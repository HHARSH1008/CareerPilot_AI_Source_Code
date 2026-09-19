import 'package:flutter/material.dart';
import 'dream_job_screen.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

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
                    _dot(true),
                    _dot(false),
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
                    Icons.route,
                    size: 120,
                    color: Color(0xFF7C3AED),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Build Your Career Roadmap',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1B4B),
                  ),
                ),

                const SizedBox(height: 16),

                const Text(
                  'Get a personalized 6-month roadmap designed to help you become job-ready.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 25),

                _feature(
                  Icons.code,
                  'Skills Development',
                ),
                _feature(
                  Icons.school_outlined,
                  'Courses & Learning',
                ),
                _feature(
                  Icons.laptop_mac,
                  'Real-World Projects',
                ),
                _feature(
                  Icons.mic,
                  'Interview Preparation',
                ),
                _feature(
                  Icons.bar_chart,
                  'Progress Tracking',
                ),

                const Spacer(),

                // Next Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DreamJobScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7C3AED),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Next →',
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
            ? const Color(0xFF7C3AED)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  static Widget _feature(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 20,
            color: const Color(0xFF7C3AED),
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