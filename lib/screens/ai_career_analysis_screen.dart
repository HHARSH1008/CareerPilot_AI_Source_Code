import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'dashboard_screen.dart';

class AICareerAnalysisScreen extends StatefulWidget {

  const AICareerAnalysisScreen({super.key});

  @override

  State<AICareerAnalysisScreen> createState() =>

      _AICareerAnalysisScreenState();

}

class _AICareerAnalysisScreenState

    extends State<AICareerAnalysisScreen> {

  // =========================================================

  // BACKEND API

  // =========================================================
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

  // =========================================================

  // LOAD USER DATA

  // =========================================================

  Future<void> loadUserAndGenerateAnalysis() async {

    try {

      final User? user =

          FirebaseAuth.instance.currentUser;

      if (user == null) {

        showError('User is not logged in.');

        return;

      }

      final DocumentSnapshot snapshot =

          await FirebaseFirestore.instance

              .collection('users')

              .doc(user.uid)

              .get();

      if (!snapshot.exists) {

        showError('User profile not found.');

        return;

      }

      userData =

          snapshot.data() as Map<String, dynamic>;

      await generateAIAnalysis();

    } catch (e) {

      debugPrint('Load User Error: $e');

      if (mounted) {

        showError(

          'Unable to load your profile.',

        );

      }

    }

  }

  // =========================================================

  // GENERATE AI ANALYSIS

  // =========================================================

  Future<void> generateAIAnalysis() async {

    if (!mounted) return;

    setState(() {

      isLoading = true;

    });

    try {

      final response = await http

          .post(

            Uri.parse(apiUrl),

            headers: {

              'Content-Type': 'application/json',
              'Accept': 'application/json',

            },

           body: jsonEncode({
  'name': userData['name'] ?? '',
  'email': userData['email'] ?? '',
  'status': userData['status'] ?? '',
  'education': userData['education'] ?? '',
  'degree': userData['degree'] ?? '',
  'graduationYear': userData['graduationYear'] ?? '',
  'skills': userData['skills'] ?? [],
  'targetRole': userData['targetRole'] ?? '',
  'experienceLevel':
      userData['experienceLevel'] ?? '',
  'preferredLocation':
      userData['preferredLocation'] ?? '',
  'workMode': userData['workMode'] ?? '',
  'expectedSalary':
      userData['expectedSalary'] ?? '',
  'jobType': userData['jobType'] ?? '',
  'companyType':
      userData['companyType'] ?? '',
  'relocation':
      userData['relocation'] ?? '',
}),

          )

          .timeout(

            const Duration(seconds: 60),

          );

      debugPrint(

        'API Status: ${response.statusCode}',

      );

      debugPrint(

        'API Response: ${response.body}',

      );

      if (response.statusCode != 200) {

        throw Exception(

          'Server returned ${response.statusCode}',

        );

      }

      final Map<String, dynamic> result =

          jsonDecode(response.body);

      if (result['success'] != true) {

        throw Exception(

          result['message'] ??

              'AI analysis failed',

        );

      }

      final Map<String, dynamic> analysis =

          Map<String, dynamic>.from(

        result['analysis'] ?? {},

      );

      // Career match

      careerMatch =

          (analysis['careerMatch'] ?? 0)

              is num

          ? (analysis['careerMatch'] ?? 0)

              .toInt()

          : 0;

      // Summary

      summary =

          analysis['summary']?.toString() ?? '';

      // Recommended skills

      recommendedSkills =

          convertToStringList(

        analysis['recommendedSkills'],

      );

      // Recommended roles

      recommendedRoles =

          convertToStringList(

        analysis['recommendedRoles'],

      );

      // Strengths

      strengths =

          convertToStringList(

        analysis['strengths'],

      );

      // Improvements

      improvements =

          convertToStringList(

        analysis['improvements'],

      );

      // Interview topics

      interviewTopics =

          convertToStringList(

        analysis['interviewTopics'],

      );

      // Roadmap

      careerRoadmap = [];

      final roadmapData =

          analysis['careerRoadmap'];

      if (roadmapData is List) {

        for (final item in roadmapData) {

          if (item is Map) {

            careerRoadmap.add(

              Map<String, dynamic>.from(item),

            );

          }

        }

      }

      // Save AI analysis to Firebase

      await saveCareerAnalysis();

      if (!mounted) return;

      Navigator.pushReplacement(
      context,
      MaterialPageRoute(
      builder: (context) => const DashboardScreen(),
  ),
);

      setState(() {

        isLoading = false;

        isRegenerating = false;

      });

    } catch (e) {

      debugPrint(

        'AI Analysis Error: $e',

      );

      if (!mounted) return;

      setState(() {

        isLoading = false;

        isRegenerating = false;

      });

      showError(

        'AI analysis failed: ${e.toString()}',

      );

    }

  }

  // =========================================================

  // CONVERT LIST

  // =========================================================

  List<String> convertToStringList(

    dynamic value,

  ) {

    if (value is List) {

      return value

          .map(

            (item) => item.toString(),

          )

          .where(

            (item) => item.trim().isNotEmpty,

          )

          .toList();

    }

    return [];

  }

  // =========================================================

  // SAVE ANALYSIS

  // =========================================================

  Future<void> saveCareerAnalysis() async {

    try {

      final User? user =

          FirebaseAuth.instance.currentUser;

      if (user == null) return;

      await FirebaseFirestore.instance

          .collection('users')

          .doc(user.uid)

          .set(

        {

          'careerAnalysis': {

            'careerMatch': careerMatch,

            'summary': summary,

            'recommendedSkills':

                recommendedSkills,

            'recommendedRoles':

                recommendedRoles,

            'strengths': strengths,

            'improvements': improvements,

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

        'Career analysis saved successfully.',

      );

    } catch (e) {

      debugPrint(

        'Save Analysis Error: $e',

      );

    }

  }

  // =========================================================

  // REGENERATE

  // =========================================================

  Future<void> regenerateAnalysis() async {

    if (isRegenerating) return;

    setState(() {

      isRegenerating = true;

    });

    await generateAIAnalysis();

  }

  // =========================================================

  // ERROR MESSAGE

  // =========================================================

  void showError(String message) {

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        content: Text(message),

        behavior:

            SnackBarBehavior.floating,

        duration:

            const Duration(seconds: 4),

      ),

    );

  }

  // =========================================================

  // GRADIENT

  // =========================================================

  LinearGradient get primaryGradient =>

      const LinearGradient(

        colors: [

          Color(0xFF2563EB),

          Color(0xFF7C3AED),

        ],

      );

  // =========================================================

  // BUILD

  // =========================================================

  @override

  Widget build(BuildContext context) {

    if (isLoading) {

      return Scaffold(

        backgroundColor:

            const Color(0xFFF8FAFC),

        body: Center(

          child: Column(

            mainAxisAlignment:

                MainAxisAlignment.center,

            children: [

              Container(

                height: 82,

                width: 82,

                decoration: BoxDecoration(

                  gradient:

                      primaryGradient,

                  borderRadius:

                      BorderRadius.circular(24),

                ),

                child: const Icon(

                  Icons.auto_awesome_rounded,

                  color: Colors.white,

                  size: 42,

                ),

              ),

              const SizedBox(height: 25),

              const Text(

                'AI is analyzing your career...',

                style: TextStyle(

                  fontSize: 20,

                  fontWeight:

                      FontWeight.w800,

                  color:

                      Color(0xFF111827),

                ),

              ),

              const SizedBox(height: 10),

              const Text(

                'Finding the best career path for you',

                textAlign: TextAlign.center,

                style: TextStyle(

                  fontSize: 14,

                  color:

                      Color(0xFF64748B),

                ),

              ),

              const SizedBox(height: 25),

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

          const Color(0xFFF8FAFC),

      appBar: AppBar(

        backgroundColor:

            Colors.transparent,

        elevation: 0,

        leading: IconButton(

          icon: const Icon(

            Icons.arrow_back_rounded,

            color:

                Color(0xFF111827),

          ),

          onPressed: () {

            Navigator.pop(context);

          },

        ),

        title: const Text(

          'AI Career Analysis',

          style: TextStyle(

            color:

                Color(0xFF111827),

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

                  Color(0xFF4F46E5),

            ),

          ),

        ],

      ),

      body: SafeArea(

        child: SingleChildScrollView(

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

              buildHeaderCard(),

              const SizedBox(height: 18),

              buildCareerMatchCard(),

              const SizedBox(height: 18),

              buildSummaryCard(),

              const SizedBox(height: 18),

              buildSection(

                title: 'Your Strengths',

                icon:

                    Icons.emoji_events_rounded,

                items: strengths,

              ),

              const SizedBox(height: 18),

              buildSection(

                title:

                    'Areas to Improve',

                icon:

                    Icons.trending_up_rounded,

                items: improvements,

              ),

              const SizedBox(height: 18),

              buildSection(

                title:

                    'Recommended Skills',

                icon:

                    Icons.school_rounded,

                items:

                    recommendedSkills,

              ),

              const SizedBox(height: 18),

              buildRolesCard(),

              const SizedBox(height: 18),

              buildRoadmapCard(),

              const SizedBox(height: 18),

              buildSection(

                title:

                    'Interview Preparation',

                icon:

                    Icons.question_answer_rounded,

                items:

                    interviewTopics,

              ),

              const SizedBox(height: 25),

              buildRegenerateButton(),

            ],

          ),

        ),

      ),

    );

  }

  // =========================================================

  // HEADER CARD

  // =========================================================

  Widget buildHeaderCard() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(22),

      decoration: BoxDecoration(

        gradient: primaryGradient,

        borderRadius:

            BorderRadius.circular(24),

        boxShadow: [

          BoxShadow(

            color:

                const Color(0xFF4F46E5)

                    .withOpacity(0.20),

            blurRadius: 20,

            offset:

                const Offset(0, 10),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Container(

            height: 48,

            width: 48,

            decoration:

                BoxDecoration(

              color: Colors.white

                  .withOpacity(0.18),

              borderRadius:

                  BorderRadius.circular(15),

            ),

            child: const Icon(

              Icons.auto_awesome_rounded,

              color: Colors.white,

              size: 27,

            ),

          ),

          const SizedBox(height: 18),

          Text(

            'Hi ${userData['name'] ?? 'there'} 👋',

            style: const TextStyle(

              color: Colors.white,

              fontSize: 25,

              fontWeight:

                  FontWeight.w800,

            ),

          ),

          const SizedBox(height: 8),

          const Text(

            'Your personalized AI career analysis is ready.',

            style: TextStyle(

              color: Colors.white70,

              fontSize: 14,

              height: 1.5,

            ),

          ),

        ],

      ),

    );

  }

  // =========================================================

  // CAREER MATCH

  // =========================================================

  Widget buildCareerMatchCard() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(22),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(22),

        border: Border.all(

          color:

              const Color(0xFFE2E8F0),

        ),

      ),

      child: Column(

        children: [

          const Text(

            'Career Match',

            style: TextStyle(

              fontSize: 16,

              fontWeight:

                  FontWeight.w700,

              color:

                  Color(0xFF64748B),

            ),

          ),

          const SizedBox(height: 15),

          Stack(

            alignment:

                Alignment.center,

            children: [

              SizedBox(

                height: 150,

                width: 150,

                child:

                    CircularProgressIndicator(

                  value:

                      careerMatch / 100,

                  strokeWidth: 13,

                  backgroundColor:

                      const Color(

                          0xFFE2E8F0),

                  valueColor:

                      const AlwaysStoppedAnimation<

                          Color>(

                    Color(0xFF4F46E5),

                  ),

                ),

              ),

              Column(

                children: [

                  Text(

                    '$careerMatch%',

                    style:

                        const TextStyle(

                      fontSize: 34,

                      fontWeight:

                          FontWeight.w900,

                      color:

                          Color(0xFF111827),

                    ),

                  ),

                  const Text(

                    'Match',

                    style:

                        TextStyle(

                      fontSize: 13,

                      color:

                          Color(0xFF64748B),

                    ),

                  ),

                ],

              ),

            ],

          ),

          const SizedBox(height: 20),

          Text(

            userData['targetRole']

                    ?.toString() ??

                'Your Target Career',

            textAlign:

                TextAlign.center,

            style:

                const TextStyle(

              fontSize: 20,

              fontWeight:

                  FontWeight.w800,

              color:

                  Color(0xFF111827),

            ),

          ),

        ],

      ),

    );

  }

  // =========================================================

  // SUMMARY

  // =========================================================

  Widget buildSummaryCard() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(22),

        border: Border.all(

          color:

              const Color(0xFFE2E8F0),

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                height: 42,

                width: 42,

                decoration:

                    BoxDecoration(

                  gradient:

                      primaryGradient,

                  borderRadius:

                      BorderRadius.circular(

                          13),

                ),

                child: const Icon(

                  Icons.insights_rounded,

                  color: Colors.white,

                  size: 22,

                ),

              ),

              const SizedBox(width: 12),

              const Text(

                'AI Career Summary',

                style: TextStyle(

                  fontSize: 18,

                  fontWeight:

                      FontWeight.w800,

                  color:

                      Color(0xFF111827),

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          Text(

            summary.isEmpty

                ? 'No summary available.'

                : summary,

            style: const TextStyle(

              fontSize: 14,

              height: 1.6,

              color:

                  Color(0xFF475569),

            ),

          ),

        ],

      ),

    );

  }

  // =========================================================

  // GENERIC SECTION

  // =========================================================

  Widget buildSection({

    required String title,

    required IconData icon,

    required List<String> items,

  }) {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(22),

        border: Border.all(

          color:

              const Color(0xFFE2E8F0),

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                height: 42,

                width: 42,

                decoration:

                    BoxDecoration(

                  gradient:

                      primaryGradient,

                  borderRadius:

                      BorderRadius.circular(

                          13),

                ),

                child: Icon(

                  icon,

                  color: Colors.white,

                  size: 22,

                ),

              ),

              const SizedBox(width: 12),

              Expanded(

                child: Text(

                  title,

                  style:

                      const TextStyle(

                    fontSize: 18,

                    fontWeight:

                        FontWeight.w800,

                    color:

                        Color(0xFF111827),

                  ),

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          if (items.isEmpty)

            const Text(

              'No information available.',

              style: TextStyle(

                color:

                    Color(0xFF64748B),

              ),

            ),

          ...items.map(

            (item) => Padding(

              padding:

                  const EdgeInsets.only(

                bottom: 10,

              ),

              child: Row(

                crossAxisAlignment:

                    CrossAxisAlignment.start,

                children: [

                  const Padding(

                    padding:

                        EdgeInsets.only(

                      top: 6,

                    ),

                    child: Icon(

                      Icons

                          .check_circle_rounded,

                      size: 17,

                      color:

                          Color(0xFF4F46E5),

                    ),

                  ),

                  const SizedBox(

                    width: 10,

                  ),

                  Expanded(

                    child: Text(

                      item,

                      style:

                          const TextStyle(

                        fontSize: 14,

                        height: 1.45,

                        color:

                            Color(0xFF475569),

                      ),

                    ),

                  ),

                ],

              ),

            ),

          ),

        ],

      ),

    );

  }

  // =========================================================

  // ROLES

  // =========================================================

  Widget buildRolesCard() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(22),

        border: Border.all(

          color:

              const Color(0xFFE2E8F0),

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                height: 42,

                width: 42,

                decoration:

                    BoxDecoration(

                  gradient:

                      primaryGradient,

                  borderRadius:

                      BorderRadius.circular(

                          13),

                ),

                child: const Icon(

                  Icons.work_rounded,

                  color: Colors.white,

                  size: 22,

                ),

              ),

              const SizedBox(width: 12),

              const Text(

                'Recommended Roles',

                style: TextStyle(

                  fontSize: 18,

                  fontWeight:

                      FontWeight.w800,

                  color:

                      Color(0xFF111827),

                ),

              ),

            ],

          ),

          const SizedBox(height: 16),

          Wrap(

            spacing: 8,

            runSpacing: 8,

            children:

                recommendedRoles

                    .map(

                      (role) => Container(

                        padding:

                            const EdgeInsets

                                .symmetric(

                          horizontal: 14,

                          vertical: 10,

                        ),

                        decoration:

                            BoxDecoration(

                          color:

                              const Color(

                                  0xFFEEF2FF),

                          borderRadius:

                              BorderRadius

                                  .circular(

                                      30),

                        ),

                        child: Text(

                          role,

                          style:

                              const TextStyle(

                            fontSize: 13,

                            fontWeight:

                                FontWeight.w600,

                            color:

                                Color(0xFF4338CA),

                          ),

                        ),

                      ),

                    )

                    .toList(),

          ),

        ],

      ),

    );

  }

  // =========================================================

  // ROADMAP

  // =========================================================

  Widget buildRoadmapCard() {

    return Container(

      width: double.infinity,

      padding:

          const EdgeInsets.all(20),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(22),

        border: Border.all(

          color:

              const Color(0xFFE2E8F0),

        ),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          Row(

            children: [

              Container(

                height: 42,

                width: 42,

                decoration:

                    BoxDecoration(

                  gradient:

                      primaryGradient,

                  borderRadius:

                      BorderRadius.circular(

                          13),

                ),

                child: const Icon(

                  Icons.map_rounded,

                  color: Colors.white,

                  size: 22,

                ),

              ),

              const SizedBox(width: 12),

              const Text(

                'Your Career Roadmap',

                style: TextStyle(

                  fontSize: 18,

                  fontWeight:

                      FontWeight.w800,

                  color:

                      Color(0xFF111827),

                ),

              ),

            ],

          ),

          const SizedBox(height: 20),

          if (careerRoadmap.isEmpty)

            const Text(

              'No roadmap available.',

              style: TextStyle(

                color:

                    Color(0xFF64748B),

              ),

            ),

          ...List.generate(

            careerRoadmap.length,

            (index) {

              final step =

                  careerRoadmap[index];

              final title =

                  step['title']

                          ?.toString() ??

                      'Step ${index + 1}';

              final description =

                  step['description']

                          ?.toString() ??

                      '';

              return Padding(

                padding:

                    const EdgeInsets.only(

                  bottom: 18,

                ),

                child: Row(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    Container(

                      height: 38,

                      width: 38,

                      decoration:

                          BoxDecoration(

                        gradient:

                            primaryGradient,

                        shape:

                            BoxShape.circle,

                      ),

                      alignment:

                          Alignment.center,

                      child: Text(

                        '${index + 1}',

                        style:

                            const TextStyle(

                          color:

                              Colors.white,

                          fontWeight:

                              FontWeight.w800,

                        ),

                      ),

                    ),

                    const SizedBox(

                      width: 14,

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

                              fontSize: 15,

                              fontWeight:

                                  FontWeight.w800,

                              color:

                                  Color(0xFF111827),

                            ),

                          ),

                          const SizedBox(

                            height: 5,

                          ),

                          Text(

                            description,

                            style:

                                const TextStyle(

                              fontSize: 13,

                              height: 1.5,

                              color:

                                  Color(0xFF64748B),

                            ),

                          ),

                        ],

                      ),

                    ),

                  ],

                ),

              );

            },

          ),

        ],

      ),

    );

  }

  // =========================================================

  // REGENERATE BUTTON

  // =========================================================

  Widget buildRegenerateButton() {

    return SizedBox(

      width: double.infinity,

      height: 55,

      child: DecoratedBox(

        decoration: BoxDecoration(

          gradient:

              primaryGradient,

          borderRadius:

              BorderRadius.circular(16),

        ),

        child: ElevatedButton(

          onPressed:

              isRegenerating

                  ? null

                  : regenerateAnalysis,

          style:

              ElevatedButton.styleFrom(

            backgroundColor:

                Colors.transparent,

            shadowColor:

                Colors.transparent,

            shape:

                RoundedRectangleBorder(

              borderRadius:

                  BorderRadius.circular(

                      16),

            ),

          ),

          child: isRegenerating

              ? const SizedBox(

                  height: 22,

                  width: 22,

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

                    Icon(

                      Icons.refresh_rounded,

                      color:

                          Colors.white,

                    ),

                    SizedBox(width: 8),

                    Text(

                      'Regenerate Analysis',

                      style:

                          TextStyle(

                        color:

                            Colors.white,

                        fontSize: 15,

                        fontWeight:

                            FontWeight.w700,

                      ),

                    ),

                  ],

                ),

        ),

      ),

    );

  }

}