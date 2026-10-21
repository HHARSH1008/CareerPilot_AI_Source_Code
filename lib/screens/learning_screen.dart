import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

class LearningScreen extends StatefulWidget {
  final dynamic skill;

  final dynamic category;
const LearningScreen(
  this.skill, {
  super.key,
  required this.category,
});

  @override

  State<LearningScreen> createState() =>

      _LearningScreenState();

}

class _LearningScreenState

    extends State<LearningScreen> {

  // ============================================================

  // API

  // ============================================================

  static const String apiUrl =

      'https://career-ai-backend-fk2i.onrender.com/api/learning-curriculum';

  static const String notesApiUrl =
      'https://career-ai-backend-fk2i.onrender.com/api/learning-notes';

  // ============================================================

  // USER SKILLS

  // ============================================================

  bool isLoading = true;

  List<String> selectedSkills = [];

  // ============================================================

  // SELECTED SKILL

  // ============================================================

  String? selectedSkill;

  bool isGenerating = false;
  bool isGeneratingNotes = false;

  Map<String, dynamic>? curriculum;
  Map<String, dynamic>? aiNotes;

  // Saved AI notes for each lesson.
  // Loaded from Firestore so notes remain after logout/login.
  Map<String, Map<String, dynamic>> savedAiNotes = {};

  Set<int> completedLessons = {};

  int _loadRequestId = 0;
  String? _courseError;

  // ============================================================

  // INIT

  // ============================================================

  @override

  void initState() {

    super.initState();

    loadUserSkills();

  }

  // ============================================================

  // LOAD USER SKILLS

  // ============================================================

  Future<void> loadUserSkills() async {

    try {

      final user =

          FirebaseAuth.instance.currentUser;

      if (user == null) {

        if (!mounted) return;

        setState(() {

          isLoading = false;

        });

        return;

      }

      final doc =

          await FirebaseFirestore.instance

              .collection('users')

              .doc(user.uid)

              .get();

      final data =

          doc.data() ?? {};

      final rawSkills =

          data['skills'];

      List<String> skills = [];

      if (rawSkills is List) {

        skills = rawSkills

            .map(

              (skill) =>

                  skill.toString().trim(),

            )

            .where(

              (skill) =>

                  skill.isNotEmpty,

            )

            .toSet()

            .toList();

      }

      if (!mounted) return;

      setState(() {

        selectedSkills = skills;

        isLoading = false;

      });

    } catch (e) {

      debugPrint(

        'Learning Skills Error: $e',

      );

      if (!mounted) return;

      setState(() {

        isLoading = false;

      });

    }

  }

  // ============================================================

  // OPEN SELECTED SKILL

  // ============================================================

  Future<void> openSkill(
    String skill,
  ) async {
    final requestId = ++_loadRequestId;

    setState(() {
      selectedSkill = skill;
      curriculum = null;
      aiNotes = null;
      savedAiNotes = {};
      completedLessons = {};
      _courseError = null;
      isGenerating = true;
    });

    await loadSavedCourse(
      skill,
      requestId: requestId,
    );
  }

  // ============================================================

  // COURSE ID

  // ============================================================

  String createCourseId(

    String skill,

  ) {

    return skill

        .toLowerCase()

        .trim()

        .replaceAll(

          RegExp(r'[^a-z0-9]+'),

          '_',

        )

        .replaceAll(

          RegExp(r'_+'),

          '_',

        )

        .replaceAll(

          RegExp(r'^_|_$'),

          '',

        );

  }

  // ============================================================

  // VALIDATE SAVED COURSE
  // ============================================================

  bool isValidSavedCourse(dynamic value) {
    if (value is! Map) {
      return false;
    }

    final lessons = value['lessons'];

    if (lessons is! List || lessons.isEmpty) {
      return false;
    }

    // A previously generated/partially saved course can exist in
    // Firestore without the fields required by this screen.
    // Treat that document as invalid and regenerate it instead of
    // showing "Course not available".
    for (final item in lessons) {
      if (item is! Map) {
        return false;
      }

      final title = item['title']?.toString().trim() ?? '';
      if (title.isEmpty) {
        return false;
      }
    }

    return true;
  }

  // ============================================================

  // LOAD SAVED COURSE

  // ============================================================

  Future<void> loadSavedCourse(
    String skill, {
    int? requestId,
  }) async {
    final activeRequestId =
        requestId ?? _loadRequestId;

    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception(
          'User not logged in',
        );
      }

      final courseId =
          createCourseId(skill);

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('learningCourses')
              .doc(courseId)
              .get();

      if (!mounted ||
          activeRequestId != _loadRequestId ||
          selectedSkill != skill) {
        return;
      }

      await loadProgress(skill);

      if (!mounted ||
          activeRequestId != _loadRequestId ||
          selectedSkill != skill) {
        return;
      }

      if (doc.exists &&
          doc.data() != null) {
        final data = doc.data()!;
        final lessons = data['lessons'];

        final rawSavedNotes =
            data['learningNotes'];

        final loadedNotes =
            <String, Map<String, dynamic>>{};

        if (rawSavedNotes is Map) {
          rawSavedNotes.forEach((key, value) {
            if (value is Map &&
                value['notes'] is Map) {
              loadedNotes[key.toString()] =
                  Map<String, dynamic>.from(
                value['notes'] as Map,
              );
            }
          });
        }

        savedAiNotes = loadedNotes;

        if (isValidSavedCourse(data)) {
          setState(() {
            curriculum =
                Map<String, dynamic>.from(data);
            _courseError = null;
            isGenerating = false;
          });

          debugPrint(
            'Saved course loaded: $skill',
          );

          return;
        }
      }

      await generateCourse(
        skill,
        requestId: activeRequestId,
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Saved Course Firebase Error: ${e.code} - ${e.message}',
      );

      if (!mounted ||
          activeRequestId != _loadRequestId ||
          selectedSkill != skill) {
        return;
      }

      if (e.code == 'permission-denied' ||
          e.code == 'unauthenticated') {
        setState(() {
          isGenerating = false;
          _courseError =
              'Course storage permission is not available. '
              'Please publish the latest Firestore Rules and try again.';
        });
        return;
      }

      await generateCourse(
        skill,
        requestId: activeRequestId,
      );
    } catch (e) {
      debugPrint(
        'Saved Course Error: $e',
      );

      if (!mounted ||
          activeRequestId != _loadRequestId ||
          selectedSkill != skill) {
        return;
      }

      await generateCourse(
        skill,
        requestId: activeRequestId,
      );
    }
  }

  // ============================================================
  // LOCAL FALLBACK COURSE
  // ============================================================

  Map<String, dynamic> createLocalFallbackCourse(String skill) {
    final cleanSkill = skill.trim().isEmpty ? 'Software Development' : skill.trim();
    final topics = <List<String>>[
      ['Introduction', 'Core terminology', 'Basic workflow'],
      ['Core concepts', 'Common patterns', 'Best practices'],
      ['Practical usage', 'Problem solving', 'Debugging'],
      ['Intermediate concepts', 'Architecture', 'Reusable solutions'],
      ['Advanced concepts', 'Optimization', 'Professional practices'],
      ['Real-world development', 'Error handling', 'Project structure'],
      ['Technical questions', 'Coding problems', 'Interview practice'],
      ['Project planning', 'Feature development', 'Portfolio presentation'],
    ];
    final titles = <String>[
      '$cleanSkill Fundamentals', '$cleanSkill Core Concepts', '$cleanSkill Practical Usage', '$cleanSkill Intermediate Concepts',
      '$cleanSkill Advanced Concepts', '$cleanSkill Real World Development', '$cleanSkill Interview Preparation', '$cleanSkill Portfolio Project',
    ];
    final lessons = List.generate(8, (index) {
      final number = index + 1;
      return <String, dynamic>{
        'lessonNumber': number, 'id': 'lesson-$number', 'title': titles[index],
        'shortDescription': 'Learn ${titles[index].toLowerCase()} with practical placement-focused guidance.',
        'explanation': 'Study $cleanSkill concepts step by step and apply them through small practical tasks.',
        'topics': topics[index],
        'examples': [{'title': '$cleanSkill Example', 'code': '// Practice $cleanSkill concept $number', 'explanation': 'Use this concept in a small practical example.'}],
        'practice': 'Create one small practice task using $cleanSkill and explain what you learned.',
        'interviewQuestions': ['What is an important concept from ${titles[index]}?', 'How would you use this concept in a real $cleanSkill project?'],
      };
    });
    return {'skill': cleanSkill, 'title': 'Complete $cleanSkill Course', 'description': 'Beginner to job-ready $cleanSkill learning path.', 'lessons': lessons};
  }

  Future<void> generateCourse(
    String skill, {
    int? requestId,
  }) async {
    final activeRequestId =
        requestId ?? _loadRequestId;

    if (!mounted) return;

    setState(() {
      isGenerating = true;
      _courseError = null;
    });

    try {
      debugPrint(
        'Generating AI course for: $skill',
      );

      final response =
          await http
              .post(
                Uri.parse(apiUrl),
                headers: {
                  'Content-Type':
                      'application/json',
                  'Accept':
                      'application/json',
                },
                body: jsonEncode({
                  'skill': skill,
                }),
              )
              .timeout(
                const Duration(
                  seconds: 100,
                ),
              );

      debugPrint(
        'Learning API Status: ${response.statusCode}',
      );
      debugPrint(
        'Learning API Response: ${response.body}',
      );

      if (!mounted ||
          activeRequestId != _loadRequestId ||
          selectedSkill != skill) {
        return;
      }

      if (response.statusCode != 200) {
        debugPrint('Learning API failed with ${response.statusCode}. Using local fallback course.');
        final fallbackCourse = createLocalFallbackCourse(skill);
        await saveCourse(skill, fallbackCourse);
        if (!mounted || activeRequestId != _loadRequestId || selectedSkill != skill) return;
        setState(() { curriculum = fallbackCourse; _courseError = null; isGenerating = false; });
        return;
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded is! Map) {
        throw Exception(
          'Invalid server response',
        );
      }

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'AI course generation failed',
        );
      }

      dynamic rawCourse = decoded['curriculum'];
      if (rawCourse is! Map) rawCourse = decoded['course'];
      if (rawCourse is! Map) rawCourse = decoded['data'];

      Map<String, dynamic> course;
      if (rawCourse is Map) {
        course = Map<String, dynamic>.from(rawCourse);
      } else {
        debugPrint('Backend returned no usable curriculum. Using local fallback.');
        course = createLocalFallbackCourse(skill);
      }

      final lessons = course['lessons'];
      if (lessons is! List || lessons.isEmpty) {
        debugPrint('Backend curriculum had no lessons. Using local fallback.');
        course = createLocalFallbackCourse(skill);
      }

      course['skill'] = skill;

      await saveCourse(
        skill,
        course,
      );

      if (!mounted ||
          activeRequestId != _loadRequestId ||
          selectedSkill != skill) {
        return;
      }

      setState(() {
        curriculum = course;
        _courseError = null;
        isGenerating = false;
      });

      debugPrint(
        'AI course ready: $skill',
      );
    } catch (e) {
      debugPrint(
        'AI Learning Error: $e',
      );

      if (!mounted ||
          activeRequestId != _loadRequestId ||
          selectedSkill != skill) {
        return;
      }

      debugPrint('AI course generation failed. Using local fallback: $e');
      final fallbackCourse = createLocalFallbackCourse(skill);
      try {
        await saveCourse(skill, fallbackCourse);
      } catch (saveError) {
        debugPrint('Fallback course save error: $saveError');
      }
      if (!mounted || activeRequestId != _loadRequestId || selectedSkill != skill) return;
      setState(() { curriculum = fallbackCourse; _courseError = null; isGenerating = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI course was temporarily unavailable. A complete offline course has been loaded.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================

  // SAVE COURSE

  // ============================================================

  Future<void> saveCourse(

    String skill,

    Map<String, dynamic> course,

  ) async {

    try {

      final user =

          FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final courseId =

          createCourseId(skill);

      await FirebaseFirestore.instance

          .collection('users')

          .doc(user.uid)

          .collection('learningCourses')

          .doc(courseId)

          .set({

        'skill': skill,

        'title':

            course['title']?.toString() ??

                'Learn $skill',

        'description':

            course['description']

                    ?.toString() ??

                '',

        'lessons':

            course['lessons'],

        'createdAt':

            FieldValue.serverTimestamp(),

        'updatedAt':

            FieldValue.serverTimestamp(),

      }, SetOptions(merge: true));

    } catch (e) {

      debugPrint(

        'Save Course Error: $e',

      );

    }

  }

  // ============================================================

  // LOAD PROGRESS

  // ============================================================

  Future<void> loadProgress(

    String skill,

  ) async {

    try {

      final user =

          FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final doc =

          await FirebaseFirestore.instance

              .collection('users')

              .doc(user.uid)

              .get();

      final data =

          doc.data() ?? {};

      final allProgress =

          data['skillProgress'];

      if (allProgress is Map) {

        final progress =

            allProgress[skill];

        if (progress is List) {

          completedLessons =

              progress

                  .map(

                    (item) =>

                        int.tryParse(

                      item.toString(),

                    ),

                  )

                  .whereType<int>()

                  .toSet();

        }

      }

    } catch (e) {

      debugPrint(

        'Progress Error: $e',

      );

    }

  }

  // ============================================================

  // SAVE PROGRESS

  // ============================================================

  Future<void> saveProgress() async {

    try {

      final user =

          FirebaseAuth.instance.currentUser;

      if (user == null ||

          selectedSkill == null) {

        return;

      }

      final userRef =

          FirebaseFirestore.instance

              .collection('users')

              .doc(user.uid);

      final doc =

          await userRef.get();

      final data =

          doc.data() ?? {};

      Map<String, dynamic>

          allProgress = {};

      final existing =

          data['skillProgress'];

      if (existing is Map) {

        allProgress =

            Map<String, dynamic>.from(

          existing,

        );

      }

      allProgress[selectedSkill!] =

          completedLessons.toList()

            ..sort();

      await userRef.set(

        {

          'skillProgress':

              allProgress,

          'updatedAt':

              FieldValue.serverTimestamp(),

        },

        SetOptions(

          merge: true,

        ),

      );

    } catch (e) {

      debugPrint(

        'Save Progress Error: $e',

      );

    }

  }

  // ============================================================

  // MARK LESSON COMPLETE

  // ============================================================

  Future<void> toggleLesson(

    int index,

  ) async {

    setState(() {

      if (completedLessons

          .contains(index)) {

        completedLessons

            .remove(index);

      } else {

        completedLessons

            .add(index);

      }

    });

    await saveProgress();

  }

  // ============================================================

  // GET LESSONS

  // ============================================================

  List<Map<String, dynamic>>

      getLessons() {

    if (curriculum == null) {

      return [];

    }

    final raw =

        curriculum!['lessons'];

    if (raw is! List) {

      return [];

    }

    return raw

        .whereType<Map>()

        .map(

          (lesson) =>

              Map<String, dynamic>.from(

            lesson,

          ),

        )

        .toList();

  }

  // ============================================================

  // SKILL ICON

  // ============================================================

  IconData skillIcon(

    String skill,

  ) {

    final value =

        skill.toLowerCase();

    if (value.contains('python')) {

      return Icons.code_rounded;

    }

    if (value.contains('java')) {

      return Icons.coffee_rounded;

    }

    if (value.contains('flutter')) {

      return Icons.phone_android_rounded;

    }

    if (value.contains('dart')) {

      return Icons.flutter_dash_rounded;

    }

    if (value.contains('mysql') ||

        value.contains('sql')) {

      return Icons.storage_rounded;

    }

    if (value.contains('firebase')) {

      return Icons.local_fire_department_rounded;

    }

    if (value.contains('react')) {

      return Icons.web_rounded;

    }

    if (value.contains('javascript')) {

      return Icons.javascript_rounded;

    }

    if (value.contains('cyber') ||

        value.contains('security')) {

      return Icons.security_rounded;

    }

    if (value.contains('git')) {

      return Icons.source_rounded;

    }

    if (value.contains('machine') ||

        value == 'ml' ||

        value.contains('ai')) {

      return Icons.psychology_rounded;

    }

    return Icons.school_rounded;

  }

  // ============================================================

  // BUILD

  // ============================================================

  @override

  Widget build(

    BuildContext context,

  ) {

    return Scaffold(

      backgroundColor:

          const Color(0xffF7F8FC),

      appBar: AppBar(

        backgroundColor:

            Colors.white,

        elevation: 0,

        leading: IconButton(

          onPressed: () {

            if (selectedSkill != null) {

              setState(() {

                selectedSkill = null;

                curriculum = null;

                completedLessons =

                    {};

              });

            } else {

              Navigator.pop(

                context,

              );

            }

          },

          icon: const Icon(

            Icons.arrow_back_rounded,

            color:

                Color(0xff172033),

          ),

        ),

        title: Text(

          selectedSkill == null

              ? 'Learning'

              : selectedSkill!,

          style:

              const TextStyle(

            color:

                Color(0xff172033),

            fontWeight:

                FontWeight.bold,

            fontSize: 21,

          ),

        ),

        actions: [

          if (selectedSkill != null)

            IconButton(

              onPressed:

                  isGenerating

                      ? null

                      : () {

                          generateCourse(

                            selectedSkill!,

                          );

                        },

              icon: const Icon(

                Icons.refresh_rounded,

                color:

                    Color(0xff667EEA),

              ),

            ),

        ],

      ),

      body: isLoading

    ? const Center(

        child: CircularProgressIndicator(

          color: Color(0xff667EEA),

        ),

      )

    : selectedSkill == null

        ? buildSkillList()

        : _currentLesson != null

            ? buildLessonContent()

            : buildCourse(),

    );

  }

  // ============================================================

  // SKILL LIST

  // ============================================================

  Widget buildSkillList() {

    if (selectedSkills.isEmpty) {

      return const Center(

        child: Padding(

          padding:

              EdgeInsets.all(25),

          child: Column(

            mainAxisAlignment:

                MainAxisAlignment.center,

            children: [

              Icon(

                Icons.school_outlined,

                size: 70,

                color:

                    Color(0xff667EEA),

              ),

              SizedBox(

                height: 20,

              ),

              Text(

                'No skills selected',

                style:

                    TextStyle(

                  fontSize: 22,

                  fontWeight:

                      FontWeight.bold,

                ),

              ),

              SizedBox(

                height: 10,

              ),

              Text(

                'Select skills during onboarding to start learning.',

                textAlign:

                    TextAlign.center,

                style:

                    TextStyle(

                  color:

                      Colors.grey,

                ),

              ),

            ],

          ),

        ),

      );

    }

    return RefreshIndicator(

      onRefresh:

          loadUserSkills,

      color:

          const Color(0xff667EEA),

      child: ListView(

        padding:

            const EdgeInsets.all(

          16,

        ),

        children: [

          buildLearningBanner(),

          const SizedBox(

            height: 25,

          ),

          const Text(

            'Your Learning',

            style:

                TextStyle(

              fontSize: 22,

              fontWeight:

                  FontWeight.bold,

              color:

                  Color(0xff172033),

            ),

          ),

          const SizedBox(

            height: 5,

          ),

          const Text(

            'Choose a skill and learn it completely inside the app.',

            style:

                TextStyle(

              color:

                  Colors.grey,

              fontSize: 13,

            ),

          ),

          const SizedBox(

            height: 18,

          ),

          ...selectedSkills.map(

            (skill) =>

                buildSkillCard(

              skill,

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // BANNER

  // ============================================================

  Widget buildLearningBanner() {

    return Container(

      padding:

          const EdgeInsets.all(22),

      decoration:

          BoxDecoration(

        gradient:

            const LinearGradient(

          colors: [

            Color(0xff667EEA),

            Color(0xff764BA2),

          ],

        ),

        borderRadius:

            BorderRadius.circular(

          25,

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                width: 55,

                height: 55,

                decoration:

                    BoxDecoration(

                  color:

                      Colors.white24,

                  borderRadius:

                      BorderRadius.circular(

                    17,

                  ),

                ),

                child:

                    const Icon(

                  Icons.auto_awesome,

                  color:

                      Colors.white,

                  size: 30,

                ),

              ),

              const SizedBox(

                width: 14,

              ),

              const Expanded(

                child: Text(

                  'AI Learning',

                  style:

                      TextStyle(

                    color:

                        Colors.white,

                    fontSize: 23,

                    fontWeight:

                        FontWeight.bold,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 18,

          ),

          const Text(

            'Learn your selected skills with AI-generated lessons, examples, practice and interview preparation.',

            style:

                TextStyle(

              color:

                  Colors.white70,

              fontSize: 14,

              height: 1.5,

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // SKILL CARD

  // ============================================================

  Widget buildSkillCard(

    String skill,

  ) {

    return Container(

      margin:

          const EdgeInsets.only(

        bottom: 14,

      ),

      child: Material(

        color:

            Colors.white,

        borderRadius:

            BorderRadius.circular(

          20,

        ),

        child: InkWell(

          onTap: () {

            openSkill(

              skill,

            );

          },

          borderRadius:

              BorderRadius.circular(

            20,

          ),

          child: Container(

            padding:

                const EdgeInsets.all(

              17,

            ),

            decoration:

                BoxDecoration(

              borderRadius:

                  BorderRadius.circular(

                20,

              ),

              border: Border.all(

                color:

                    const Color(

                  0xffE5E7EF,

                ),

              ),

            ),

            child: Row(

              children: [

                Container(

                  width: 58,

                  height: 58,

                  decoration:

                      BoxDecoration(

                    gradient:

                        const LinearGradient(

                      colors: [

                        Color(

                          0xff667EEA,

                        ),

                        Color(

                          0xff764BA2,

                        ),

                      ],

                    ),

                    borderRadius:

                        BorderRadius.circular(

                      17,

                    ),

                  ),

                  child:

                      Icon(

                    skillIcon(

                      skill,

                    ),

                    color:

                        Colors.white,

                    size: 28,

                  ),

                ),

                const SizedBox(

                  width: 14,

                ),

                Expanded(

                  child:

                      Column(

                    crossAxisAlignment:

                        CrossAxisAlignment

                            .start,

                    children: [

                      Text(

                        skill,

                        style:

                            const TextStyle(

                          fontSize:

                              17,

                          fontWeight:

                              FontWeight

                                  .bold,

                          color:

                              Color(

                            0xff172033,

                          ),

                        ),

                      ),

                      const SizedBox(

                        height: 5,

                      ),

                      const Text(

                        'AI Course • Examples • Practice • Interview',

                        style:

                            TextStyle(

                          fontSize:

                              11,

                          color:

                              Colors.grey,

                        ),

                      ),

                    ],

                  ),

                ),

                Container(

                  width: 40,

                  height: 40,

                  decoration:

                      BoxDecoration(

                    color:

                        const Color(

                      0xffEEF0FF,

                    ),

                    borderRadius:

                        BorderRadius.circular(

                      12,

                    ),

                  ),

                  child:

                      const Icon(

                    Icons

                        .arrow_forward_ios_rounded,

                    size: 15,

                    color:

                        Color(

                      0xff667EEA,

                    ),

                  ),

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }

  // ============================================================

  // COURSE

  // ============================================================

  Widget buildCourse() {

    if (isGenerating) {

      return buildGenerating();

    }

    if (curriculum == null) {
      return buildCourseError();
    }

    final lessons =

        getLessons();

    final total =

        lessons.length;

    final completed =

        completedLessons

            .where(

              (index) =>

                  index >= 0 &&

                  index < total,

            )

            .length;

    final progress =

        total == 0

            ? 0.0

            : completed / total;

    return RefreshIndicator(

      onRefresh: () async {

        await generateCourse(

          selectedSkill!,

        );

      },

      color:

          const Color(0xff667EEA),

      child: ListView(

        physics:

            const AlwaysScrollableScrollPhysics(),

        padding:

            const EdgeInsets.all(

          16,

        ),

        children: [

          buildCourseHeader(

            progress,

            completed,

            total,

          ),

          const SizedBox(

            height: 25,

          ),

          const Text(

            'Learning Path',

            style:

                TextStyle(

              fontSize: 21,

              fontWeight:

                  FontWeight.bold,

              color:

                  Color(0xff172033),

            ),

          ),

          const SizedBox(

            height: 6,

          ),

          const Text(

            'Learn step by step inside the app.',

            style:

                TextStyle(

              color:

                  Colors.grey,

            ),

          ),

          const SizedBox(

            height: 16,

          ),

          ...List.generate(

            lessons.length,

            (index) =>

                buildLesson(

              index,

              lessons[index],

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // GENERATING

  // ============================================================

  Widget buildCourseError() {
    final message =
        (_courseError == null ||
                _courseError!.trim().isEmpty)
            ? 'We could not load this course right now.'
            : _courseError!;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: const Color(0xffEEF1FF),
                borderRadius:
                    BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                size: 38,
                color: Color(0xff667EEA),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Course could not be loaded',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xff172033),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xff687086),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 170,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: selectedSkill == null
                    ? null
                    : () {
                        final skill =
                            selectedSkill!;
                        final retryId =
                            ++_loadRequestId;

                        setState(() {
                          curriculum = null;
                          aiNotes = null;
                          _courseError = null;
                          isGenerating = true;
                        });

                        loadSavedCourse(
                          skill,
                          requestId: retryId,
                        );
                      },
                icon: const Icon(
                  Icons.refresh_rounded,
                ),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xff667EEA),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildGenerating() {

    return Center(

      child: Padding(

        padding:

            const EdgeInsets.all(

          30,

        ),

        child: Column(

          mainAxisAlignment:

              MainAxisAlignment.center,

          children: [

            Container(

              width: 90,

              height: 90,

              decoration:

                  BoxDecoration(

                gradient:

                    const LinearGradient(

                  colors: [

                    Color(0xff667EEA),

                    Color(0xff764BA2),

                  ],

                ),

                borderRadius:

                    BorderRadius.circular(

                  28,

                ),

              ),

              child:

                  const Icon(

                Icons.auto_awesome,

                color:

                    Colors.white,

                size: 42,

              ),

            ),

            const SizedBox(

              height: 22,

            ),

            Text(

              'AI is preparing ${selectedSkill!}',

              textAlign:

                  TextAlign.center,

              style:

                  const TextStyle(

                fontSize: 21,

                fontWeight:

                    FontWeight.bold,

                color:

                    Color(0xff172033),

              ),

            ),

            const SizedBox(

              height: 10,

            ),

            const Text(

              'Creating lessons, examples, practice tasks and interview questions for you...',

              textAlign:

                  TextAlign.center,

              style:

                  TextStyle(

                color:

                    Colors.grey,

                height: 1.5,

              ),

            ),

            const SizedBox(

              height: 25,

            ),

            const CircularProgressIndicator(

              color:

                  Color(0xff667EEA),

            ),

          ],

        ),

      ),

    );

  }

  // ============================================================

  // COURSE HEADER

  // ============================================================

  Widget buildCourseHeader(

    double progress,

    int completed,

    int total,

  ) {

    return Container(

      padding:

          const EdgeInsets.all(

        22,

      ),

      decoration:

          BoxDecoration(

        gradient:

            const LinearGradient(

          colors: [

            Color(0xff667EEA),

            Color(0xff764BA2),

          ],

        ),

        borderRadius:

            BorderRadius.circular(

          25,

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                width: 55,

                height: 55,

                decoration:

                    BoxDecoration(

                  color:

                      Colors.white24,

                  borderRadius:

                      BorderRadius.circular(

                    17,

                  ),

                ),

                child:

                    Icon(

                  skillIcon(

                    selectedSkill!,

                  ),

                  color:

                      Colors.white,

                  size: 29,

                ),

              ),

              const SizedBox(

                width: 14,

              ),

              Expanded(

                child: Text(

                  'Learn $selectedSkill',

                  style:

                      const TextStyle(

                    color:

                        Colors.white,

                    fontSize: 23,

                    fontWeight:

                        FontWeight.bold,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 22,

          ),

          Text(

            curriculum!['description']

                    ?.toString() ??

                'Your AI-powered learning course.',

            style:

                const TextStyle(

              color:

                  Colors.white70,

              fontSize: 14,

              height: 1.5,

            ),

          ),

          const SizedBox(

            height: 20,

          ),

          Row(

            children: [

              Expanded(

                child:

                    LinearProgressIndicator(

                  value:

                      progress,

                  minHeight: 9,

                  backgroundColor:

                      Colors.white24,

                  valueColor:

                      const AlwaysStoppedAnimation<

                          Color>(

                    Colors.white,

                  ),

                  borderRadius:

                      BorderRadius.circular(

                    10,

                  ),

                ),

              ),

              const SizedBox(

                width: 12,

              ),

              Text(

                '${(progress * 100).round()}%',

                style:

                    const TextStyle(

                  color:

                      Colors.white,

                  fontWeight:

                      FontWeight.bold,

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 8,

          ),

          Text(

            '$completed of $total lessons completed',

            style:

                const TextStyle(

              color:

                  Colors.white70,

              fontSize: 12,

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // LESSON CARD

  // ============================================================

  Widget buildLesson(

    int index,

    Map<String, dynamic> lesson,

  ) {

    final completed =

        completedLessons

            .contains(index);

    return InkWell(

      onTap: () {

        openLessonContent(

          index,

          lesson,

        );

      },

      borderRadius:

          BorderRadius.circular(

        20,

      ),

      child: Container(

        margin:

            const EdgeInsets.only(

          bottom: 14,

        ),

        padding:

            const EdgeInsets.all(

          17,

        ),

        decoration:

            BoxDecoration(

          color:

              Colors.white,

          borderRadius:

              BorderRadius.circular(

            20,

          ),

          border: Border.all(

            color: completed

                ? const Color(

                    0xff667EEA,

                  )

                : const Color(

                    0xffE5E7EF,

                  ),

          ),

        ),

        child: Row(

          children: [

            Container(

              width: 55,

              height: 55,

              decoration:

                  BoxDecoration(

                gradient:

                    LinearGradient(

                  colors: completed

                      ? const [

                          Color(

                            0xff34C759,

                          ),

                          Color(

                            0xff2E9D4F,

                          ),

                        ]

                      : const [

                          Color(

                            0xff667EEA,

                          ),

                          Color(

                            0xff764BA2,

                          ),

                        ],

                ),

                borderRadius:

                    BorderRadius.circular(

                  17,

                ),

              ),

              child:

                  Icon(

                completed

                    ? Icons.check_rounded

                    : Icons.menu_book_rounded,

                color:

                    Colors.white,

              ),

            ),

            const SizedBox(

              width: 14,

            ),

            Expanded(

              child:

                  Column(

                crossAxisAlignment:

                    CrossAxisAlignment.start,

                children: [

                  Text(

                    'LESSON ${index + 1}',

                    style:

                        const TextStyle(

                      fontSize: 10,

                      color:

                          Color(

                        0xff667EEA,

                      ),

                      fontWeight:

                          FontWeight.bold,

                      letterSpacing: 1,

                    ),

                  ),

                  const SizedBox(

                    height: 4,

                  ),

                  Text(

                    lesson['title']

                            ?.toString() ??

                        'Lesson ${index + 1}',

                    maxLines:

                        2,

                    overflow:

                        TextOverflow

                            .ellipsis,

                    style:

                        const TextStyle(

                      fontSize: 16,

                      fontWeight:

                          FontWeight.bold,

                      color:

                          Color(

                        0xff172033,

                      ),

                    ),

                  ),

                  const SizedBox(

                    height: 5,

                  ),

                  Text(

                    lesson['shortDescription']

                            ?.toString() ??

                        '',

                    maxLines:

                        2,

                    overflow:

                        TextOverflow

                            .ellipsis,

                    style:

                        const TextStyle(

                      fontSize: 12,

                      color:

                          Colors.grey,

                    ),

                  ),

                ],

              ),

            ),

            const Icon(

              Icons

                  .arrow_forward_ios_rounded,

              size: 16,

              color:

                  Color(0xff667EEA),

            ),

          ],

        ),

      ),

    );

  }

  // ============================================================

  // OPEN LESSON CONTENT

  // ============================================================

 void openLessonContent(

  int index,

  Map<String, dynamic> lesson,

) {

  final lessonTitle =

      lesson['title']?.toString().trim() ?? '';

  final notesKey =

      selectedSkill == null ||

              lessonTitle.isEmpty

          ? ''

          : createLessonNotesId(

              selectedSkill!,

              lessonTitle,

            );


  final savedNotes =

      notesKey.isNotEmpty

          ? savedAiNotes[notesKey]

          : null;

  setState(() {

    _currentLessonIndex = index;

    _currentLesson = lesson;

    aiNotes = savedNotes == null

        ? null

        : Map<String, dynamic>.from(

            savedNotes,

          );

    isGeneratingNotes = false;

  });

  // Existing notes are shown immediately.
  // If this lesson has no saved notes, generate them automatically.
  if (savedNotes == null) {

    Future.microtask(() {

      if (mounted && _currentLesson == lesson) {

        generateAiNotes(lesson);

      }

    });

  }

}

  int _currentLessonIndex = 0;

  Map<String, dynamic>?

      _currentLesson;

  // ============================================================

  // AI NOTES ID

  // ============================================================

  String createLessonNotesId(

    String skill,

    String lessonTitle,

  ) {

    return createCourseId(

      '$skill-$lessonTitle',

    );

  }

  // ============================================================

  // SAVE AI NOTES TO FIRESTORE

  // ============================================================

  Future<void> saveAiNotes(

    String skill,

    String lessonTitle,

    Map<String, dynamic> notes,

  ) async {

    try {

      final user =

          FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final courseId =

          createCourseId(skill);

      final notesKey =

          createLessonNotesId(

        skill,

        lessonTitle,

      );

      final courseRef =

          FirebaseFirestore.instance

              .collection('users')

              .doc(user.uid)

              .collection('learningCourses')

              .doc(courseId);

      final courseDoc =

          await courseRef.get();

      final existingData =

          courseDoc.data() ?? {};

      final rawLearningNotes =

          existingData['learningNotes'];

      final learningNotes =

          <String, dynamic>{};

      if (rawLearningNotes is Map) {

        learningNotes.addAll(

          Map<String, dynamic>.from(

            rawLearningNotes,

          ),

        );

      }

      learningNotes[notesKey] = {

        'lessonTitle': lessonTitle,

        'notes': notes,

        'updatedAt':

            FieldValue.serverTimestamp(),

      };

      await courseRef.set(

        {

          'learningNotes':

              learningNotes,

          'updatedAt':

              FieldValue.serverTimestamp(),

        },

        SetOptions(

          merge: true,

        ),

      );

      savedAiNotes[notesKey] =

          Map<String, dynamic>.from(

        notes,

      );

    } catch (e) {

      debugPrint(

        'Save AI Notes Error: $e',

      );

    }

  }

  // ============================================================

  // GENERATE AI NOTES

  // ============================================================

  Future<void> generateAiNotes(

    Map<String, dynamic> lesson,

  ) async {

    if (selectedSkill == null ||

        isGeneratingNotes) {

      return;

    }

    final String lessonTitle =

        lesson['title']?.toString().trim() ??

            '';

    if (lessonTitle.isEmpty) {

      if (mounted) {

        setState(() {

          isGeneratingNotes = false;

        });

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text(

              'Lesson title is missing. Please open the lesson again.',

            ),

            behavior: SnackBarBehavior.floating,

          ),

        );

      }

      return;

    }

    setState(() {

      isGeneratingNotes = true;

    });

    try {


      final response =

          await http

              .post(

                Uri.parse(

                  notesApiUrl,

                ),

                headers: {

                  'Content-Type':

                      'application/json',

                },

                body: jsonEncode({

                  'skill':

                      selectedSkill,

                  'lessonTitle':

                      lessonTitle,

                  'shortDescription':

                      lesson['shortDescription']

                              ?.toString() ??

                          '',

                  'explanation':

                      lesson['explanation']

                              ?.toString() ??

                          '',

                  'topics':

                      lesson['topics'] ?? [],

                  'examples':

                      lesson['examples'] ?? [],

                  'practice':

                      lesson['practice']

                              ?.toString() ??

                          '',

                  'interviewQuestions':

                      lesson['interviewQuestions'] ??

                          [],

                }),

              )

              .timeout(

                const Duration(

                  seconds: 90,

                ),

              );

      debugPrint(

        'AI Notes Status: ${response.statusCode}',

      );

      if (response.statusCode != 200) {

        throw Exception(

          'Notes API failed: ${response.statusCode}',

        );

      }

      final decoded =

          jsonDecode(

        response.body,

      );

      if (decoded is! Map ||

          decoded['success'] != true) {

        throw Exception(

          decoded is Map

              ? decoded['message']?.toString() ??

                  'AI notes failed'

              : 'Invalid AI notes response',

        );

      }

      final rawNotes =

          decoded['notes'];

      if (rawNotes is! Map) {

        throw Exception(

          'Invalid AI notes data',

        );

      }

      final generatedNotes =

          Map<String, dynamic>.from(

        rawNotes,

      );

      // Save permanently before showing the notes.
      await saveAiNotes(

        selectedSkill!,

        lessonTitle,

        generatedNotes,

      );

      if (!mounted) return;

      setState(() {

        aiNotes = generatedNotes;

        isGeneratingNotes = false;

      });

    } catch (e) {
      debugPrint(
        'AI Notes Error: $e',
      );

      if (!mounted) return;

      final fallbackLessonTitle =

          lessonTitle.isNotEmpty

              ? lessonTitle

              : (_currentLesson?['title']?.toString().trim() ?? '');

      final fallbackKey =

          selectedSkill == null ||

                  fallbackLessonTitle.isEmpty

              ? ''

              : createLessonNotesId(

                  selectedSkill!,

                  fallbackLessonTitle,

                );


      final cachedNotes =
          fallbackKey.isNotEmpty
              ? savedAiNotes[fallbackKey]
              : null;

      setState(() {
        isGeneratingNotes = false;

        if (cachedNotes != null) {
          aiNotes =
              Map<String, dynamic>.from(
            cachedNotes,
          );
        }
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(
        SnackBar(
          content: Text(
            cachedNotes != null
                ? 'AI service unavailable. Showing your saved notes.'
                : 'AI Notes generate nahi ho paaye. Please try again.',
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
    }

  }

  Widget buildAiNotesLoading() {

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xffEEF1FF),
            Color(0xffF8F5FF),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xffD9DEFF),
        ),
      ),
      child: const Column(
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xff667EEA),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'AI is preparing your complete study notes...',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xff172033),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Gemini is generating detailed explanations, examples, practice questions and interview answers.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: Color(0xff687086),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildRealAiNotes(Map<String, dynamic> notes) {
    List<String> stringList(dynamic value) {
      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return [];
    }

    final summary = notes['summary']?.toString() ?? '';
    final detailedExplanation =
        notes['detailedExplanation']?.toString() ?? '';
    final keyConcepts = stringList(notes['keyConcepts']);
    final importantPoints = stringList(notes['importantPoints']);
    final commonMistakes = stringList(notes['commonMistakes']);
    final quickRevision = stringList(notes['quickRevision']);

    final examples = notes['examples'] is List
        ? List<dynamic>.from(notes['examples'] as List)
        : <dynamic>[];

    final practiceQuestions = notes['practiceQuestions'] is List
        ? List<dynamic>.from(notes['practiceQuestions'] as List)
        : <dynamic>[];

    final interviewQuestions = notes['interviewQuestions'] is List
        ? List<dynamic>.from(notes['interviewQuestions'] as List)
        : <dynamic>[];

    Widget sectionTitle(
      String title,
      IconData icon,
    ) {
      return Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xffEEF1FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              icon,
              color: const Color(0xff667EEA),
              size: 21,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xff172033),
              ),
            ),
          ),
        ],
      );
    }

    Widget textCard(String text) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 14,
            height: 1.6,
            color: Color(0xff3F4659),
          ),
        ),
      );
    }

    Widget bulletCard(List<String> items) {
      return Column(
        children: items.map((item) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 9),
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: Color(0xff667EEA),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Color(0xff3F4659),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    Widget exampleCard(dynamic rawExample, int index) {
      final example = rawExample is Map
          ? Map<String, dynamic>.from(rawExample)
          : <String, dynamic>{};

      final title = example['title']?.toString() ?? 'Example ${index + 1}';
      final scenario = example['scenario']?.toString() ?? '';
      final code = example['code']?.toString() ?? '';
      final explanation = example['explanation']?.toString() ?? '';

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: const Color(0xffE5E7F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${index + 1}. $title',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xff172033),
              ),
            ),
            if (scenario.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                scenario,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xff596176),
                ),
              ),
            ],
            if (code.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: const Color(0xff151923),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Text(
                    code,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12.5,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
            if (explanation.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                explanation,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xff3F4659),
                ),
              ),
            ],
          ],
        ),
      );
    }

    Widget questionCard(
      dynamic rawQuestion,
      int index,
      String prefix,
    ) {
      final item = rawQuestion is Map
          ? Map<String, dynamic>.from(rawQuestion)
          : <String, dynamic>{};

      final question =
          item['question']?.toString() ?? rawQuestion.toString();
      final answer = item['answer']?.toString() ?? '';
      final difficulty = item['difficulty']?.toString() ?? '';

      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$prefix${index + 1}. $question',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.45,
                color: Color(0xff172033),
              ),
            ),
            if (difficulty.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                'Difficulty: $difficulty',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff667EEA),
                ),
              ),
            ],
            if (answer.isNotEmpty) ...[
              const SizedBox(height: 9),
              Text(
                'Answer / Approach',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff667EEA),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                answer,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color: Color(0xff596176),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xffEEF1FF),
            Color(0xffF8F5FF),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xffD9DEFF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xff667EEA),
                      Color(0xff764BA2),
                    ],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete AI Study Notes',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff172033),
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Generated by Gemini • Saved to your account',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xff687086),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (summary.isNotEmpty) ...[
            const SizedBox(height: 22),
            sectionTitle(
              '1. Summary',
              Icons.summarize_outlined,
            ),
            textCard(summary),
          ],

          if (detailedExplanation.isNotEmpty) ...[
            const SizedBox(height: 20),
            sectionTitle(
              '2. Detailed Explanation',
              Icons.menu_book_rounded,
            ),
            textCard(detailedExplanation),
          ],

          if (keyConcepts.isNotEmpty) ...[
            const SizedBox(height: 20),
            sectionTitle(
              '3. Key Concepts',
              Icons.key_rounded,
            ),
            bulletCard(keyConcepts),
          ],

          if (importantPoints.isNotEmpty) ...[
            const SizedBox(height: 20),
            sectionTitle(
              '4. Important Points',
              Icons.priority_high_rounded,
            ),
            bulletCard(importantPoints),
          ],

          if (examples.isNotEmpty) ...[
            const SizedBox(height: 20),
            sectionTitle(
              '5. Practical Examples',
              Icons.code_rounded,
            ),
            ...examples.asMap().entries.map(
              (entry) => exampleCard(
                entry.value,
                entry.key,
              ),
            ),
          ],

          if (practiceQuestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            sectionTitle(
              '6. Practice Questions',
              Icons.fitness_center_rounded,
            ),
            ...practiceQuestions.asMap().entries.map(
              (entry) => questionCard(
                entry.value,
                entry.key,
                '',
              ),
            ),
          ],

          if (commonMistakes.isNotEmpty) ...[
            const SizedBox(height: 20),
            sectionTitle(
              '7. Common Mistakes',
              Icons.warning_amber_rounded,
            ),
            bulletCard(commonMistakes),
          ],

          if (interviewQuestions.isNotEmpty) ...[
            const SizedBox(height: 20),
            sectionTitle(
              '8. Interview Questions',
              Icons.question_answer_rounded,
            ),
            ...interviewQuestions.asMap().entries.map(
              (entry) => questionCard(
                entry.value,
                entry.key,
                '',
              ),
            ),
          ],

          if (quickRevision.isNotEmpty) ...[
            const SizedBox(height: 20),
            sectionTitle(
              '9. Quick Revision',
              Icons.flash_on_rounded,
            ),
            bulletCard(quickRevision),
          ],
        ],
      ),
    );
  }

  Widget _aiNotesSection({required IconData icon, required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.82), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xff667EEA)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xff172033))),
            ],
          ),
          const SizedBox(height: 11),
          child,
        ],
      ),
    );
  }

  Widget _bulletList(List<String> items) {
    return Column(
      children: items.map((item) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Icon(Icons.circle, size: 6, color: Color(0xff667EEA)),
              ),
              const SizedBox(width: 9),
              Expanded(child: Text(item, style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xff454B63)))),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget buildLessonContent() {
    final lesson = _currentLesson;

    if (lesson == null) {
      return const SizedBox();
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        buildLessonHeader(lesson),
        const SizedBox(height: 18),

        if (isGeneratingNotes) ...[
          buildAiNotesLoading(),
          const SizedBox(height: 18),
        ],

        if (!isGeneratingNotes && aiNotes == null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xffF7F8FC),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: const Color(0xffE3E6F0),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.auto_awesome,
                  size: 38,
                  color: Color(0xff667EEA),
                ),
                SizedBox(height: 10),
                Text(
                  'AI Notes are ready to generate',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xff172033),
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Get detailed explanations, multiple examples, practice questions and interview preparation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xff687086),
                  ),
                ),
                SizedBox(height: 14),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () => generateAiNotes(lesson),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate Complete AI Notes'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff667EEA),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
        ],

        if (aiNotes != null) ...[
          buildRealAiNotes(aiNotes!),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: isGeneratingNotes
                  ? null
                  : () => generateAiNotes(lesson),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Regenerate Complete AI Notes'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xff667EEA),
                side: const BorderSide(
                  color: Color(0xff667EEA),
                ),
                padding: const EdgeInsets.symmetric(
                  vertical: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xffEEF1FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.cloud_done_rounded,
                size: 20,
                color: Color(0xff667EEA),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Your AI notes are saved to your account and remain available after logout.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xff4B5575),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        SizedBox(
          height: 55,
          child: ElevatedButton.icon(
            onPressed: () async {
              await toggleLesson(_currentLessonIndex);
              if (!mounted) return;
              setState(() {
                _currentLesson = null;
                aiNotes = null;
              });
            },
            icon: Icon(
              completedLessons.contains(_currentLessonIndex)
                  ? Icons.undo_rounded
                  : Icons.check_rounded,
            ),
            label: Text(
              completedLessons.contains(_currentLessonIndex)
                  ? 'Mark Lesson Incomplete'
                  : 'Mark Lesson Complete',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff667EEA),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildLessonHeader(

    Map<String, dynamic> lesson,

  ) {

    return Container(

      padding:

          const EdgeInsets.all(

        22,

      ),

      decoration:

          BoxDecoration(

        gradient:

            const LinearGradient(

          colors: [

            Color(0xff667EEA),

            Color(0xff764BA2),

          ],

        ),

        borderRadius:

            BorderRadius.circular(

          24,

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Text(

            'LESSON ${_currentLessonIndex + 1}',

            style:

                const TextStyle(

              color:

                  Colors.white70,

              fontSize: 11,

              letterSpacing: 1,

              fontWeight:

                  FontWeight.bold,

            ),

          ),

          const SizedBox(

            height: 8,

          ),

          Text(

            lesson['title']

                    ?.toString() ??

                'Lesson',

            style:

                const TextStyle(

              color:

                  Colors.white,

              fontSize: 25,

              fontWeight:

                  FontWeight.bold,

            ),

          ),

          const SizedBox(

            height: 10,

          ),

          Text(

            lesson['shortDescription']

                    ?.toString() ??

                '',

            style:

                const TextStyle(

              color:

                  Colors.white70,

              fontSize: 14,

              height: 1.5,

            ),

          ),

          const SizedBox(

            height: 12,

          ),

          const Row(

            children: [

              Icon(

                Icons.auto_awesome,

                color:

                    Colors.white,

                size: 16,

              ),

              SizedBox(

                width: 6,

              ),

              Text(

                'Taught by AI inside the app',

                style:

                    TextStyle(

                  color:

                      Colors.white70,

                  fontSize: 11,

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }

  // ============================================================

  // TEACHING SECTION

  // ============================================================

  Widget buildTeachingSection(

    String title,

    IconData icon,

    Widget child,

  ) {

    return Container(

      width:

          double.infinity,

      padding:

          const EdgeInsets.all(

        18,

      ),

      decoration:

          BoxDecoration(

        color:

            Colors.white,

        borderRadius:

            BorderRadius.circular(

          20,

        ),

        border: Border.all(

          color:

              const Color(

            0xffE5E7EF,

          ),

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                width: 42,

                height: 42,

                decoration:

                    BoxDecoration(

                  color:

                      const Color(

                    0xffEEF0FF,

                  ),

                  borderRadius:

                      BorderRadius.circular(

                    13,

                  ),

                ),

                child:

                    Icon(

                  icon,

                  color:

                      const Color(

                    0xff667EEA,

                  ),

                ),

              ),

              const SizedBox(

                width: 12,

              ),

              Text(

                title,

                style:

                    const TextStyle(

                  fontSize: 18,

                  fontWeight:

                      FontWeight.bold,

                  color:

                      Color(

                    0xff172033,

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(

            height: 16,

          ),

          child,

        ],

      ),

    );

  }

  // ============================================================

  // EXAMPLE

  // ============================================================

  Widget buildExample(

    Map<String, dynamic> example,

  ) {

    return Container(

      width:

          double.infinity,

      margin:

          const EdgeInsets.only(

        bottom: 14,

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Text(

            example['title']

                    ?.toString() ??

                'Example',

            style:

                const TextStyle(

              fontWeight:

                  FontWeight.bold,

              fontSize: 15,

            ),

          ),

          const SizedBox(

            height: 10,

          ),

          if ((example['code']

                      ?.toString()

                      .isNotEmpty ??

                  false))

            Container(

              width:

                  double.infinity,

              padding:

                  const EdgeInsets.all(

                14,

              ),

              decoration:

                  BoxDecoration(

                color:

                    const Color(

                  0xff151923,

                ),

                borderRadius:

                    BorderRadius.circular(

                  12,

                ),

              ),

              child:

                  SingleChildScrollView(

                scrollDirection:

                    Axis.horizontal,

                child: Text(

                  example['code']

                          ?.toString() ??

                      '',

                  style:

                      const TextStyle(

                    color:

                        Colors.white,

                    fontFamily:

                        'monospace',

                    fontSize: 13,

                    height: 1.5,

                  ),

                ),

              ),

            ),

          if ((example['explanation']

                      ?.toString()

                      .isNotEmpty ??

                  false))

            Padding(

              padding:

                  const EdgeInsets.only(

                top: 10,

              ),

              child: Text(

                example['explanation']

                        ?.toString() ??

                    '',

                style:

                    const TextStyle(

                  fontSize: 13,

                  height: 1.5,

                  color:

                      Colors.grey,

                ),

              ),

            ),

        ],

      ),

    );

  }

}