import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ai_career_mentor/screens/ai_career_analysis_screen.dart';

class CareerPreferencesScreen extends StatefulWidget {
  const CareerPreferencesScreen({super.key});

  @override
  State<CareerPreferencesScreen> createState() =>
      _CareerPreferencesScreenState();
}

class _CareerPreferencesScreenState
    extends State<CareerPreferencesScreen> {
  String? selectedLocation;
  String? selectedWorkMode;
  String? selectedSalary;
  String? selectedJobType;
  String? selectedCompanyType;
  String? selectedRelocation;

  bool isLoading = false;

  final List<String> locations = [
    'Ahmedabad',
    'Mumbai',
    'Pune',
    'Bangalore',
    'Hyderabad',
    'Delhi',
    'Gurgaon',
    'Noida',
    'Chennai',
    'Remote',
    'Any Location',
  ];

  final List<String> workModes = [
    'Remote',
    'Hybrid',
    'On-site',
  ];

  final List<String> salaries = [
    '₹2 - ₹4 LPA',
    '₹4 - ₹6 LPA',
    '₹6 - ₹10 LPA',
    '₹10 - ₹15 LPA',
    '₹15+ LPA',
  ];

  final List<String> jobTypes = [
    'Full-time',
    'Internship',
    'Part-time',
    'Contract',
  ];

  final List<String> companyTypes = [
    'Startup',
    'MNC',
    'Product Company',
    'Service Company',
    'Any Company',
  ];

  final List<String> relocationOptions = [
    'Yes',
    'No',
    'Maybe',
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
  // SAVE DATA + NEXT SCREEN
  // =========================

  Future<void> continueNext() async {
    // Validation

    if (selectedLocation == null) {
      showMessage('Please select your preferred location');
      return;
    }

    if (selectedWorkMode == null) {
      showMessage('Please select your preferred work mode');
      return;
    }

    if (selectedSalary == null) {
      showMessage('Please select your expected salary');
      return;
    }

    if (selectedJobType == null) {
      showMessage('Please select your preferred job type');
      return;
    }

    if (selectedCompanyType == null) {
      showMessage('Please select your preferred company type');
      return;
    }

    if (selectedRelocation == null) {
      showMessage('Please select your relocation preference');
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
      // FIRESTORE SAVE
      // =========================

      await FirebaseFirestore.instance
    .collection('users')
    .doc(user.uid)
    .set(
  {
    'preferredLocation': selectedLocation,
    'workMode': selectedWorkMode,
    'expectedSalary': selectedSalary,
    'jobType': selectedJobType,
    'companyType': selectedCompanyType,
    'relocation': selectedRelocation,

    // IMPORTANT
    'profileCompleted': true,

    'updatedAt': FieldValue.serverTimestamp(),
  },
  SetOptions(merge: true),
);

      if (!mounted) return;

      showMessage(
        'Career preferences saved successfully!',
      );

      // Small delay so user can see success message
      await Future.delayed(
        const Duration(milliseconds: 700),
      );

      if (!mounted) return;

      // =========================
      // GO TO AI ANALYSIS SCREEN
      // =========================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AICareerAnalysisScreen(),
        ),
      );
    } on FirebaseException catch (e) {
      debugPrint(
        'Firebase Error Code: ${e.code}',
      );

      debugPrint(
        'Firebase Error Message: ${e.message}',
      );

      if (!mounted) return;

      if (e.code == 'permission-denied') {
        showMessage(
          'Permission denied. Check Firestore rules.',
        );
      } else if (e.code == 'unavailable') {
        showMessage(
          'Internet connection problem.',
        );
      } else {
        showMessage(
          'Failed to save preferences. Try again.',
        );
      }
    } catch (e) {
      debugPrint(
        'Career Preferences Error: $e',
      );

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

  // =========================
  // DROPDOWN WIDGET
  // =========================

  Widget buildDropdown({
    required String title,
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E293B),
          ),
        ),

        const SizedBox(height: 9),

        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: const Color(0xFFE2E8F0),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,

              hint: Text(
                hint,
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 14,
                ),
              ),

              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: Color(0xFF64748B),
              ),

              items: items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                );
              }).toList(),

              onChanged: isLoading
                  ? null
                  : onChanged,
            ),
          ),
        ),
      ],
    );
  }

  // =========================
  // BUILD UI
  // =========================

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
          onPressed: isLoading
              ? null
              : () {
                  Navigator.pop(context);
                },

          icon: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF111827),
          ),
        ),

        title: const Text(
          'Career Preferences',
          style: TextStyle(
            color: Color(0xFF111827),
            fontSize: 19,
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
            12,
            24,
            35,
          ),

          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              // =========================
              // PROGRESS
              // =========================

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  Expanded(
                    flex: 1,
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
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
                  gradient:
                      const LinearGradient(
                    colors: [
                      Color(0xFF2563EB),
                      Color(0xFF7C3AED),
                    ],
                  ),

                  borderRadius:
                      BorderRadius.circular(18),
                ),

                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),

              const SizedBox(height: 22),

              // =========================
              // TITLE
              // =========================

              const Text(
                'What are your preferences?',

                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 8),

              const Text(
                'Tell us what kind of job you are looking for so we can find opportunities that match you.',

                style: TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF64748B),
                ),
              ),

              const SizedBox(height: 30),

              // =========================
              // LOCATION
              // =========================

              buildDropdown(
                title: 'Preferred Location',
                hint:
                    'Select your preferred location',
                value: selectedLocation,
                items: locations,

                onChanged: (value) {
                  setState(() {
                    selectedLocation = value;
                  });
                },
              ),

              const SizedBox(height: 22),

              // =========================
              // WORK MODE
              // =========================

              buildDropdown(
                title: 'Work Mode',
                hint: 'Select work mode',
                value: selectedWorkMode,
                items: workModes,

                onChanged: (value) {
                  setState(() {
                    selectedWorkMode = value;
                  });
                },
              ),

              const SizedBox(height: 22),

              // =========================
              // SALARY
              // =========================

              buildDropdown(
                title: 'Expected Salary',
                hint: 'Select expected salary',
                value: selectedSalary,
                items: salaries,

                onChanged: (value) {
                  setState(() {
                    selectedSalary = value;
                  });
                },
              ),

              const SizedBox(height: 22),

              // =========================
              // JOB TYPE
              // =========================

              buildDropdown(
                title: 'Job Type',
                hint: 'Select job type',
                value: selectedJobType,
                items: jobTypes,

                onChanged: (value) {
                  setState(() {
                    selectedJobType = value;
                  });
                },
              ),

              const SizedBox(height: 22),

              // =========================
              // COMPANY TYPE
              // =========================

              buildDropdown(
                title: 'Preferred Company',
                hint: 'Select company type',
                value: selectedCompanyType,
                items: companyTypes,

                onChanged: (value) {
                  setState(() {
                    selectedCompanyType = value;
                  });
                },
              ),

              const SizedBox(height: 22),

              // =========================
              // RELOCATION
              // =========================

              buildDropdown(
                title: 'Open to Relocation?',
                hint: 'Select your preference',
                value: selectedRelocation,
                items: relocationOptions,

                onChanged: (value) {
                  setState(() {
                    selectedRelocation = value;
                  });
                },
              ),

              const SizedBox(height: 38),

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

              const SizedBox(height: 15),

              // =========================
              // BOTTOM TEXT
              // =========================

              const Center(
                child: Text(
                  'You can update these preferences later.',

                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94A3B8),
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