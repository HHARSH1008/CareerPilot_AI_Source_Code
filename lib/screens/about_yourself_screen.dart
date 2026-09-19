import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'skills_screen.dart';

class AboutYourselfScreen extends StatefulWidget {
  const AboutYourselfScreen({super.key});

  @override
  State<AboutYourselfScreen> createState() =>
      _AboutYourselfScreenState();
}

class _AboutYourselfScreenState
    extends State<AboutYourselfScreen> {
  String? selectedStatus;
  String? selectedEducation;
  String? selectedDegree;
  String? selectedGraduationYear;

  bool isLoading = false;

  final List<String> statusOptions = [
    'Student',
    'Working Professional',
  ];

  final List<String> educationOptions = [
    'High School',
    'Diploma',
    'Undergraduate',
    'Postgraduate',
    'PhD',
    'Other',
  ];

  final List<String> degreeOptions = [
    'BCA',
    'BSc',
    'B.Tech',
    'BE',
    'BBA',
    'BA',
    'B.Com',
    'MCA',
    'M.Tech',
    'MBA',
    'MA',
    'MSc',
    'Other',
  ];

  final List<String> graduationYears = [
    '2026',
    '2027',
    '2028',
    '2029',
    '2030',
    '2031',
    '2032',
    '2033',
    '2034',
    '2035',
  ];

  // Save profile data to Firestore
  Future<void> saveProfile() async {
    // Check all fields
    if (selectedStatus == null ||
        selectedEducation == null ||
        selectedDegree == null ||
        selectedGraduationYear == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all fields'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Get currently logged-in user
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Save data in Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'uid': user.uid,
        'name': user.displayName ?? '',
        'email': user.email ?? '',
        'status': selectedStatus,
        'education': selectedEducation,
        'degree': selectedDegree,
        'graduationYear': selectedGraduationYear,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Go to Skills screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const SkillsScreen(),
        ),
      );
    } on FirebaseException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.code == 'permission-denied'
                  ? 'Permission denied. Please check Firestore rules.'
                  : 'Failed to save profile. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Something went wrong. Please try again.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFEAF4FF),
              Color(0xFFF3E8FF),
            ],
          ),
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // Progress
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 35),

                // Icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.85),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.person_outline,
                      size: 42,
                      color: Color(0xFF6366F1),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                const Center(
                  child: Text(
                    'Tell Us About Yourself',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1B4B),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                const Center(
                  child: Text(
                    'Help us personalize your career journey',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),

                const SizedBox(height: 35),

                // Status
                const Text(
                  'I am a',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1B4B),
                  ),
                ),

                const SizedBox(height: 8),

                _buildDropdown(
                  value: selectedStatus,
                  hint: 'Select your current status',
                  icon: Icons.person_outline,
                  items: statusOptions,
                  onChanged: (value) {
                    setState(() {
                      selectedStatus = value;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // Education
                const Text(
                  'Education',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1B4B),
                  ),
                ),

                const SizedBox(height: 8),

                _buildDropdown(
                  value: selectedEducation,
                  hint: 'Select your education',
                  icon: Icons.school_outlined,
                  items: educationOptions,
                  onChanged: (value) {
                    setState(() {
                      selectedEducation = value;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // Degree
                const Text(
                  'Degree',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1B4B),
                  ),
                ),

                const SizedBox(height: 8),

                _buildDropdown(
                  value: selectedDegree,
                  hint: 'Select your degree',
                  icon: Icons.workspace_premium_outlined,
                  items: degreeOptions,
                  onChanged: (value) {
                    setState(() {
                      selectedDegree = value;
                    });
                  },
                ),

                const SizedBox(height: 20),

                // Graduation Year
                const Text(
                  'Graduation Year',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E1B4B),
                  ),
                ),

                const SizedBox(height: 8),

                _buildDropdown(
                  value: selectedGraduationYear,
                  hint: 'Select graduation year',
                  icon: Icons.calendar_month_outlined,
                  items: graduationYears,
                  onChanged: (value) {
                    setState(() {
                      selectedGraduationYear = value;
                    });
                  },
                ),

                const SizedBox(height: 35),

                // Continue Button
                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: ElevatedButton(
                    onPressed: isLoading ? null : saveProfile,

                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          const Color(0xFF9CA3AF),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(16),
                      ),
                    ),

                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Continue →',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required String hint,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white,
          width: 1.5,
        ),
      ),

      child: DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,

        icon: const Icon(
          Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF6366F1),
        ),

        decoration: InputDecoration(
          prefixIcon: Icon(
            icon,
            color: const Color(0xFF6366F1),
          ),
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),

        items: items.map((item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item),
          );
        }).toList(),

        onChanged: onChanged,
      ),
    );
  }
}