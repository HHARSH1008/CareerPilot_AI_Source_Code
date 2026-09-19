import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'discover_career_screen.dart';
import 'about_yourself_screen.dart';
import 'dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();

    _timer = Timer(
      const Duration(seconds: 3),
      () {
        if (!mounted) return;
        _checkUserSession();
      },
    );
  }

  // =========================================================
  // CHECK USER SESSION
  // =========================================================

  Future<void> _checkUserSession() async {
    final User? user = FirebaseAuth.instance.currentUser;

    // -------------------------------------------------------
    // NO USER LOGGED IN
    // -------------------------------------------------------

    if (user == null) {
      _goToDiscoverCareer();
      return;
    }

    // -------------------------------------------------------
    // USER IS ALREADY LOGGED IN
    // -------------------------------------------------------

    try {
      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final data = doc.data();

      final bool profileCompleted =
          data != null && data['profileCompleted'] == true;

      if (!mounted) return;

      // -----------------------------------------------------
      // PROFILE COMPLETED → DASHBOARD
      // -----------------------------------------------------

      if (profileCompleted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const DashboardScreen(),
          ),
        );
      }

      // -----------------------------------------------------
      // PROFILE NOT COMPLETED → ABOUT YOURSELF
      // -----------------------------------------------------

      else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const AboutYourselfScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint('Session check error: $e');

      if (!mounted) return;

      // If Firestore check fails, don't trap the user.
      // Send them to the normal starting screen.
      _goToDiscoverCareer();
    }
  }

  // =========================================================
  // GO TO DISCOVER CAREER
  // =========================================================

  void _goToDiscoverCareer() {
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const DiscoverCareerScreen(),
      ),
    );
  }

  // =========================================================
  // DISPOSE TIMER
  // =========================================================

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // Background Gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromARGB(255, 80, 159, 250),
              Color.fromARGB(255, 120, 78, 165),
            ],
          ),
        ),

        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              // Logo
              Image.asset(
                'assets/images/ai-career-mentor-logo.png',
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return const Icon(
                    Icons.psychology,
                    size: 120,
                    color: Colors.blue,
                  );
                },
              ),

              const SizedBox(height: 25),

              // App Name
              const Text(
                'AI Career Mentor',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color.fromARGB(
                    255,
                    242,
                    242,
                    245,
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // Tagline
              const Text(
                'Your AI Career Companion',
                style: TextStyle(
                  fontSize: 16,
                  color: Color.fromARGB(
                    255,
                    225,
                    227,
                    229,
                  ),
                ),
              ),

              const SizedBox(height: 30),

              // Loading
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF6366F1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}