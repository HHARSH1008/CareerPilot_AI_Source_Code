import 'package:flutter/material.dart';
import 'welcome_screen.dart';
class DreamJobScreen extends StatelessWidget {
  const DreamJobScreen({super.key});

  
  
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
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            child: Column(
              children: [
                // Progress
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _dot(false),
                    _dot(false),
                    _dot(true),
                  ],
                ),

                const Spacer(),

                // Illustration
                Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.75),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    size: 120,
                    color: Color(0xFF4F46E5),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Find Your Dream Job',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Let AI match you with relevant job opportunities based on your role, skills, and preferred location.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 25),

                _feature(
                  Icons.auto_awesome,
                  'AI-Powered Job Matching',
                ),
                _feature(
                  Icons.work_outline,
                  'Role-Based Opportunities',
                ),
                _feature(
                  Icons.location_on_outlined,
                  'Location-Based Jobs',
                ),
                _feature(
                  Icons.language,
                  'Multiple Job Platforms',
                ),

                const Spacer(),

                // Get Started Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                     Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                      builder: (context) => const WelcomeScreen(),
                       ),
                     );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Get Started →',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
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

  static Widget _dot(bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      width: active ? 24 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: active
            ? const Color(0xFF4F46E5)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  static Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF4F46E5),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }
}