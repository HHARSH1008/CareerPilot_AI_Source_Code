import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SkillLearningScreen extends StatefulWidget {
  final String skill;

  const SkillLearningScreen({
    super.key,
    required this.skill,
  });

  @override
  State<SkillLearningScreen> createState() =>
      _SkillLearningScreenState();
}

class _SkillLearningScreenState extends State<SkillLearningScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Map<String, bool> completedSteps = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProgress();
  }

  // ------------------------------------------------------------
  // VIDEO DATA
  // ------------------------------------------------------------

  Map<String, String> get videoData {
    switch (widget.skill.toLowerCase()) {
      case 'flutter':
      case 'dart':
        return {
          'videoUrl':
              'https://www.youtube.com/watch?v=2kjp9yAKpT4',
        };

      case 'python':
        return {
          'videoUrl':
              'https://www.youtube.com/watch?v=rfscVS0vtbw',
        };

      case 'machine learning':
      case 'ml':
      case 'ai/ml':
        return {
          'videoUrl':
              'https://www.youtube.com/watch?v=i_LwzRVP7bg',
        };

      case 'javascript':
        return {
          'videoUrl':
              'https://www.youtube.com/watch?v=PkZNo7MFNFg',
        };

      case 'react':
        return {
          'videoUrl':
              'https://www.youtube.com/watch?v=DLX62G4lc44',
        };

      case 'sql':
        return {
          'videoUrl':
              'https://www.youtube.com/watch?v=HXV3zeQKqGY',
        };

      case 'firebase':
        return {
          'videoUrl':
              'https://www.youtube.com/results?search_query=Firebase+Flutter+tutorial',
        };

      default:
        return {
          'videoUrl':
              'https://www.youtube.com/results?search_query=${Uri.encodeComponent(widget.skill + ' tutorial')}',
        };
    }
  }

  // ------------------------------------------------------------
  // LEARNING STEPS
  // ------------------------------------------------------------

  List<Map<String, String>> get learningSteps {
    switch (widget.skill.toLowerCase()) {
      case 'flutter':
        return [
          {
            'title': 'Dart Fundamentals',
            'description':
                'Learn variables, data types, functions, collections and OOP in Dart.',
          },
          {
            'title': 'Flutter Widgets',
            'description':
                'Understand StatelessWidget, StatefulWidget, Container, Row, Column and common widgets.',
          },
          {
            'title': 'Layouts & UI',
            'description':
                'Learn responsive layouts, Material Design, themes and reusable UI components.',
          },
          {
            'title': 'Navigation & Forms',
            'description':
                'Learn routes, navigation, forms, validation and passing data between screens.',
          },
          {
            'title': 'Firebase & APIs',
            'description':
                'Learn Firebase Authentication, Firestore and REST API integration.',
          },
          {
            'title': 'Build a Real Project',
            'description':
                'Combine your skills and build a complete production-style Flutter application.',
          },
        ];

      case 'python':
        return [
          {
            'title': 'Python Basics',
            'description':
                'Learn variables, data types, operators and input/output.',
          },
          {
            'title': 'Conditions & Loops',
            'description':
                'Learn if-else, for loops, while loops and control flow.',
          },
          {
            'title': 'Functions',
            'description':
                'Learn functions, parameters, return values and reusable code.',
          },
          {
            'title': 'Lists & Dictionaries',
            'description':
                'Learn Python collections and how to work with structured data.',
          },
          {
            'title': 'OOP in Python',
            'description':
                'Learn classes, objects, inheritance and encapsulation.',
          },
          {
            'title': 'Python Project',
            'description':
                'Build a practical Python project using the concepts you learned.',
          },
        ];

      case 'machine learning':
      case 'ml':
      case 'ai/ml':
        return [
          {
            'title': 'ML Fundamentals',
            'description':
                'Understand what Machine Learning is and how ML systems work.',
          },
          {
            'title': 'Data Preparation',
            'description':
                'Learn datasets, features, labels and preparing data for models.',
          },
          {
            'title': 'Classification',
            'description':
                'Understand classification problems and common algorithms.',
          },
          {
            'title': 'Regression',
            'description':
                'Learn regression and how models predict numerical values.',
          },
          {
            'title': 'Neural Networks',
            'description':
                'Understand the basics of neural networks and TensorFlow.',
          },
          {
            'title': 'ML Project',
            'description':
                'Build an end-to-end Machine Learning project.',
          },
        ];

      case 'javascript':
        return [
          {
            'title': 'JavaScript Basics',
            'description':
                'Learn variables, data types and basic JavaScript syntax.',
          },
          {
            'title': 'Functions',
            'description':
                'Learn functions, parameters, return values and scope.',
          },
          {
            'title': 'Arrays & Objects',
            'description':
                'Learn arrays, objects and common data manipulation techniques.',
          },
          {
            'title': 'DOM Manipulation',
            'description':
                'Learn how JavaScript interacts with HTML and CSS.',
          },
          {
            'title': 'Modern JavaScript',
            'description':
                'Learn let, const, arrow functions, destructuring, spread and modules.',
          },
          {
            'title': 'JavaScript Project',
            'description':
                'Build a practical JavaScript application.',
          },
        ];

      case 'react':
        return [
          {
            'title': 'React Basics',
            'description':
                'Understand React, components and JSX.',
          },
          {
            'title': 'Props & State',
            'description':
                'Learn how components share data and manage state.',
          },
          {
            'title': 'Events',
            'description':
                'Learn event handling and user interaction.',
          },
          {
            'title': 'Hooks',
            'description':
                'Learn useState, useEffect and reusable React logic.',
          },
          {
            'title': 'API Integration',
            'description':
                'Learn how to fetch and display data from APIs.',
          },
          {
            'title': 'React Project',
            'description':
                'Build a complete React application.',
          },
        ];

      case 'sql':
        return [
          {
            'title': 'SQL Basics',
            'description':
                'Learn databases, tables and basic SELECT queries.',
          },
          {
            'title': 'Filtering Data',
            'description':
                'Learn WHERE, ORDER BY, LIMIT and conditional queries.',
          },
          {
            'title': 'Aggregate Functions',
            'description':
                'Learn COUNT, SUM, AVG, MIN, MAX and GROUP BY.',
          },
          {
            'title': 'Joins',
            'description':
                'Learn INNER JOIN, LEFT JOIN and other important joins.',
          },
          {
            'title': 'Subqueries',
            'description':
                'Learn nested queries and advanced SQL operations.',
          },
          {
            'title': 'SQL Project',
            'description':
                'Practice SQL using a realistic database project.',
          },
        ];

      case 'firebase':
        return [
          {
            'title': 'Firebase Basics',
            'description':
                'Understand Firebase and how it integrates with Flutter.',
          },
          {
            'title': 'Firebase Authentication',
            'description':
                'Learn Email/Password and Google authentication.',
          },
          {
            'title': 'Cloud Firestore',
            'description':
                'Learn collections, documents and CRUD operations.',
          },
          {
            'title': 'Firebase Storage',
            'description':
                'Learn how to upload and manage files.',
          },
          {
            'title': 'Security Rules',
            'description':
                'Learn how to protect Firebase data.',
          },
          {
            'title': 'Firebase Project',
            'description':
                'Build a complete Firebase-powered application.',
          },
        ];

      default:
        return [
          {
            'title': 'Introduction',
            'description':
                'Understand the fundamentals of ${widget.skill}.',
          },
          {
            'title': 'Core Concepts',
            'description':
                'Learn the most important concepts.',
          },
          {
            'title': 'Practice',
            'description':
                'Practice the concepts with examples.',
          },
          {
            'title': 'Intermediate',
            'description':
                'Move towards intermediate-level concepts.',
          },
          {
            'title': 'Advanced',
            'description':
                'Learn advanced concepts and techniques.',
          },
          {
            'title': 'Build a Project',
            'description':
                'Apply everything you learned in a real project.',
          },
        ];
    }
  }

  // ------------------------------------------------------------
  // LOAD FIRESTORE PROGRESS
  // ------------------------------------------------------------

  Future<void> _loadProgress() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      final snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final data = snapshot.data();

      if (data != null) {
        final allProgress =
            data['skillProgress'] as Map<String, dynamic>?;

        final skillProgress =
            allProgress?[widget.skill] as Map<String, dynamic>?;

        if (skillProgress != null) {
          final Map<String, bool> loaded = {};

          skillProgress.forEach((key, value) {
            loaded[key] = value == true;
          });

          completedSteps = loaded;
        }
      }
    } catch (e) {
      debugPrint('Progress load error: $e');
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ------------------------------------------------------------
  // SAVE PROGRESS
  // ------------------------------------------------------------

  Future<void> _toggleStep(String title) async {
    final user = _auth.currentUser;

    if (user == null) return;

    setState(() {
      completedSteps[title] =
          !(completedSteps[title] ?? false);
    });

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'skillProgress': {
            widget.skill: completedSteps,
          },
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint('Progress save error: $e');
    }
  }

  // ------------------------------------------------------------
  // OPEN DIRECT YOUTUBE VIDEO
  // ------------------------------------------------------------

  Future<void> _watchVideo() async {
    final url = videoData['videoUrl'];

    if (url == null || url.isEmpty) return;

    final uri = Uri.parse(url);

    try {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open YouTube video',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open YouTube video',
            ),
          ),
        );
      }
    }
  }

  // ------------------------------------------------------------
  // PROGRESS
  // ------------------------------------------------------------

  double get progress {
    if (learningSteps.isEmpty) return 0;

    final completed = learningSteps
        .where(
          (step) =>
              completedSteps[step['title']!] == true,
        )
        .length;

    return completed / learningSteps.length;
  }

  int get completedCount {
    return learningSteps
        .where(
          (step) =>
              completedSteps[step['title']!] == true,
        )
        .length;
  }

  // ------------------------------------------------------------
  // UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final steps = learningSteps;

    return Scaffold(
      backgroundColor: const Color(0xffF6F7FB),
      body: SafeArea(
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff667EEA),
                ),
              )
            : CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: _buildHeader(),
                  ),

                  SliverToBoxAdapter(
                    child: _buildProgressCard(),
                  ),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        20,
                        24,
                        20,
                        12,
                      ),
                      child: Text(
                        'Learning Path',
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff20233A),
                        ),
                      ),
                    ),
                  ),

                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      0,
                      20,
                      30,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final step = steps[index];

                          return _buildLearningCard(
                            index: index,
                            title: step['title']!,
                            description:
                                step['description']!,
                          );
                        },
                        childCount: steps.length,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ------------------------------------------------------------
  // HEADER
  // ------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        15,
        20,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xff667EEA),
            Color(0xff764BA2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Learning',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.school_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.skill,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Build your skills step by step',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // PROGRESS CARD
  // ------------------------------------------------------------

  Widget _buildProgressCard() {
    final percent =
        (progress * 100).round();

    return Container(
      margin: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        0,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.insights_rounded,
                color: Color(0xff667EEA),
              ),
              const SizedBox(width: 10),

              const Expanded(
                child: Text(
                  'Your Progress',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              Text(
                '$percent%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xff667EEA),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
                  const Color(0xffE9EAF2),
              valueColor:
                  const AlwaysStoppedAnimation<Color>(
                Color(0xff667EEA),
              ),
            ),
          ),

          const SizedBox(height: 10),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '$completedCount / ${learningSteps.length} steps completed',
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xff777B91),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // LEARNING CARD
  // ------------------------------------------------------------

  Widget _buildLearningCard({
    required int index,
    required String title,
    required String description,
  }) {
    final isCompleted =
        completedSteps[title] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isCompleted
              ? const Color(0xff667EEA)
              : const Color(0xffE7E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.035),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xff667EEA),
                        Color(0xff764BA2),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(13),
                  ),
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Color(0xff25283D),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: Color(0xff777B91),
                        ),
                      ),
                    ],
                  ),
                ),

                if (isCompleted)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xff4CAF50),
                    size: 25,
                  ),
              ],
            ),

            const SizedBox(height: 17),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _watchVideo,
                    icon: const Icon(
                      Icons.play_circle_fill_rounded,
                      size: 21,
                    ),
                    label: const Text(
                      'Watch Video',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor:
                          const Color(0xff667EEA),
                      side: const BorderSide(
                        color: Color(0xff667EEA),
                      ),
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _toggleStep(title);
                    },
                    icon: Icon(
                      isCompleted
                          ? Icons.undo_rounded
                          : Icons.check_rounded,
                      size: 19,
                    ),
                    label: Text(
                      isCompleted
                          ? 'Completed'
                          : 'Complete',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isCompleted
                              ? const Color(0xffE9EAF2)
                              : const Color(0xff667EEA),
                      foregroundColor:
                          isCompleted
                              ? const Color(0xff55596E)
                              : Colors.white,
                      elevation: 0,
                      padding:
                          const EdgeInsets.symmetric(
                        vertical: 12,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}