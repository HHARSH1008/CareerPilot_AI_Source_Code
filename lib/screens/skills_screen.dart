import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'career_goal_screen.dart';

class SkillsScreen extends StatefulWidget {
  const SkillsScreen({super.key});

  @override
  State<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends State<SkillsScreen> {
  final TextEditingController customSkillController =
      TextEditingController();

  bool isLoading = false;

  final List<String> skills = [
    'Flutter',
    'Java',
    'Python',
    'React',
    'Node.js',
    'JavaScript',
    'C++',
    'C',
    'Dart',
    'HTML',
    'CSS',
    'SQL',
    'MongoDB',
    'Firebase',
    'Git',
    'GitHub',
  ];

  final Set<String> selectedSkills = {};

  @override
  void dispose() {
    customSkillController.dispose();
    super.dispose();
  }

  // =========================================================
  // TOGGLE SKILL
  // =========================================================
  void toggleSkill(String skill) {
    setState(() {
      if (selectedSkills.contains(skill)) {
        selectedSkills.remove(skill);
      } else {
        selectedSkills.add(skill);
      }
    });
  }

  // =========================================================
  // ADD CUSTOM SKILL
  // =========================================================
  void showAddSkillDialog() {
    customSkillController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Add Custom Skill',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),

          content: TextField(
            controller: customSkillController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter skill name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                final skill =
                    customSkillController.text.trim();

                if (skill.isEmpty) {
                  return;
                }

                setState(() {
                  skills.add(skill);
                  selectedSkills.add(skill);
                });

                Navigator.pop(context);
              },

              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  // =========================================================
  // SAVE SKILLS + GO TO CAREER GOAL
  // =========================================================
  Future<void> continueNext() async {
    if (selectedSkills.isEmpty) {
      showMessage(
        'Please select at least one skill',
      );
      return;
    }

    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage(
        'Please login first',
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Save selected skills to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'skills': selectedSkills.toList(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      // Go to Career Goal screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const CareerGoalScreen(),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Firestore Error: ${e.code}',
      );

      if (mounted) {
        showMessage(
          'Unable to save skills. Please try again.',
        );
      }
    } catch (e) {
      debugPrint(
        'Skills Error: $e',
      );

      if (mounted) {
        showMessage(
          'Something went wrong. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // SHOW MESSAGE
  // =========================================================
  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // BUILD
  // =========================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF8FAFC),

      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF111827),
          ),

          onPressed: () =>
              Navigator.pop(context),
        ),

        title: const Text(
          'Your Skills',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        centerTitle: true,
      ),

      body: SafeArea(
        child: Column(
          children: [

            // =================================================
            // MAIN CONTENT
            // =================================================
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(
                  24,
                  15,
                  24,
                  20,
                ),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    // =================================================
                    // PROGRESS
                    // =================================================
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 6,

                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFF4F46E5,
                              ),

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        Expanded(
                          child: Container(
                            height: 6,

                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFF4F46E5,
                              ),

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 6),

                        Expanded(
                          child: Container(
                            height: 6,

                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xFFE2E8F0,
                              ),

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 30),

                    // =================================================
                    // ICON
                    // =================================================
                    Container(
                      height: 64,
                      width: 64,

                      decoration:
                          BoxDecoration(
                        gradient:
                            const LinearGradient(
                          colors: [
                            Color(0xFF2563EB),
                            Color(0xFF7C3AED),
                          ],
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          18,
                        ),
                      ),

                      child: const Icon(
                        Icons
                            .code_rounded,
                        color:
                            Colors.white,
                        size: 32,
                      ),
                    ),

                    const SizedBox(height: 22),

                    // =================================================
                    // TITLE
                    // =================================================
                    const Text(
                      'What are your skills?',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight:
                            FontWeight.w800,
                        color:
                            Color(0xFF111827),
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Select the technologies and skills you already know.',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color:
                            Color(0xFF64748B),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // =================================================
                    // SELECTED COUNT
                    // =================================================
                    Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.all(
                        16,
                      ),

                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFEEF2FF,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),

                        border: Border.all(
                          color:
                              const Color(
                            0xFFC7D2FE,
                          ),
                        ),
                      ),

                      child: Row(
                        children: [
                          const Icon(
                            Icons
                                .check_circle_rounded,
                            color:
                                Color(
                              0xFF4F46E5,
                            ),
                          ),

                          const SizedBox(
                            width: 10,
                          ),

                          Text(
                            '${selectedSkills.length} skills selected',

                            style:
                                const TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  Color(
                                0xFF3730A3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),

                    // =================================================
                    // SKILLS TITLE
                    // =================================================
                    const Text(
                      'Popular Skills',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight:
                            FontWeight.w700,
                        color:
                            Color(0xFF1E293B),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // =================================================
                    // SKILLS
                    // =================================================
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,

                      children:
                          skills.map((skill) {
                        final bool isSelected =
                            selectedSkills
                                .contains(
                          skill,
                        );

                        return GestureDetector(
                          onTap: () =>
                              toggleSkill(
                            skill,
                          ),

                          child:
                              AnimatedContainer(
                            duration:
                                const Duration(
                              milliseconds: 200,
                            ),

                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 15,
                              vertical: 11,
                            ),

                            decoration:
                                BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFFEEF2FF,
                                    )
                                  : Colors.white,

                              borderRadius:
                                  BorderRadius
                                      .circular(
                                12,
                              ),

                              border:
                                  Border.all(
                                color: isSelected
                                    ? const Color(
                                        0xFF4F46E5,
                                      )
                                    : const Color(
                                        0xFFE2E8F0,
                                      ),

                                width:
                                    isSelected
                                        ? 1.5
                                        : 1,
                              ),
                            ),

                            child: Row(
                              mainAxisSize:
                                  MainAxisSize
                                      .min,

                              children: [
                                Icon(
                                  isSelected
                                      ? Icons
                                          .check_circle_rounded
                                      : Icons
                                          .add_circle_outline_rounded,

                                  size: 18,

                                  color: isSelected
                                      ? const Color(
                                          0xFF4F46E5,
                                        )
                                      : const Color(
                                          0xFF64748B,
                                        ),
                                ),

                                const SizedBox(
                                  width: 7,
                                ),

                                Text(
                                  skill,

                                  style:
                                      TextStyle(
                                    fontSize: 14,

                                    fontWeight:
                                        FontWeight
                                            .w600,

                                    color: isSelected
                                        ? const Color(
                                            0xFF4338CA,
                                          )
                                        : const Color(
                                            0xFF475569,
                                          ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 25),

                    // =================================================
                    // ADD CUSTOM SKILL
                    // =================================================
                    GestureDetector(
                      onTap:
                          showAddSkillDialog,

                      child: Container(
                        width: double.infinity,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 15,
                        ),

                        decoration:
                            BoxDecoration(
                          color: Colors.white,

                          borderRadius:
                              BorderRadius
                                  .circular(
                            14,
                          ),

                          border: Border.all(
                            color:
                                const Color(
                              0xFFD8B4FE,
                            ),
                          ),
                        ),

                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment
                                  .center,

                          children: const [
                            Icon(
                              Icons
                                  .add_rounded,
                              color:
                                  Color(
                                0xFF7C3AED,
                              ),
                            ),

                            SizedBox(width: 8),

                            Text(
                              'Add another skill',

                              style:
                                  TextStyle(
                                color:
                                    Color(
                                  0xFF7C3AED,
                                ),

                                fontWeight:
                                    FontWeight
                                        .w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // =================================================
            // BOTTOM CONTINUE BUTTON
            // =================================================
            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                24,
                12,
                24,
                20,
              ),

              decoration:
                  const BoxDecoration(
                color: Colors.white,
              ),

              child: SizedBox(
                width: double.infinity,
                height: 56,

                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF7C3AED),
                      ],
                    ),

                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),

                  child: ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : continueNext,

                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          Colors.transparent,

                      disabledBackgroundColor:
                          Colors.transparent,

                      shadowColor:
                          Colors.transparent,

                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),

                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,

                            child:
                                CircularProgressIndicator(
                              color:
                                  Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,

                            children: [
                              Text(
                                'Continue',

                                style:
                                    TextStyle(
                                  color:
                                      Colors.white,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),

                              SizedBox(
                                width: 8,
                              ),

                              Icon(
                                Icons
                                    .arrow_forward_rounded,
                                color:
                                    Colors.white,
                                size: 21,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}