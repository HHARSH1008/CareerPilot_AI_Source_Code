import 'package:ai_career_mentor/screens/learning_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ai_chat_screen.dart';
import 'discover_career_screen.dart';
import 'jobs_screen.dart';
import 'skill_learning_screen.dart';
import 'learning_screen.dart';
import 'career_roadmap_screen.dart';
import 'profile_screen.dart';
// import '../theme/theme_controller.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const primary = Color(0xff667EEA);
  static const secondary = Color(0xff764BA2);
  static const dark = Color(0xff172033);
  static const bg = Color(0xffF6F7FB);

  bool isLoading = true;
  int selectedIndex = 0;

  String name = 'User';
  String targetRole = 'Career Goal';
  int careerMatch = 0;

  List<String> selectedSkills = [];
  List<String> recommendedRoles = [];
  List<String> recommendedSkills = [];
  List<String> strengths = [];
  List<String> improvements = [];

  @override
  void initState() {
    super.initState();
    loadDashboard();
  }

  List<String> _list(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList();
    }

    return [];
  }

  // ------------------------------------------------------------
  // FALLBACK CAREER MATCH
  // ------------------------------------------------------------

  int _calculateFallbackMatch(
    List<String> skills,
    String role,
  ) {
    if (skills.isEmpty) return 0;

    final r = role.toLowerCase();
    final s = skills.map((e) => e.toLowerCase()).toList();

    List<String> expected;

    if (r.contains('flutter') || r.contains('mobile')) {
      expected = [
        'flutter',
        'dart',
        'firebase',
        'git',
        'api',
      ];
    } else if (r.contains('python')) {
      expected = [
        'python',
        'sql',
        'git',
        'django',
        'api',
      ];
    } else if (r.contains('java')) {
      expected = [
        'java',
        'sql',
        'git',
        'spring',
        'api',
      ];
    } else if (r.contains('react') ||
        r.contains('frontend')) {
      expected = [
        'react',
        'javascript',
        'html',
        'css',
        'git',
      ];
    } else if (r.contains('cyber') ||
        r.contains('security')) {
      expected = [
        'cyber security',
        'networking',
        'linux',
        'git',
        'python',
      ];
    } else {
      expected = [
        'git',
        'github',
        'java',
        'python',
        'sql',
        'flutter',
        'dart',
      ];
    }

    final matches = expected
        .where(
          (e) => s.any(
            (x) =>
                x == e ||
                x.contains(e) ||
                e.contains(x),
          ),
        )
        .length;

    final score =
        ((matches / expected.length) * 100).round();

    return score.clamp(20, 95);
  }

  // ------------------------------------------------------------
  // FALLBACK ROLES
  // ------------------------------------------------------------

  List<String> _fallbackRoles(
    List<String> skills,
  ) {
    final s =
        skills.map((e) => e.toLowerCase()).toList();

    final roles = <String>[];

    if (s.any(
      (x) =>
          x.contains('flutter') ||
          x == 'dart',
    )) {
      roles.add('Flutter Developer');
      roles.add('Mobile App Developer');
      roles.add('Dart Developer');
    }

    if (s.any((x) => x == 'java')) {
      roles.add('Java Developer');
    }

    if (s.any(
      (x) =>
          x.contains('cyber') ||
          x.contains('security'),
    )) {
      roles.add('Cyber Security Analyst');
    }

    if (s.any((x) => x == 'python')) {
      roles.add('Python Developer');
    }

    if (s.any(
      (x) =>
          x.contains('react') ||
          x == 'javascript',
    )) {
      roles.add('Frontend Developer');
    }

    if (s.any(
      (x) =>
          x == 'sql' ||
          x.contains('database'),
    )) {
      roles.add('Backend / Database Developer');
    }

    if (roles.isEmpty) {
      roles.add('Software Developer');
      roles.add('Junior Software Developer');
    }

    return roles.take(6).toList();
  }

  // ------------------------------------------------------------
  // FALLBACK STRENGTHS
  // ------------------------------------------------------------

  List<String> _fallbackStrengths(
    List<String> skills,
  ) {
    return skills
        .take(3)
        .map(
          (s) =>
              'You have hands-on knowledge of $s.',
        )
        .toList();
  }

  // ------------------------------------------------------------
  // FALLBACK IMPROVEMENTS
  // ------------------------------------------------------------

  List<String> _fallbackImprovements(
    List<String> skills,
  ) {
    final result = <String>[];

    if (!skills.any(
      (s) =>
          s.toLowerCase() == 'git' ||
          s.toLowerCase() == 'github',
    )) {
      result.add(
        'Strengthen Git and GitHub workflow.',
      );
    }

    result.add(
      'Build 2–3 real projects using your selected skills.',
    );

    result.add(
      'Practice DSA and technical interview questions regularly.',
    );

    return result.take(3).toList();
  }

  // ------------------------------------------------------------
  // PREPARE RECOMMENDED ROLES
  // ------------------------------------------------------------

  List<String> _prepareRecommendedRoles({
    required List<String> aiRoles,
    required List<String> skills,
    required String targetRole,
  }) {
    final result = <String>[];

    final cleanTarget = targetRole.trim();

    // Target role gets first priority.
    if (cleanTarget.isNotEmpty &&
        cleanTarget.toLowerCase() != 'career goal' &&
        cleanTarget.toLowerCase() != 'other') {
      result.add(cleanTarget);
    }

    // Add AI recommended roles.
    for (final role in aiRoles) {
      final cleanRole = role.trim();

      if (cleanRole.isEmpty) continue;

      final alreadyExists = result.any(
        (existing) =>
            existing.toLowerCase() ==
            cleanRole.toLowerCase(),
      );

      if (!alreadyExists) {
        result.add(cleanRole);
      }
    }

    // If AI roles are empty, use fallback.
    if (result.isEmpty) {
      final fallback = _fallbackRoles(skills);

      for (final role in fallback) {
        if (!result.any(
          (existing) =>
              existing.toLowerCase() ==
              role.toLowerCase(),
        )) {
          result.add(role);
        }
      }
    }

    return result.take(6).toList();
  }

  // ------------------------------------------------------------
  // LOAD DASHBOARD
  // ------------------------------------------------------------

  Future<void> loadDashboard() async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) {
        if (mounted) {
          setState(() {
            isLoading = false;
          });
        }

        return;
      }

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final data = doc.data() ?? {};

      final rawAnalysis =
          data['careerAnalysis'];

      final analysis =
          rawAnalysis is Map
              ? Map<String, dynamic>.from(
                  rawAnalysis,
                )
              : <String, dynamic>{};

      // ----------------------------------------------------------
      // PROFILE DATA
      // ----------------------------------------------------------

      final skills =
          _list(data['skills']);

      final aiRoles =
          _list(
        analysis['recommendedRoles'],
      );

      final aiRecommendedSkills =
          _list(
        analysis['recommendedSkills'],
      );

      final aiStrengths =
          _list(
        analysis['strengths'],
      );

      final aiImprovements =
          _list(
        analysis['improvements'],
      );

      // ----------------------------------------------------------
      // CAREER MATCH
      // ----------------------------------------------------------

      int aiMatch =
          int.tryParse(
                analysis['careerMatch']
                        ?.toString() ??
                    '',
              ) ??
              0;

      aiMatch =
          aiMatch.clamp(0, 100);

      // ----------------------------------------------------------
      // TARGET ROLE
      // ----------------------------------------------------------

      final role =
          data['targetRole']
                      ?.toString()
                      .trim()
                      .isNotEmpty ==
                  true
              ? data['targetRole']
                  .toString()
                  .trim()
              : 'Career Goal';

      // ----------------------------------------------------------
      // RECOMMENDED ROLES
      // ----------------------------------------------------------

      final roles =
          _prepareRecommendedRoles(
        aiRoles: aiRoles,
        skills: skills,
        targetRole: role,
      );

      final displayRole =
          (role.toLowerCase() == 'other' ||
                  role.toLowerCase() ==
                      'career goal')
              ? (roles.isNotEmpty
                  ? roles.first
                  : 'Software Developer')
              : role;

      // ----------------------------------------------------------
      // UPDATE UI
      // ----------------------------------------------------------

      if (mounted) {
        setState(() {
          name =
              data['name']
                          ?.toString()
                          .trim()
                          .isNotEmpty ==
                      true
                  ? data['name']
                      .toString()
                      .trim()
                  : (user.displayName ??
                      'User');

          targetRole =
              displayRole;

          selectedSkills =
              skills;

          careerMatch =
              aiMatch > 0
                  ? aiMatch
                  : _calculateFallbackMatch(
                      skills,
                      displayRole,
                    );

          recommendedRoles =
              roles;

          recommendedSkills =
              aiRecommendedSkills;

          strengths =
              aiStrengths.isNotEmpty
                  ? aiStrengths
                  : _fallbackStrengths(
                      skills,
                    );

          improvements =
              aiImprovements.isNotEmpty
                  ? aiImprovements
                  : _fallbackImprovements(
                      skills,
                    );

          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint(
        'Dashboard Error: $e',
      );

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ------------------------------------------------------------
  // OPEN YOUTUBE LEARNING
  // ------------------------------------------------------------

  void openLearning(
    String skill,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            SkillLearningScreen(
          skill: skill,
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // OPEN AI LEARNING
  // ------------------------------------------------------------

  void openAILearning(
    String skill,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            LearningScreen(
          skill,
          category: '',
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // ROLE DETAILS
  // ------------------------------------------------------------

  void _showRoleDetails(
    String role,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return Container(
          padding:
              const EdgeInsets.fromLTRB(
            22,
            12,
            22,
            30,
          ),
          decoration:
              const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 45,
                  height: 5,
                  decoration:
                      BoxDecoration(
                    color:
                        Colors.grey.shade300,
                    borderRadius:
                        BorderRadius.circular(
                      10,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                height: 22,
              ),

              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration:
                        BoxDecoration(
                      gradient:
                          const LinearGradient(
                        colors: [
                          primary,
                          secondary,
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        18,
                      ),
                    ),
                    child: const Icon(
                      Icons
                          .work_outline_rounded,
                      color:
                          Colors.white,
                      size: 29,
                    ),
                  ),

                  const SizedBox(
                    width: 15,
                  ),

                  Expanded(
                    child: Text(
                      role,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                        color: dark,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 22,
              ),

              const Text(
                'Why this role?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight:
                      FontWeight.bold,
                  color: dark,
                ),
              ),

              const SizedBox(
                height: 8,
              ),

              Text(
                'This role is recommended based on your selected skills and career profile.',
                style:
                    TextStyle(
                  fontSize: 13,
                  height: 1.5,
                  color:
                      Colors.grey.shade700,
                ),
              ),

              const SizedBox(
                height: 18,
              ),

              if (selectedSkills
                  .isNotEmpty) ...[
                const Text(
                  'Relevant Skills',
                  style:
                      TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                    color: dark,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      selectedSkills
                          .take(6)
                          .map(
                            (skill) =>
                                Container(
                              padding:
                                  const EdgeInsets
                                      .symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xffEEF0FF,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  20,
                                ),
                              ),
                              child: Text(
                                skill,
                                style:
                                    const TextStyle(
                                  fontSize:
                                      12,
                                  fontWeight:
                                      FontWeight
                                          .w600,
                                  color:
                                      primary,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                ),
              ],

              const SizedBox(
                height: 24,
              ),

              SizedBox(
                width:
                    double.infinity,
                height: 50,
                child:
                    ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                    );

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const JobsScreen(),
                      ),
                    );
                  },
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        primary,
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
                  child:
                      const Text(
                    'Explore Jobs',
                    style:
                        TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ------------------------------------------------------------
  // LOGOUT
  // ------------------------------------------------------------

  Future<void> logoutUser() async {
    final confirm =
        await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
        title:
            const Text('Logout'),
        content: const Text(
          'Are you sure you want to logout?',
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(
              context,
              false,
            ),
            child:
                const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(
              context,
              true,
            ),
            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  primary,
              foregroundColor:
                  Colors.white,
            ),
            child:
                const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      return;
    }

    await FirebaseAuth.instance
        .signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) =>
            const DiscoverCareerScreen(),
      ),
      (_) => false,
    );
  }

  // ------------------------------------------------------------
  // BUILD
  // ------------------------------------------------------------

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: isLoading
            ? const Center(
                child:
                    CircularProgressIndicator(
                  color: primary,
                ),
              )
            : RefreshIndicator(
                onRefresh:
                    loadDashboard,
                color: primary,
                child:
                    SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    100,
                  ),
                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _header(),

                      const SizedBox(
                        height: 24,
                      ),

                      _careerMatch(),

                      const SizedBox(
                        height: 28,
                      ),

                      _title(
                        'Recommended Roles',
                        'AI-powered roles based on your career profile',
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      recommendedRoles.isEmpty
                          ? _empty(
                              'No recommended roles available yet.',
                            )
                          : SizedBox(
                              // FIXED: increased height
                              height: 145,
                              child:
                                  ListView.separated(
                                scrollDirection:
                                    Axis.horizontal,
                                itemCount:
                                    recommendedRoles
                                        .length,
                                separatorBuilder:
                                    (
                                  _,
                                  __,
                                ) =>
                                        const SizedBox(
                                  width: 12,
                                ),
                                itemBuilder:
                                    (
                                  _,
                                  i,
                                ) =>
                                        _roleCard(
                                  recommendedRoles[
                                      i],
                                  i,
                                ),
                              ),
                            ),

                      const SizedBox(
                        height: 28,
                      ),

                      _aiCard(),

                      const SizedBox(
                        height: 14,
                      ),

                      _resumeCard(),

                      const SizedBox(
                        height: 28,
                      ),

                      _title(
                        'Skills to Learn',
                        'Based on the skills you selected',
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      if (selectedSkills
                          .isEmpty)
                        _empty(
                          'No skills selected yet.',
                        )
                      else
                        ...selectedSkills
                            .map(
                          (
                            skill,
                          ) =>
                              Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 10,
                            ),
                            child:
                                _skillCard(
                              skill,
                            ),
                          ),
                        ),

                      const SizedBox(
                        height: 18,
                      ),

                      _title(
                        'Learning',
                        'Personalized fundamentals for your selected skills',
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      if (selectedSkills
                          .isEmpty)
                        _empty(
                          'Select skills to get a personalized learning path.',
                        )
                      else
                        ...selectedSkills
                            .take(4)
                            .map(
                          (
                            skill,
                          ) =>
                              Padding(
                            padding:
                                const EdgeInsets
                                    .only(
                              bottom: 12,
                            ),
                            child:
                                _learningCard(
                              skill,
                            ),
                          ),
                        ),

                      if (selectedSkills
                          .isNotEmpty)
                        Align(
                          alignment:
                              Alignment
                                  .centerRight,
                          child:
                              TextButton(
                            onPressed:
                                () =>
                                    openLearning(
                              selectedSkills
                                  .first,
                            ),
                            child:
                                const Text(
                              'Open Learning →',
                              style:
                                  TextStyle(
                                color:
                                    primary,
                                fontWeight:
                                    FontWeight
                                        .bold,
                              ),
                            ),
                          ),
                        ),

                      const SizedBox(
                        height: 18,
                      ),

                      _title(
                        'Your Career Roadmap',
                        'Your journey to your dream job',
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      _roadmap(),

                      const SizedBox(
                        height: 28,
                      ),

                      if (strengths
                          .isNotEmpty) ...[
                        _title(
                          'Your Strengths',
                          'What you are already good at',
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        ...strengths
                            .take(3)
                            .map(
                          (
                            e,
                          ) =>
                              _info(
                            Icons
                                .check_circle,
                            e,
                          ),
                        ),

                        const SizedBox(
                          height: 18,
                        ),
                      ],

                      if (improvements
                          .isNotEmpty) ...[
                        _title(
                          'Areas to Improve',
                          'Focus on these areas',
                        ),

                        const SizedBox(
                          height: 12,
                        ),

                        ...improvements
                            .take(3)
                            .map(
                          (
                            e,
                          ) =>
                              _info(
                            Icons
                                .trending_up,
                            e,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      bottomNavigationBar:
          _bottomNav(),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _header() =>
      Row(
        children: [
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello, $name 👋',
                  style:
                      const TextStyle(
                    fontSize: 26,
                    fontWeight:
                        FontWeight.bold,
                    color: dark,
                  ),
                ),

                const SizedBox(
                  height: 5,
                ),

                const Text(
                  "Let's build your career 🚀",
                  style: TextStyle(
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          GestureDetector(
            onTap:
                logoutUser,
            child:
                Container(
              width: 48,
              height: 48,
              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    primary,
                    secondary,
                  ],
                ),
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .logout_rounded,
                color:
                    Colors.white,
              ),
            ),
          ),
        ],
      );

  // ------------------------------------------------------------
  // CAREER MATCH
  // ------------------------------------------------------------

  Widget _careerMatch() =>
      Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.all(
          22,
        ),
        decoration:
            BoxDecoration(
          gradient:
              const LinearGradient(
            colors: [
              primary,
              secondary,
            ],
          ),
          borderRadius:
              BorderRadius.circular(
            24,
          ),
        ),
        child:
            Row(
          children: [
            SizedBox(
              width: 92,
              height: 92,
              child:
                  Stack(
                alignment:
                    Alignment.center,
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child:
                        CircularProgressIndicator(
                      value:
                          careerMatch /
                              100,
                      strokeWidth:
                          8,
                      backgroundColor:
                          Colors.white24,
                      valueColor:
                          const AlwaysStoppedAnimation<
                              Color>(
                        Colors.white,
                      ),
                    ),
                  ),

                  Text(
                    '$careerMatch%',
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          20,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width: 20,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment
                        .start,
                children: [
                  const Text(
                    'Career Match',
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  Text(
                    targetRole,
                    maxLines: 2,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      color:
                          Colors.white,
                      fontSize:
                          20,
                      fontWeight:
                          FontWeight
                              .bold,
                    ),
                  ),

                  const SizedBox(
                    height: 5,
                  ),

                  const Text(
                    'Based on your skills and career profile',
                    style:
                        TextStyle(
                      color:
                          Colors.white70,
                      fontSize:
                          12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  // ------------------------------------------------------------
  // SECTION TITLE
  // ------------------------------------------------------------

  Widget _title(
    String title,
    String subtitle,
  ) =>
      Row(
        children: [
          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    fontSize:
                        19,
                    fontWeight:
                        FontWeight
                            .bold,
                    color: dark,
                  ),
                ),

                const SizedBox(
                  height: 3,
                ),

                Text(
                  subtitle,
                  style:
                      const TextStyle(
                    fontSize:
                        12,
                    color:
                        Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          const Icon(
            Icons
                .arrow_forward_ios,
            size: 14,
            color:
                Colors.grey,
          ),
        ],
      );

  // ------------------------------------------------------------
  // RECOMMENDED ROLE CARD
  // ------------------------------------------------------------

  Widget _roleCard(
    String role,
    int index,
  ) {
    final isTargetRole =
        role.toLowerCase() ==
        targetRole.toLowerCase();

    return InkWell(
      onTap: () =>
          _showRoleDetails(
        role,
      ),
      borderRadius:
          BorderRadius.circular(
        20,
      ),
      child:
          Container(
        width: 205,
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
            20,
          ),
          border:
              Border.all(
            color: isTargetRole
                ? primary
                : const Color(
                    0xffE5E7EF,
                  ),
            width:
                isTargetRole
                    ? 1.5
                    : 1,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black
                      .withOpacity(
                0.03,
              ),
              blurRadius:
                  8,
              offset:
                  const Offset(
                0,
                3,
              ),
            ),
          ],
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            // TOP ICON + GOAL
            Row(
              children: [
                Container(
                  width:
                      43,
                  height:
                      43,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xffEEF0FF,
                    ),
                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),
                  child:
                      const Icon(
                    Icons
                        .work_outline_rounded,
                    color:
                        primary,
                    size:
                        22,
                  ),
                ),

                const Spacer(),

                if (isTargetRole)
                  Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal:
                          8,
                      vertical:
                          4,
                    ),
                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xffEEF0FF,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        20,
                      ),
                    ),
                    child:
                        const Text(
                      'Goal',
                      style:
                          TextStyle(
                        fontSize:
                            9,
                        fontWeight:
                            FontWeight
                                .bold,
                        color:
                            primary,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            // ROLE NAME
            Expanded(
              child:
                  Text(
                role,
                maxLines:
                    2,
                overflow:
                    TextOverflow
                        .ellipsis,
                style:
                    const TextStyle(
                  fontSize:
                      14,
                  fontWeight:
                      FontWeight
                          .w700,
                  color:
                      dark,
                ),
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            // BOTTOM LABEL
            Row(
              children: [
                const Icon(
                  Icons
                      .auto_awesome,
                  size:
                      12,
                  color:
                      primary,
                ),

                const SizedBox(
                  width: 4,
                ),

                Expanded(
                  child:
                      Text(
                    isTargetRole
                        ? 'Your target role'
                        : 'AI recommended',
                    maxLines:
                        1,
                    overflow:
                        TextOverflow
                            .ellipsis,
                    style:
                        const TextStyle(
                      fontSize:
                          10,
                      color:
                          Colors.grey,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 4,
                ),

                const Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size:
                      11,
                  color:
                      primary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // AI CARD
  // ------------------------------------------------------------

  Widget _aiCard() =>
      InkWell(
        onTap: () =>
            Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AIChatScreen(),
          ),
        ),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        child:
            Container(
          padding:
              const EdgeInsets.all(
            20,
          ),
          decoration:
              BoxDecoration(
            color:
                Colors.white,
            borderRadius:
                BorderRadius.circular(
              22,
            ),
          ),
          child:
              Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      primary,
                      secondary,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .smart_toy_outlined,
                  color:
                      Colors.white,
                  size:
                      28,
                ),
              ),

              const SizedBox(
                width: 15,
              ),

              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Ask AI Career Mentor',
                      style:
                          TextStyle(
                        fontSize:
                            16,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),

                    SizedBox(
                      height: 5,
                    ),

                    Text(
                      'Get personalized career guidance anytime.',
                      style:
                          TextStyle(
                        fontSize:
                            12,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .arrow_forward_ios,
                size:
                    17,
                color:
                    Colors.grey,
              ),
            ],
          ),
        ),
      );

  // ------------------------------------------------------------
  // RESUME CARD
  // ------------------------------------------------------------

  Widget _resumeCard() =>
      InkWell(
        onTap: () =>
            ScaffoldMessenger
                .of(context)
                .showSnackBar(
          const SnackBar(
            content: Text(
              'Resume Builder is Coming Soon 🚀',
            ),
            behavior:
                SnackBarBehavior
                    .floating,
          ),
        ),
        child:
            Container(
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
            border:
                Border.all(
              color:
                  const Color(
                0xffE8E9F0,
              ),
            ),
          ),
          child:
              Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xffEEF0FF,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .description_outlined,
                  color:
                      primary,
                  size:
                      28,
                ),
              ),

              const SizedBox(
                width: 15,
              ),

              const Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Resume Builder',
                          style:
                              TextStyle(
                            fontSize:
                                16,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                dark,
                          ),
                        ),

                        SizedBox(
                          width: 8,
                        ),

                        Text(
                          'Coming Soon',
                          style:
                              TextStyle(
                            fontSize:
                                10,
                            fontWeight:
                                FontWeight
                                    .bold,
                            color:
                                primary,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(
                      height: 5,
                    ),

                    Text(
                      'Create a professional resume with AI',
                      style:
                          TextStyle(
                        fontSize:
                            12,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .arrow_forward_ios,
                size:
                    16,
                color:
                    Colors.grey,
              ),
            ],
          ),
        ),
      );

  // ------------------------------------------------------------
  // SKILL CARD
  // ------------------------------------------------------------

  Widget _skillCard(
    String skill,
  ) =>
      InkWell(
        onTap: () =>
            openLearning(
          skill,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        child:
            Container(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 15,
            vertical: 13,
          ),
          decoration:
              BoxDecoration(
            color:
                Colors.white,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            border:
                Border.all(
              color:
                  const Color(
                0xffE1E3ED,
              ),
            ),
          ),
          child:
              Row(
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
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
                child:
                    Icon(
                  _icon(skill),
                  size:
                      19,
                  color:
                      primary,
                ),
              ),

              const SizedBox(
                width: 12,
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
                            14,
                        fontWeight:
                            FontWeight
                                .w600,
                        color:
                            Color(
                          0xff4C55A5,
                        ),
                      ),
                    ),

                    const SizedBox(
                      height: 3,
                    ),

                    const Text(
                      'Open dynamic learning playlists',
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

              const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size:
                    13,
                color:
                    primary,
              ),
            ],
          ),
        ),
      );

  // ------------------------------------------------------------
  // LEARNING CARD
  // ------------------------------------------------------------

  Widget _learningCard(
    String skill,
  ) =>
      InkWell(
        onTap: () =>
            openAILearning(
          skill,
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child:
            Container(
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
              20,
            ),
            border:
                Border.all(
              color:
                  const Color(
                0xffE8E9F0,
              ),
            ),
          ),
          child:
              Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xffEEF0FF,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    17,
                  ),
                ),
                child:
                    Icon(
                  _icon(skill),
                  color:
                      primary,
                  size:
                      28,
                ),
              ),

              const SizedBox(
                width: 15,
              ),

              Expanded(
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Learn $skill',
                      style:
                          const TextStyle(
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight
                                .bold,
                        color:
                            dark,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    const Text(
                      'Dynamic courses • YouTube playlists • Learn in app',
                      style:
                          TextStyle(
                        fontSize:
                            12,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons
                    .arrow_forward_ios,
                size:
                    16,
                color:
                    Colors.grey,
              ),
            ],
          ),
        ),
      );

  // ------------------------------------------------------------
  // ROADMAP
  // ------------------------------------------------------------

  Widget _roadmap() =>
      InkWell(
        onTap: () =>
            Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const CareerRoadmapScreen(),
          ),
        ),
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        child:
            Container(
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
            border:
                Border.all(
              color:
                  const Color(
                0xffE8E9F0,
              ),
            ),
          ),
          child:
              Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  gradient:
                      const LinearGradient(
                    colors: [
                      primary,
                      secondary,
                    ],
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .route_rounded,
                  color:
                      Colors.white,
                  size:
                      27,
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
                      targetRole,
                      maxLines:
                          1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize:
                            15,
                        fontWeight:
                            FontWeight
                                .bold,
                        color:
                            dark,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Text(
                      selectedSkills
                              .isEmpty
                          ? 'Generate your personalized career roadmap'
                          : '${selectedSkills.take(3).join(' • ')} • AI Roadmap',
                      maxLines:
                          2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize:
                            11,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              const Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size:
                    16,
                color:
                    primary,
              ),
            ],
          ),
        ),
      );

  // ------------------------------------------------------------
  // INFO
  // ------------------------------------------------------------

  Widget _info(
    IconData icon,
    String text,
  ) =>
      Container(
        width:
            double.infinity,
        margin:
            const EdgeInsets.only(
          bottom: 10,
        ),
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          color:
              Colors.white,
          borderRadius:
              BorderRadius.circular(
            15,
          ),
        ),
        child:
            Row(
          children: [
            Icon(
              icon,
              color:
                  primary,
              size:
                  20,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  Text(
                text,
                style:
                    const TextStyle(
                  fontSize:
                      13,
                ),
              ),
            ),
          ],
        ),
      );

  // ------------------------------------------------------------
  // EMPTY
  // ------------------------------------------------------------

  Widget _empty(
    String text,
  ) =>
      Container(
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
            18,
          ),
          border:
              Border.all(
            color:
                const Color(
              0xffE8E9F0,
            ),
          ),
        ),
        child:
            Row(
          children: [
            const Icon(
              Icons
                  .info_outline,
              color:
                  primary,
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  Text(
                text,
                style:
                    const TextStyle(
                  color:
                      Colors.grey,
                  fontSize:
                      13,
                ),
              ),
            ),
          ],
        ),
      );

  // ------------------------------------------------------------
  // ICONS
  // ------------------------------------------------------------

  IconData _icon(
    String skill,
  ) {
    final s =
        skill.toLowerCase();

    if (s.contains('flutter')) {
      return Icons
          .phone_android_rounded;
    }

    if (s.contains('dart')) {
      return Icons.code_rounded;
    }

    if (s.contains('python')) {
      return Icons.code_rounded;
    }

    if (s.contains('java')) {
      return Icons.coffee_rounded;
    }

    if (s.contains('javascript')) {
      return Icons
          .javascript_rounded;
    }

    if (s.contains('react')) {
      return Icons.web_rounded;
    }

    if (s.contains('firebase')) {
      return Icons
          .local_fire_department_rounded;
    }

    if (s.contains('sql') ||
        s.contains('database') ||
        s.contains('mongodb')) {
      return Icons
          .storage_rounded;
    }

    if (s.contains('cyber') ||
        s.contains('security') ||
        s == 'ai' ||
        s == 'ml') {
      return Icons
          .security_rounded;
    }

    if (s.contains('git') ||
        s.contains('github')) {
      return Icons
          .source_rounded;
    }

    return Icons.school_rounded;
  }

  // ------------------------------------------------------------
  // BOTTOM NAVIGATION
  // ------------------------------------------------------------

  Widget _bottomNav() =>
      BottomNavigationBar(
        currentIndex:
            selectedIndex,
        type:
            BottomNavigationBarType
                .fixed,
        selectedItemColor:
            primary,
        unselectedItemColor:
            Colors.grey,
        onTap:
            (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const JobsScreen(),
              ),
            );
          } else if (index == 0) {
            setState(
              () =>
                  selectedIndex =
                      0,
            );
          } else if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const CareerRoadmapScreen(),
              ),
            );
          } else if (index == 3) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ProfileScreen(),
              ),
    );
  }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(
              Icons
                  .home_outlined,
            ),
            activeIcon:
                Icon(
              Icons.home,
            ),
            label:
                'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons
                  .work_outline,
            ),
            activeIcon:
                Icon(
              Icons.work,
            ),
            label:
                'Jobs',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons
                  .map_outlined,
            ),
            activeIcon:
                Icon(
              Icons.map,
            ),
            label:
                'Roadmap',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons
                  .person_outline,
            ),
            activeIcon:
                Icon(
              Icons.person,
            ),
            label:
                'Profile',
          ),
        ],
      );
}