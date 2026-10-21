import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class CareerRoadmapScreen extends StatefulWidget {
  const CareerRoadmapScreen({super.key});

  @override
  State<CareerRoadmapScreen> createState() =>
      _CareerRoadmapScreenState();
}

class _CareerRoadmapScreenState
    extends State<CareerRoadmapScreen> {
  static const String apiUrl =
      'https://career-ai-backend-fk2i.onrender.com/api/career-roadmap';

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _roadmap = [];

  Map<String, dynamic> _progress = {};

  bool _isLoading = true;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _loadRoadmap();
  }

  // ============================================================
  // LOAD ROADMAP
  // ============================================================

  Future<void> _loadRoadmap() async {
    try {
      final user = _auth.currentUser;

      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final doc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final data =
          doc.data() ?? <String, dynamic>{};

      _profile = data;

      final savedRoadmap = data['careerRoadmap'];

      final savedProgress =
          data['roadmapProgress'];

      if (savedRoadmap is List &&
          savedRoadmap.isNotEmpty) {
        _roadmap = savedRoadmap
            .whereType<Map>()
            .map(
              (item) => Map<String, dynamic>.from(
                item,
              ),
            )
            .toList();

        if (savedProgress is Map) {
          _progress =
              Map<String, dynamic>.from(
            savedProgress,
          );
        }

        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });

        await _generateRoadmap();
      }
    } catch (error) {
      debugPrint(
        'Load roadmap error: $error',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Unable to load roadmap.',
      );
    }
  }

  // ============================================================
  // GENERATE ROADMAP
  // ============================================================

  Future<void> _generateRoadmap() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Please login first.',
      );
      return;
    }

    if (_profile == null) {
      _showMessage(
        'Profile information not found.',
      );
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final profile = _profile!;

      final skills =
          profile['skills'] is List
              ? List<String>.from(
                  (profile['skills'] as List)
                      .map(
                    (item) => item.toString(),
                  ),
                )
              : <String>[];

      final body = {
        'name':
            profile['name'] ?? '',
        'status':
            profile['status'] ?? '',
        'education':
            profile['education'] ?? '',
        'degree':
            profile['degree'] ?? '',
        'graduationYear':
            profile['graduationYear'] ?? '',
        'skills': skills,
        'targetRole':
            profile['targetRole'] ?? '',
        'experienceLevel':
            profile['experienceLevel'] ?? '',
        'preferredLocation':
            profile['preferredLocation'] ?? '',
        'workMode':
            profile['workMode'] ?? '',
        'expectedSalary':
            profile['expectedSalary'] ?? '',
        'jobType':
            profile['jobType'] ?? '',
        'companyType':
            profile['companyType'] ?? '',
        'relocation':
            profile['relocation'] ?? '',
      };

      debugPrint(
        'Sending roadmap request: ${jsonEncode(body)}',
      );

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              'Content-Type':
                  'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(
              seconds: 90,
            ),
          );

      debugPrint(
        'Roadmap response status: ${response.statusCode}',
      );

      debugPrint(
        'Roadmap response: ${response.body}',
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Roadmap API failed: ${response.statusCode}',
        );
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message'] ??
              'Roadmap generation failed.',
        );
      }

      final roadmapData =
          decoded['roadmap'];

      if (roadmapData is! List) {
        throw Exception(
          'Invalid roadmap received.',
        );
      }

      final generatedRoadmap =
          roadmapData
              .whereType<Map>()
              .map(
                (item) =>
                    Map<String, dynamic>.from(
                  item,
                ),
              )
              .toList();

      final normalizedRoadmap =
          generatedRoadmap
              .map(
                (month) => {
                  'month':
                      month['month']
                              ?.toString() ??
                          '',
                  'focus':
                      month['focus']
                              ?.toString() ??
                          '',
                  'topics':
                      month['topics'] is List
                          ? List<String>.from(
                              (month['topics']
                                      as List)
                                  .map(
                                (item) =>
                                    item.toString(),
                              ),
                            )
                          : <String>[],
                  'projects':
                      month['projects'] is List
                          ? List<String>.from(
                              (month['projects']
                                      as List)
                                  .map(
                                (item) =>
                                    item.toString(),
                              ),
                            )
                          : <String>[],
                },
              )
              .toList();

      final newProgress =
          <String, dynamic>{};

      for (
        int monthIndex = 0;
        monthIndex <
            normalizedRoadmap.length;
        monthIndex++
      ) {
        final monthKey =
            'month_$monthIndex';

        newProgress[monthKey] = {};

        final topics =
            normalizedRoadmap[
                    monthIndex]
                ['topics'] as List<String>;

        for (
          int topicIndex = 0;
          topicIndex <
              topics.length;
          topicIndex++
        ) {
          newProgress[monthKey]
              [topicIndex.toString()] =
              false;
        }
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'careerRoadmap':
              normalizedRoadmap,
          'roadmapGeneratedAt':
              FieldValue.serverTimestamp(),
          'roadmapProgress':
              newProgress,
        },
        SetOptions(
          merge: true,
        ),
      );

      if (!mounted) return;

      setState(() {
        _roadmap =
            normalizedRoadmap;
        _progress = newProgress;
      });

      _showMessage(
        'Your personalized roadmap is ready!',
      );
    } catch (error) {
      debugPrint(
        'Generate roadmap error: $error',
      );

      if (mounted) {
        _showMessage(
          'Unable to generate roadmap. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  // ============================================================
  // SAVE PROGRESS
  // ============================================================

  Future<void> _toggleTopic(
    int monthIndex,
    int topicIndex,
    bool value,
  ) async {
    final user = _auth.currentUser;

    if (user == null) return;

    final monthKey =
        'month_$monthIndex';

    setState(() {
      if (!_progress.containsKey(
        monthKey,
      )) {
        _progress[monthKey] = {};
      }

      if (_progress[monthKey] is! Map) {
        _progress[monthKey] = {};
      }

      _progress[monthKey]
          [topicIndex.toString()] = value;
    });

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'roadmapProgress':
              _progress,
        },
        SetOptions(
          merge: true,
        ),
      );
    } catch (error) {
      debugPrint(
        'Save roadmap progress error: $error',
      );
    }
  }

  // ============================================================
  // CHECK TOPIC
  // ============================================================

  bool _isTopicCompleted(
    int monthIndex,
    int topicIndex,
  ) {
    final monthKey =
        'month_$monthIndex';

    final monthProgress =
        _progress[monthKey];

    if (monthProgress is Map) {
      return monthProgress[
              topicIndex.toString()] ==
          true;
    }

    return false;
  }

  // ============================================================
  // OVERALL PROGRESS
  // ============================================================

  double _overallProgress() {
    int total = 0;
    int completed = 0;

    for (
      int monthIndex = 0;
      monthIndex <
          _roadmap.length;
      monthIndex++
    ) {
      final topics =
          _roadmap[monthIndex]['topics'];

      if (topics is! List) {
        continue;
      }

      for (
        int topicIndex = 0;
        topicIndex <
            topics.length;
        topicIndex++
      ) {
        total++;

        if (_isTopicCompleted(
          monthIndex,
          topicIndex,
        )) {
          completed++;
        }
      }
    }

    if (total == 0) {
      return 0;
    }

    return completed / total;
  }

  // ============================================================
  // MONTH PROGRESS
  // ============================================================

  double _monthProgress(
    int monthIndex,
  ) {
    final month =
        _roadmap[monthIndex];

    final topics =
        month['topics'];

    if (topics is! List ||
        topics.isEmpty) {
      return 0;
    }

    int completed = 0;

    for (
      int topicIndex = 0;
      topicIndex <
          topics.length;
      topicIndex++
    ) {
      if (_isTopicCompleted(
        monthIndex,
        topicIndex,
      )) {
        completed++;
      }
    }

    return completed /
        topics.length;
  }

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final progress =
        _overallProgress();

    return Scaffold(
      backgroundColor:
          const Color(0xFFF6F7FB),

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.white,

        title: const Text(
          'Your Career Roadmap',
          style: TextStyle(
            color: Colors.black87,
            fontWeight:
                FontWeight.w700,
          ),
        ),

        iconTheme:
            const IconThemeData(
          color: Colors.black87,
        ),

        actions: [
          IconButton(
            tooltip:
                'Generate Again',
            onPressed:
                _isGenerating
                    ? null
                    : _generateRoadmap,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),

      body: _buildBody(progress),
    );
  }

  Widget _buildBody(
    double progress,
  ) {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_isGenerating) {
      return _buildGenerating();
    }

    if (_roadmap.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh:
          _generateRoadmap,

      child: ListView(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),
        children: [
          _buildHero(progress),

          const SizedBox(
            height: 18,
          ),

          _buildOverallProgress(
            progress,
          ),

          const SizedBox(
            height: 20,
          ),

          const Text(
            '6-Month Plan',
            style: TextStyle(
              fontSize: 21,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          ...List.generate(
            _roadmap.length,
            (index) =>
                _buildMonthCard(
              index,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHero(
    double progress,
  ) {
    final role =
        _profile?['targetRole']
                ?.toString() ??
            'Software Developer';

    final skills =
        _profile?['skills'] is List
            ? List<String>.from(
                (_profile!['skills']
                        as List)
                    .map(
                  (item) =>
                      item.toString(),
                ),
              )
            : <String>[];

    return Container(
      padding:
          const EdgeInsets.all(20),

      decoration:
          BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xFF5B5FEF),
            Color(0xFF7B61FF),
          ],
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
        ),

        borderRadius:
            BorderRadius.circular(
          24,
        ),

        boxShadow: [
          BoxShadow(
            color: const Color(
              0xFF5B5FEF,
            ).withOpacity(0.20),
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
          const Icon(
            Icons.route_rounded,
            color: Colors.white,
            size: 34,
          ),

          const SizedBox(
            height: 14,
          ),

          const Text(
            'Your Personalized Career Path',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            role,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(
            height: 14,
          ),

          if (skills.isNotEmpty)
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children:
                  skills.map(
                (skill) {
                  return Container(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),

                    decoration:
                        BoxDecoration(
                      color: Colors.white
                          .withOpacity(
                        0.16,
                      ),
                      borderRadius:
                          BorderRadius
                              .circular(
                        30,
                      ),
                    ),

                    child: Text(
                      skill,
                      style:
                          const TextStyle(
                        color:
                            Colors.white,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // OVERALL PROGRESS
  // ============================================================

  Widget _buildOverallProgress(
    double progress,
  ) {
    final percentage =
        (progress * 100)
            .round();

    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,

            children: [
              const Text(
                'Overall Progress',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              Text(
                '$percentage%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              20,
            ),

            child:
                LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor:
                  Colors.grey.shade200,
              valueColor:
                  const AlwaysStoppedAnimation<
                      Color>(
                Color(0xFF5B5FEF),
              ),
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Text(
            progress >= 1
                ? '🎉 Roadmap completed!'
                : 'Complete the topics step by step.',
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MONTH CARD
  // ============================================================

  Widget _buildMonthCard(
    int monthIndex,
  ) {
    final month =
        _roadmap[monthIndex];

    final monthName =
        month['month']
                ?.toString() ??
            'Month ${monthIndex + 1}';

    final focus =
        month['focus']
                ?.toString() ??
            '';

    final topics =
        month['topics'] is List
            ? List<String>.from(
                (month['topics']
                        as List)
                    .map(
                  (item) =>
                      item.toString(),
                ),
              )
            : <String>[];

    final projects =
        month['projects'] is List
            ? List<String>.from(
                (month['projects']
                        as List)
                    .map(
                  (item) =>
                      item.toString(),
                ),
              )
            : <String>[];

    final monthProgress =
        _monthProgress(
      monthIndex,
    );

    final percentage =
        (monthProgress * 100)
            .round();

    return Container(
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          20,
        ),

        border: Border.all(
          color:
              Colors.grey.shade200,
        ),
      ),

      child: Theme(
        data: Theme.of(context)
            .copyWith(
          dividerColor:
              Colors.transparent,
        ),

        child: ExpansionTile(
          tilePadding:
              const EdgeInsets
                  .symmetric(
            horizontal: 16,
            vertical: 5,
          ),

          childrenPadding:
              const EdgeInsets.fromLTRB(
            10,
            0,
            10,
            15,
          ),

          leading: Container(
            width: 45,
            height: 45,

            decoration:
                BoxDecoration(
              color:
                  const Color(
                0xFF5B5FEF,
              ).withOpacity(0.10),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child: Center(
              child: Text(
                '${monthIndex + 1}',
                style:
                    const TextStyle(
                  color:
                      Color(0xFF5B5FEF),
                  fontWeight:
                      FontWeight.w800,
                  fontSize: 17,
                ),
              ),
            ),
          ),

          title: Text(
            monthName,
            style: const TextStyle(
              fontWeight:
                  FontWeight.w800,
              fontSize: 16,
            ),
          ),

          subtitle:
              Text(
            '$percentage% completed',
            style: TextStyle(
              color:
                  Colors.grey.shade600,
              fontSize: 12,
            ),
          ),

          children: [
            if (focus.isNotEmpty)
              Container(
                width:
                    double.infinity,

                margin:
                    const EdgeInsets
                        .only(
                  bottom: 12,
                ),

                padding:
                    const EdgeInsets
                        .all(
                  13,
                ),

                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF4F3FF,
                  ),

                  borderRadius:
                      BorderRadius
                          .circular(
                    14,
                  ),
                ),

                child: Row(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,

                  children: [
                    const Icon(
                      Icons
                          .flag_rounded,
                      size: 19,
                      color:
                          Color(
                        0xFF5B5FEF,
                      ),
                    ),

                    const SizedBox(
                      width: 9,
                    ),

                    Expanded(
                      child: Text(
                        focus,
                        style:
                            const TextStyle(
                          fontSize:
                              13,
                          height: 1.4,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            if (topics.isNotEmpty)
              const Align(
                alignment:
                    Alignment.centerLeft,
                child: Padding(
                  padding:
                      EdgeInsets.only(
                    left: 6,
                    bottom: 5,
                  ),
                  child: Text(
                    'Topics',
                    style:
                        TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),

            ...List.generate(
              topics.length,
              (topicIndex) {
                final completed =
                    _isTopicCompleted(
                  monthIndex,
                  topicIndex,
                );

                return Container(
                  margin:
                      const EdgeInsets
                          .only(
                    bottom: 6,
                  ),

                  decoration:
                      BoxDecoration(
                    color: completed
                        ? const Color(
                            0xFFF0FDF4,
                          )
                        : const Color(
                            0xFFF8F9FC,
                          ),

                    borderRadius:
                        BorderRadius
                            .circular(
                      13,
                    ),
                  ),

                  child:
                      CheckboxListTile(
                    value: completed,

                    onChanged:
                        (value) {
                      _toggleTopic(
                        monthIndex,
                        topicIndex,
                        value ?? false,
                      );
                    },

                    activeColor:
                        const Color(
                      0xFF5B5FEF,
                    ),

                    controlAffinity:
                        ListTileControlAffinity
                            .leading,

                    contentPadding:
                        const EdgeInsets
                            .symmetric(
                      horizontal: 8,
                    ),

                    title: Text(
                      topics[
                          topicIndex],
                      style:
                          TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight:
                            FontWeight.w500,
                        decoration:
                            completed
                                ? TextDecoration
                                    .lineThrough
                                : null,
                        color: completed
                            ? Colors
                                .grey
                            : Colors
                                .black87,
                      ),
                    ),
                  ),
                );
              },
            ),

            if (projects.isNotEmpty) ...[
              const SizedBox(
                height: 10,
              ),

              const Align(
                alignment:
                    Alignment.centerLeft,
                child: Padding(
                  padding:
                      EdgeInsets.only(
                    left: 6,
                    bottom: 8,
                  ),
                  child: Text(
                    'Projects / Deliverables',
                    style:
                        TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),

              ...projects.map(
                (project) {
                  return Container(
                    width:
                        double.infinity,

                    margin:
                        const EdgeInsets
                            .only(
                      bottom: 7,
                    ),

                    padding:
                        const EdgeInsets
                            .all(
                      13,
                    ),

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFFFF8EC,
                      ),

                      borderRadius:
                          BorderRadius
                              .circular(
                        13,
                      ),
                    ),

                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [
                        const Icon(
                          Icons
                              .code_rounded,
                          size: 19,
                          color:
                              Color(
                            0xFFE58A00,
                          ),
                        ),

                        const SizedBox(
                          width: 9,
                        ),

                        Expanded(
                          child: Text(
                            project,
                            style:
                                const TextStyle(
                              fontSize:
                                  13,
                              height:
                                  1.35,
                              fontWeight:
                                  FontWeight
                                      .w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ============================================================
  // GENERATING SCREEN
  // ============================================================

  Widget _buildGenerating() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            const SizedBox(
              width: 55,
              height: 55,
              child:
                  CircularProgressIndicator(
                strokeWidth: 4,
                valueColor:
                    AlwaysStoppedAnimation<
                        Color>(
                  Color(0xFF5B5FEF),
                ),
              ),
            ),

            const SizedBox(
              height: 25,
            ),

            const Text(
              'Creating Your Career Roadmap...',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 21,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              'AI is analyzing your skills, target role and preferences.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              padding:
                  const EdgeInsets.all(
                20,
              ),

              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF5B5FEF,
                ).withOpacity(0.10),

                shape:
                    BoxShape.circle,
              ),

              child: const Icon(
                Icons.route_rounded,
                size: 50,
                color:
                    Color(0xFF5B5FEF),
              ),
            ),

            const SizedBox(
              height: 20,
            ),

            const Text(
              'No Roadmap Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.w800,
              ),
            ),

            const SizedBox(
              height: 10,
            ),

            Text(
              'Generate a personalized roadmap based on your career profile.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                color:
                    Colors.grey.shade600,
                height: 1.4,
              ),
            ),

            const SizedBox(
              height: 22,
            ),

            ElevatedButton.icon(
              onPressed:
                  _isGenerating
                      ? null
                      : _generateRoadmap,

              icon: const Icon(
                Icons.auto_awesome,
              ),

              label: const Text(
                'Generate Roadmap',
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF5B5FEF,
                ),

                foregroundColor:
                    Colors.white,

                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 22,
                  vertical: 14,
                ),

                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }
}