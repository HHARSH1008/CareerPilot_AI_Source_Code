import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'career_preferences_screen.dart';

class CareerGoalScreen extends StatefulWidget {
  const CareerGoalScreen({super.key});

  @override
  State<CareerGoalScreen> createState() => _CareerGoalScreenState();
}

class _CareerGoalScreenState extends State<CareerGoalScreen> {
  String? selectedRole;
  String? selectedExperience;

  bool isLoading = false;

  final List<String> roles = [
    'Flutter Developer',
    'AI Developer',
    'Python Developer',
    'Data Scientist',
    'Machine Learning Engineer',
    'Web Developer',
    'React Developer',
    'Node.js Developer',
    'UI/UX Designer',
    'Other',
  ];

  final List<String> experienceLevels = [
    'Fresher',
    '0 - 1 Year',
    '1 - 3 Years',
    '3+ Years',
  ];

  // =========================
  // SHOW MESSAGE
  // =========================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // =========================
  // SAVE CAREER GOAL
  // =========================

  Future<void> continueNext() async {
    // Role validation
    if (selectedRole == null) {
      showMessage('Please select your target job role');
      return;
    }

    // Experience validation
    if (selectedExperience == null) {
      showMessage('Please select your experience level');
      return;
    }

    // Get logged-in user
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage('User not logged in. Please login again.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // =========================
      // SAVE TO FIRESTORE
      // =========================

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'targetRole': selectedRole,
          'experienceLevel': selectedExperience,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      // =========================
      // GO TO CAREER PREFERENCES
      // =========================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) =>
              const CareerPreferencesScreen(),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint('Firebase Error: ${e.code}');
      debugPrint('Firebase Message: ${e.message}');

      if (!mounted) return;

      if (e.code == 'permission-denied') {
        showMessage(
          'Permission denied. Please check Firestore rules.',
        );
      } else if (e.code == 'unavailable') {
        showMessage(
          'Internet connection problem. Please try again.',
        );
      } else {
        showMessage(
          'Failed to save career goal. Please try again.',
        );
      }
    } catch (e) {
      debugPrint('Career Goal Error: $e');

      if (!mounted) return;

      showMessage(
        'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // =========================
      // APP BAR
      // =========================

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF111827),
          ),
          onPressed: isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },
        ),

        title: const Text(
          'Career Goal',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),

        centerTitle: true,
      ),

      // =========================
      // BODY
      // =========================

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            24,
            15,
            24,
            30,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // =========================
              // PROGRESS
              // =========================

              Row(
                children: [

                  Container(
                    height: 6,
                    width: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Container(
                    height: 6,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Container(
                    height: 6,
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2E8F0),
                      borderRadius:
                          BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 30),

              // =========================
              // ICON
              // =========================

              Container(
                height: 64,
                width: 64,

                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF2563EB),
                      Color(0xFF7C3AED),
                    ],
                  ),

                  borderRadius:
                      BorderRadius.circular(18),
                ),

                child: const Icon(
                  Icons.flag_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(height: 22),

              // =========================
              // TITLE
              // =========================

              const Text(
                'What is your career goal?',

                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Tell us what role you want to pursue so we can create a personalized career path for you.',

                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 32),

              // =========================
              // TARGET ROLE
              // =========================

              const Text(
                'Target Job Role',

                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),

              const SizedBox(height: 10),

              Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 16,
                ),

                decoration: BoxDecoration(
                  color: Colors.white,

                  borderRadius:
                      BorderRadius.circular(16),

                  border: Border.all(
                    color: const Color(0xFFE2E8F0),
                  ),
                ),

                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRole,

                    isExpanded: true,

                    hint: const Text(
                      'Select your target role',

                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                      ),
                    ),

                    icon: const Icon(
                      Icons
                          .keyboard_arrow_down_rounded,
                      color: Color(0xFF64748B),
                    ),

                    items: roles.map((role) {
                      return DropdownMenuItem<String>(
                        value: role,

                        child: Text(
                          role,

                          style: const TextStyle(
                            color: Color(0xFF1E293B),
                            fontSize: 15,
                          ),
                        ),
                      );
                    }).toList(),

                    onChanged: isLoading
                        ? null
                        : (value) {
                            setState(() {
                              selectedRole = value;
                            });
                          },
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // =========================
              // EXPERIENCE
              // =========================

              const Text(
                'Experience Level',

                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),

              const SizedBox(height: 12),

              GridView.builder(
                shrinkWrap: true,

                physics:
                    const NeverScrollableScrollPhysics(),

                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.7,
                ),

                itemCount: experienceLevels.length,

                itemBuilder: (context, index) {
                  final experience =
                      experienceLevels[index];

                  final isSelected =
                      selectedExperience ==
                          experience;

                  return GestureDetector(
                    onTap: isLoading
                        ? null
                        : () {
                            setState(() {
                              selectedExperience =
                                  experience;
                            });
                          },

                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFFEEF2FF)
                            : Colors.white,

                        borderRadius:
                            BorderRadius.circular(14),

                        border: Border.all(
                          color: isSelected
                              ? const Color(
                                  0xFF4F46E5,
                                )
                              : const Color(
                                  0xFFE2E8F0,
                                ),

                          width:
                              isSelected ? 1.5 : 1,
                        ),
                      ),

                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,

                        children: [

                          Icon(
                            isSelected
                                ? Icons
                                    .check_circle_rounded
                                : Icons
                                    .radio_button_unchecked,

                            size: 19,

                            color: isSelected
                                ? const Color(
                                    0xFF4F46E5,
                                  )
                                : const Color(
                                    0xFF94A3B8,
                                  ),
                          ),

                          const SizedBox(width: 7),

                          Flexible(
                            child: Text(
                              experience,

                              style: TextStyle(
                                fontSize: 13,

                                fontWeight:
                                    FontWeight.w600,

                                color: isSelected
                                    ? const Color(
                                        0xFF4F46E5,
                                      )
                                    : const Color(
                                        0xFF475569,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 40),

              // =========================
              // CONTINUE BUTTON
              // =========================

              SizedBox(
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
                        BorderRadius.circular(16),
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
                            BorderRadius.circular(16),
                      ),
                    ),

                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,

                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2.5,

                              valueColor:
                                  AlwaysStoppedAnimation<
                                      Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment:
                                MainAxisAlignment
                                    .center,

                            children: [

                              Text(
                                'Continue',

                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),

                              SizedBox(width: 8),

                              Icon(
                                Icons
                                    .arrow_forward_rounded,
                                color: Colors.white,
                                size: 21,
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}