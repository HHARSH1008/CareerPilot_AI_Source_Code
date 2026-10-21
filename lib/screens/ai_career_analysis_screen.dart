import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AICareerAnalysisScreen extends StatefulWidget {
  const AICareerAnalysisScreen({super.key});

  @override
  State<AICareerAnalysisScreen> createState() =>
      _AICareerAnalysisScreenState();
}

class _AICareerAnalysisScreenState
    extends State<AICareerAnalysisScreen> {
  // ============================================================
  // RENDER BACKEND
  // ============================================================

  static const String apiUrl =
      'https://career-ai-backend-fk2i.onrender.com/api/career-analysis';

  bool isLoading = true;
  bool isRegenerating = false;

  int careerMatch = 0;

  String summary = '';

  List<String> recommendedSkills = [];
  List<String> recommendedRoles = [];
  List<String> strengths = [];
  List<String> improvements = [];
  List<String> interviewTopics = [];

  List<Map<String, dynamic>> careerRoadmap = [];

  Map<String, dynamic> userData = {};

  @override
  void initState() {
    super.initState();
    loadUserAndGenerateAnalysis();
  }

  // ============================================================
  // LOAD USER
  // ============================================================

  Future<void> loadUserAndGenerateAnalysis() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        _setFallbackAndFinish();
        return;
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!snapshot.exists) {
        _setFallbackAndFinish();
        return;
      }

      userData = snapshot.data() ?? {};

      await generateAIAnalysis();
    } catch (e) {
      debugPrint('Profile load handled safely: $e');

      _createFallbackAnalysis();

      if (!mounted) return;

      setState(() {
        isLoading = false;
        isRegenerating = false;
      });
    }
  }

  // ============================================================
  // GENERATE AI ANALYSIS
  // ============================================================

  Future<void> generateAIAnalysis() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    bool aiSuccess = false;

    try {
      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type': 'application/json',
            },
            body: jsonEncode(_safeUserData()),
          )
          .timeout(
            const Duration(seconds: 45),
          );

      debugPrint(
        'Career Analysis API Status: ${response.statusCode}',
      );

      // ========================================================
      // IMPORTANT:
      // Never throw exception for 4xx/5xx.
      // Use fallback instead.
      // ========================================================

      if (response.statusCode == 200) {
        try {
          final decoded = jsonDecode(response.body);

          if (decoded is Map &&
              decoded['success'] == true &&
              decoded['analysis'] is Map) {
            final analysis =
                Map<String, dynamic>.from(
              decoded['analysis'],
            );

            _applyAnalysis(analysis);

            aiSuccess = true;
          }
        } catch (e) {
          debugPrint(
            'AI response parsing handled safely: $e',
          );
        }
      } else {
        debugPrint(
          'Career analysis service unavailable. Using local analysis.',
        );
      }
    } catch (e) {
      debugPrint(
        'Career analysis request handled safely: $e',
      );
    }

    // ============================================================
    // FALLBACK
    // ============================================================

    if (!aiSuccess) {
      _createFallbackAnalysis();
    }

    // ============================================================
    // SAVE RESULT
    // ============================================================

    await saveCareerAnalysis();

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isRegenerating = false;
    });
  }

  // ============================================================
  // SAFE FIRESTORE DATA
  // ============================================================

  Map<String, dynamic> _safeUserData() {
    return {
      'name': userData['name']?.toString() ?? '',
      'email': userData['email']?.toString() ?? '',
      'status': userData['status']?.toString() ?? '',
      'education': userData['education']?.toString() ?? '',
      'degree': userData['degree']?.toString() ?? '',
      'graduationYear':
          userData['graduationYear']?.toString() ?? '',
      'targetRole':
          userData['targetRole']?.toString() ?? '',
      'experienceLevel':
          userData['experienceLevel']?.toString() ?? '',
      'preferredLocation':
          userData['preferredLocation']?.toString() ?? '',
      'workMode':
          userData['workMode']?.toString() ?? '',
      'expectedSalary':
          userData['expectedSalary']?.toString() ?? '',
      'jobType':
          userData['jobType']?.toString() ?? '',
      'companyType':
          userData['companyType']?.toString() ?? '',
      'relocation':
          userData['relocation']?.toString() ?? '',
      'skills': _getSkills(),
    };
  }

  // ============================================================
  // GET SKILLS
  // ============================================================

  List<String> _getSkills() {
    final raw = userData['skills'];

    if (raw is List) {
      return raw
          .map(
            (e) => e.toString().trim(),
          )
          .where(
            (e) => e.isNotEmpty,
          )
          .toSet()
          .toList();
    }

    return [];
  }

  // ============================================================
  // APPLY AI RESPONSE
  // ============================================================

  void _applyAnalysis(
    Map<String, dynamic> analysis,
  ) {
    int match = 0;

    final rawMatch = analysis['careerMatch'];

    if (rawMatch is num) {
      match = rawMatch.toInt();
    } else {
      match =
          int.tryParse(
            rawMatch?.toString() ?? '',
          ) ??
          0;
    }

    careerMatch = match.clamp(0, 100);

    summary =
        analysis['summary']?.toString().trim() ?? '';

    recommendedSkills =
        _convertToStringList(
      analysis['recommendedSkills'],
    );

    recommendedRoles =
        _convertToStringList(
      analysis['recommendedRoles'],
    );

    strengths =
        _convertToStringList(
      analysis['strengths'],
    );

    improvements =
        _convertToStringList(
      analysis['improvements'],
    );

    interviewTopics =
        _convertToStringList(
      analysis['interviewTopics'],
    );

    careerRoadmap = [];

    final roadmap =
        analysis['careerRoadmap'];

    if (roadmap is List) {
      for (final item in roadmap) {
        if (item is Map) {
          careerRoadmap.add(
            Map<String, dynamic>.from(item),
          );
        }
      }
    }

    // ----------------------------------------------------------
    // If AI returned incomplete data, fill missing fields.
    // ----------------------------------------------------------

    if (careerMatch <= 0 ||
        recommendedRoles.isEmpty ||
        summary.isEmpty) {
      _createFallbackAnalysis(
        preserveExisting: true,
      );
    }
  }

  // ============================================================
  // FALLBACK ANALYSIS
  // ============================================================

  void _createFallbackAnalysis({
    bool preserveExisting = false,
  }) {
    final skills = _getSkills();

    final lowerSkills = skills
        .map(
          (e) => e.toLowerCase(),
        )
        .toList();

    final targetRole =
        userData['targetRole']
                ?.toString()
                .trim() ??
            '';

    String role =
        targetRole.isNotEmpty &&
                targetRole.toLowerCase() !=
                    'other'
            ? targetRole
            : '';

    // ----------------------------------------------------------
    // ROLE FROM SKILLS
    // ----------------------------------------------------------

    if (role.isEmpty) {
      if (lowerSkills.any(
        (s) => s.contains('flutter'),
      )) {
        role = 'Flutter Developer';
      } else if (lowerSkills.any(
        (s) =>
            s.contains('python') ||
            s.contains('django') ||
            s.contains('fastapi'),
      )) {
        role = 'Python Developer';
      } else if (lowerSkills.any(
        (s) =>
            s.contains('java') ||
            s.contains('spring'),
      )) {
        role = 'Java Developer';
      } else if (lowerSkills.any(
        (s) =>
            s.contains('cyber') ||
            s.contains('security') ||
            s.contains('network'),
      )) {
        role = 'Cyber Security Analyst';
      } else if (lowerSkills.any(
        (s) =>
            s.contains('react') ||
            s.contains('javascript'),
      )) {
        role = 'Frontend Developer';
      } else if (lowerSkills.any(
        (s) =>
            s.contains('node') ||
            s.contains('express'),
      )) {
        role = 'Backend Developer';
      } else if (lowerSkills.any(
        (s) =>
            s.contains('sql') ||
            s.contains('database') ||
            s.contains('mongodb'),
      )) {
        role = 'Database Developer';
      } else if (lowerSkills.any(
        (s) =>
            s.contains('ai') ||
            s.contains('machine learning') ||
            s == 'ml',
      )) {
        role = 'AI / ML Developer';
      } else {
        role = 'Software Developer';
      }
    }

    // ----------------------------------------------------------
    // CAREER MATCH
    // ----------------------------------------------------------

    int calculatedMatch = 55;

    if (skills.isNotEmpty) {
      calculatedMatch =
          55 + (skills.length * 5);

      if (calculatedMatch > 92) {
        calculatedMatch = 92;
      }
    }

    // ----------------------------------------------------------
    // RECOMMENDED ROLES
    // ----------------------------------------------------------

    final roles = <String>[];

    if (lowerSkills.any(
      (s) => s.contains('flutter'),
    )) {
      roles.add('Flutter Developer');
    }

    if (lowerSkills.any(
      (s) => s.contains('java'),
    )) {
      roles.add('Java Developer');
    }

    if (lowerSkills.any(
      (s) =>
          s.contains('cyber') ||
          s.contains('security'),
    )) {
      roles.add('Cyber Security Analyst');
      roles.add('SOC Analyst');
    }

    if (lowerSkills.any(
      (s) => s.contains('python'),
    )) {
      roles.add('Python Developer');
    }

    if (lowerSkills.any(
      (s) =>
          s.contains('react') ||
          s.contains('javascript'),
    )) {
      roles.add('Frontend Developer');
    }

    if (lowerSkills.any(
      (s) =>
          s.contains('node') ||
          s.contains('express'),
    )) {
      roles.add('Backend Developer');
    }

    if (lowerSkills.any(
      (s) =>
          s.contains('ai') ||
          s.contains('machine learning') ||
          s == 'ml',
    )) {
      roles.add('AI / ML Developer');
    }

    if (roles.isEmpty) {
      roles.add(role);
      roles.add('Software Developer');
      roles.add('Junior Developer');
    }

    // ----------------------------------------------------------
    // SKILLS
    // ----------------------------------------------------------

    final recommended =
        <String>[...skills];

    if (lowerSkills.any(
          (s) => s.contains('flutter'),
        ) &&
        !lowerSkills.contains('dart')) {
      recommended.add('Dart');
    }

    if (lowerSkills.any(
          (s) => s.contains('java'),
        ) &&
        !lowerSkills.contains('sql')) {
      recommended.add('SQL');
    }

    if (lowerSkills.any(
          (s) => s.contains('cyber'),
        ) &&
        !lowerSkills.contains('linux')) {
      recommended.add('Linux');
    }

    if (recommended.isEmpty) {
      recommended.addAll([
        'Problem Solving',
        'Git',
        'SQL',
        'DSA',
      ]);
    }

    // ----------------------------------------------------------
    // STRENGTHS
    // ----------------------------------------------------------

    final generatedStrengths =
        <String>[];

    if (skills.isNotEmpty) {
      generatedStrengths.add(
        'Technical skills in ${skills.take(3).join(', ')}',
      );
    }

    generatedStrengths.add(
      'Willingness to learn new technologies',
    );

    generatedStrengths.add(
      'Career-focused learning approach',
    );

    // ----------------------------------------------------------
    // IMPROVEMENTS
    // ----------------------------------------------------------

    final generatedImprovements =
        <String>[
      'Practice Data Structures and Algorithms',
      'Build real-world projects',
      'Improve technical interview preparation',
    ];

    // ----------------------------------------------------------
    // INTERVIEW TOPICS
    // ----------------------------------------------------------

    final generatedInterviewTopics =
        <String>[
      '$role technical fundamentals',
      'Object-Oriented Programming',
      'Data Structures and Algorithms',
      'Database and SQL concepts',
      'Project explanation',
      'HR interview questions',
    ];

    // ----------------------------------------------------------
    // SUMMARY
    // ----------------------------------------------------------

    final generatedSummary =
        skills.isEmpty
            ? 'Your career profile is ready. Build strong technical fundamentals, complete practical projects and prepare consistently for interviews.'
            : 'Based on your selected skills, your profile currently aligns well with $role. Focus on strengthening your technical fundamentals, building real-world projects and preparing for interviews.';

    // ----------------------------------------------------------
    // ROADMAP
    // ----------------------------------------------------------

    final generatedRoadmap =
        <Map<String, dynamic>>[
      {
        'step': 1,
        'title': 'Strengthen Fundamentals',
        'description':
            'Build strong fundamentals in your selected skills.',
      },
      {
        'step': 2,
        'title': 'Practice Coding',
        'description':
            'Solve programming and DSA problems regularly.',
      },
      {
        'step': 3,
        'title': 'Build Projects',
        'description':
            'Create practical projects related to your target role.',
      },
      {
        'step': 4,
        'title': 'Prepare Interviews',
        'description':
            'Practice technical, project and HR interview questions.',
      },
      {
        'step': 5,
        'title': 'Apply for Jobs',
        'description':
            'Apply to jobs matching your skills and career preferences.',
      },
    ];

    // ----------------------------------------------------------
    // APPLY
    // ----------------------------------------------------------

    if (!preserveExisting ||
        careerMatch <= 0) {
      careerMatch = calculatedMatch;
    }

    if (!preserveExisting ||
        summary.isEmpty) {
      summary = generatedSummary;
    }

    if (!preserveExisting ||
        recommendedRoles.isEmpty) {
      recommendedRoles =
          roles.toSet().toList();
    }

    if (!preserveExisting ||
        recommendedSkills.isEmpty) {
      recommendedSkills =
          recommended.toSet().toList();
    }

    if (!preserveExisting ||
        strengths.isEmpty) {
      strengths =
          generatedStrengths;
    }

    if (!preserveExisting ||
        improvements.isEmpty) {
      improvements =
          generatedImprovements;
    }

    if (!preserveExisting ||
        interviewTopics.isEmpty) {
      interviewTopics =
          generatedInterviewTopics;
    }

    if (!preserveExisting ||
        careerRoadmap.isEmpty) {
      careerRoadmap =
          generatedRoadmap;
    }
  }

  // ============================================================
  // CONVERT LIST
  // ============================================================

  List<String> _convertToStringList(
    dynamic value,
  ) {
    if (value is List) {
      return value
          .map(
            (item) => item.toString().trim(),
          )
          .where(
            (item) => item.isNotEmpty,
          )
          .toList();
    }

    return [];
  }

  // ============================================================
  // SAVE FIRESTORE
  // ============================================================

  Future<void> saveCareerAnalysis() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'careerAnalysis': {
            'careerMatch':
                careerMatch,
            'summary':
                summary,
            'recommendedSkills':
                recommendedSkills,
            'recommendedRoles':
                recommendedRoles,
            'strengths':
                strengths,
            'improvements':
                improvements,
            'interviewTopics':
                interviewTopics,
            'careerRoadmap':
                careerRoadmap,
            'analyzedAt':
                FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );

      debugPrint(
        'Career analysis saved.',
      );
    } catch (e) {
      // Do not show error to user.
      debugPrint(
        'Career analysis save handled safely: $e',
      );
    }
  }

  // ============================================================
  // REGENERATE
  // ============================================================

  Future<void> regenerateAnalysis() async {
    if (isRegenerating) return;

    if (!mounted) return;

    setState(() {
      isRegenerating = true;
    });

    await generateAIAnalysis();
  }

  // ============================================================
  // SAFE FALLBACK
  // ============================================================

  void _setFallbackAndFinish() {
    _createFallbackAnalysis();

    if (!mounted) return;

    setState(() {
      isLoading = false;
      isRegenerating = false;
    });
  }

  // ============================================================
  // GRADIENT
  // ============================================================

  LinearGradient get primaryGradient =>
      const LinearGradient(
    colors: [
      Color(0xff667EEA),
      Color(0xff764BA2),
    ],
  );

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor:
            const Color(0xffF8FAFC),
        body: Center(
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration:
                    BoxDecoration(
                  gradient:
                      primaryGradient,
                  borderRadius:
                      BorderRadius.circular(
                    24,
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 42,
                ),
              ),
              const SizedBox(
                height: 25,
              ),
              const Text(
                'AI is analyzing your career...',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xff111827),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              const Text(
                'Finding the best career path for you',
                textAlign:
                    TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      Color(0xff64748B),
                ),
              ),
              const SizedBox(
                height: 25,
              ),
              const SizedBox(
                width: 180,
                child:
                    LinearProgressIndicator(),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor:
          const Color(0xffF8FAFC),

      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,

        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_rounded,
            color:
                Color(0xff111827),
          ),
        ),

        title: const Text(
          'AI Career Analysis',
          style: TextStyle(
            color:
                Color(0xff111827),
            fontSize: 19,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        centerTitle: true,

        actions: [
          IconButton(
            tooltip:
                'Regenerate Analysis',
            onPressed:
                isRegenerating
                    ? null
                    : regenerateAnalysis,
            icon: const Icon(
              Icons.refresh_rounded,
              color:
                  Color(0xff4F46E5),
            ),
          ),
        ],
      ),

      body: SafeArea(
        child:
            SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            20,
            10,
            20,
            35,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              _headerCard(),

              const SizedBox(
                height: 18,
              ),

              _careerMatchCard(),

              const SizedBox(
                height: 18,
              ),

              _summaryCard(),

              const SizedBox(
                height: 18,
              ),

              _section(
                title:
                    'Your Strengths',
                icon:
                    Icons.emoji_events_rounded,
                items: strengths,
              ),

              const SizedBox(
                height: 18,
              ),

              _section(
                title:
                    'Areas to Improve',
                icon:
                    Icons.trending_up_rounded,
                items:
                    improvements,
              ),

              const SizedBox(
                height: 18,
              ),

              _section(
                title:
                    'Recommended Skills',
                icon:
                    Icons.school_rounded,
                items:
                    recommendedSkills,
              ),

              const SizedBox(
                height: 18,
              ),

              _rolesCard(),

              const SizedBox(
                height: 18,
              ),

              _roadmapCard(),

              const SizedBox(
                height: 18,
              ),

              _section(
                title:
                    'Interview Preparation',
                icon:
                    Icons.question_answer_rounded,
                items:
                    interviewTopics,
              ),

              const SizedBox(
                height: 25,
              ),

              _regenerateButton(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _headerCard() {
    final name =
        userData['name']
                ?.toString()
                .trim()
                .isNotEmpty ==
            true
        ? userData['name'].toString()
        : 'Your';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),

      decoration:
          BoxDecoration(
        gradient:
            primaryGradient,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 34,
          ),

          const SizedBox(
            height: 14,
          ),

          Text(
            '$name Career Analysis',
            style:
                const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          const Text(
            'Your personalized career insights based on your profile and skills.',
            style:
                TextStyle(
              color:
                  Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CAREER MATCH
  // ============================================================

  Widget _careerMatchCard() {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(22),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color:
              const Color(0xffE5E7EB),
        ),
      ),

      child: Row(
        children: [
          SizedBox(
            width: 100,
            height: 100,

            child: Stack(
              alignment:
                  Alignment.center,

              children: [
                SizedBox(
                  width: 100,
                  height: 100,

                  child:
                      CircularProgressIndicator(
                    value:
                        careerMatch / 100,
                    strokeWidth: 9,
                    backgroundColor:
                        const Color(
                      0xffE8EAF6,
                    ),
                    valueColor:
                        const AlwaysStoppedAnimation<
                            Color>(
                      Color(0xff667EEA),
                    ),
                  ),
                ),

                Text(
                  '$careerMatch%',
                  style:
                      const TextStyle(
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xff172033),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            width: 20,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                const Text(
                  'Career Match',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                Text(
                  recommendedRoles
                          .isNotEmpty
                      ? recommendedRoles
                          .first
                      : 'Software Developer',

                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,

                  style:
                      const TextStyle(
                    color:
                        Color(0xff172033),
                    fontSize: 20,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                const Text(
                  'Based on your skills and profile',
                  style:
                      TextStyle(
                    color:
                        Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _summaryCard() {
    return _whiteCard(
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          const Text(
            'Career Summary',
            style:
                TextStyle(
              fontSize: 18,
              fontWeight:
                  FontWeight.bold,
              color:
                  Color(0xff172033),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            summary.isNotEmpty
                ? summary
                : 'Your career profile is ready. Continue building your skills and projects.',

            style:
                const TextStyle(
              fontSize: 14,
              color:
                  Color(0xff687086),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _section({
    required String title,
    required IconData icon,
    required List<String> items,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        Row(
          children: [
            Icon(
              icon,
              color:
                  const Color(0xff667EEA),
              size: 22,
            ),

            const SizedBox(
              width: 8,
            ),

            Text(
              title,
              style:
                  const TextStyle(
                fontSize: 19,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xff172033),
              ),
            ),
          ],
        ),

        const SizedBox(
          height: 12,
        ),

        if (items.isEmpty)
          _whiteCard(
            child: const Text(
              'No information available yet.',
              style:
                  TextStyle(
                color:
                    Colors.grey,
              ),
            ),
          )
        else
          ...items.take(6).map(
            (item) => Container(
              width: double.infinity,
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),

              padding:
                  const EdgeInsets.all(
                15,
              ),

              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
                border: Border.all(
                  color:
                      const Color(
                    0xffE8E9F0,
                  ),
                ),
              ),

              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [
                  Container(
                    width: 30,
                    height: 30,

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xffEEF0FF,
                      ),
                      shape:
                          BoxShape.circle,
                    ),

                    child: const Icon(
                      Icons.check_rounded,
                      size: 18,
                      color:
                          Color(
                        0xff667EEA,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Text(
                      item,
                      style:
                          const TextStyle(
                        fontSize: 13,
                        color:
                            Color(
                          0xff374151,
                        ),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // ROLES
  // ============================================================

  Widget _rolesCard() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        const Text(
          'Recommended Roles',
          style:
              TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.bold,
            color:
                Color(0xff172033),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        if (recommendedRoles.isEmpty)
          _whiteCard(
            child: const Text(
              'No roles available yet.',
              style:
                  TextStyle(
                color:
                    Colors.grey,
              ),
            ),
          )
        else
          ...recommendedRoles
              .take(6)
              .map(
                (role) => Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 10,
                  ),

                  padding:
                      const EdgeInsets.all(
                    16,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,
                    borderRadius:
                        BorderRadius.circular(
                      17,
                    ),
                    border: Border.all(
                      color:
                          const Color(
                        0xffE8E9F0,
                      ),
                    ),
                  ),

                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,

                        decoration:
                            BoxDecoration(
                          gradient:
                              primaryGradient,
                          borderRadius:
                              BorderRadius.circular(
                            13,
                          ),
                        ),

                        child: const Icon(
                          Icons.work_outline,
                          color:
                              Colors.white,
                        ),
                      ),

                      const SizedBox(
                        width: 13,
                      ),

                      Expanded(
                        child: Text(
                          role,
                          style:
                              const TextStyle(
                            fontSize: 15,
                            fontWeight:
                                FontWeight.w600,
                            color:
                                Color(
                              0xff172033,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  // ============================================================
  // ROADMAP
  // ============================================================

  Widget _roadmapCard() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,

      children: [
        const Text(
          'Career Roadmap',
          style:
              TextStyle(
            fontSize: 19,
            fontWeight:
                FontWeight.bold,
            color:
                Color(0xff172033),
          ),
        ),

        const SizedBox(
          height: 12,
        ),

        _whiteCard(
          child: Column(
            children:
                careerRoadmap
                    .take(5)
                    .map(
                      (item) {
                        final step =
                            item['step']
                                    ?.toString() ??
                                '';

                        final title =
                            item['title']
                                    ?.toString() ??
                                'Career Step';

                        final description =
                            item['description']
                                    ?.toString() ??
                                '';

                        return Padding(
                          padding:
                              const EdgeInsets
                                  .only(
                            bottom: 18,
                          ),

                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment
                                    .start,

                            children: [
                              Container(
                                width: 38,
                                height: 38,

                                decoration:
                                    BoxDecoration(
                                  color:
                                      const Color(
                                    0xffEEF0FF,
                                  ),
                                  shape:
                                      BoxShape.circle,
                                ),

                                child: Center(
                                  child: Text(
                                    step,
                                    style:
                                        const TextStyle(
                                      color:
                                          Color(
                                        0xff667EEA,
                                      ),
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(
                                width: 13,
                              ),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,

                                  children: [
                                    Text(
                                      title,
                                      style:
                                          const TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            FontWeight
                                                .bold,
                                      ),
                                    ),

                                    const SizedBox(
                                      height: 4,
                                    ),

                                    Text(
                                      description,
                                      style:
                                          const TextStyle(
                                        fontSize: 12,
                                        color:
                                            Colors.grey,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    )
                    .toList(),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // WHITE CARD
  // ============================================================

  Widget _whiteCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,

      padding:
          const EdgeInsets.all(18),

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
              const Color(0xffE8E9F0),
        ),
      ),

      child: child,
    );
  }

  // ============================================================
  // REGENERATE BUTTON
  // ============================================================

  Widget _regenerateButton() {
    return SizedBox(
      width: double.infinity,

      height: 52,

      child: ElevatedButton.icon(
        onPressed:
            isRegenerating
                ? null
                : regenerateAnalysis,

        icon: isRegenerating
            ? const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color:
                      Colors.white,
                ),
              )
            : const Icon(
                Icons.refresh_rounded,
              ),

        label: Text(
          isRegenerating
              ? 'Analyzing...'
              : 'Regenerate Analysis',
        ),

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              const Color(0xff667EEA),
          foregroundColor:
              Colors.white,
          elevation: 0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              15,
            ),
          ),
        ),
      ),
    );
  }
}