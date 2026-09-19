import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class JobModel {
  final String id;
  final String title;
  final String company;
  final String location;
  final String workMode;
  final String salary;
  final String jobType;
  final List<String> skills;
  final String description;
  final String applyUrl;

  JobModel({
    required this.id,
    required this.title,
    required this.company,
    required this.location,
    required this.workMode,
    required this.salary,
    required this.jobType,
    required this.skills,
    required this.description,
    required this.applyUrl,
  });

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Unknown Role',
      company: json['company']?.toString() ?? 'Unknown Company',
      location: json['location']?.toString() ?? 'Unknown Location',
      workMode: json['workMode']?.toString() ?? 'On-site',
      salary: json['salary']?.toString() ?? 'Not disclosed',
      jobType: json['jobType']?.toString() ?? 'Full-time',
      skills: json['skills'] is List
          ? List<String>.from(
              (json['skills'] as List).map(
                (e) => e.toString(),
              ),
            )
          : [],
      description:
          json['description']?.toString() ?? 'No description available.',
      applyUrl: json['applyUrl']?.toString() ?? '',
    );
  }
}

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  // ============================================================
  // BACKEND
  // ============================================================

static const String baseUrl =
    'https://career-ai-backend-fk2i.onrender.com';

  // ============================================================
  // JOB DATA
  // ============================================================

  List<JobModel> allJobs = [];
  List<JobModel> filteredJobs = [];

  bool isLoading = true;
  String? errorMessage;

  // ============================================================
  // PROFILE
  // ============================================================

  String? targetRole;
  String? preferredLocation;
  String? preferredWorkMode;
  String? preferredJobType;

  // ============================================================
  // SEARCH
  // ============================================================

  String searchQuery = '';
  String selectedFilter = 'All';

  final TextEditingController searchController =
      TextEditingController();

  final List<String> filters = [
    'All',
    'Remote',
    'Hybrid',
    'Internship',
    'Full-time',
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    loadProfileAndJobs();

    searchController.addListener(() {
      if (!mounted) return;

      searchQuery = searchController.text.trim().toLowerCase();

      applyFilters();
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> loadProfileAndJobs() async {
    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        final data = doc.data();

        if (data != null) {
          targetRole = data['targetRole']?.toString();

          preferredLocation =
              data['preferredLocation']?.toString();

          preferredWorkMode =
              data['workMode']?.toString();

          preferredJobType =
              data['jobType']?.toString();
        }
      }

      await fetchJobs();
    } catch (e) {
      debugPrint('Profile error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load profile.';
      });
    }
  }

  // ============================================================
  // FETCH JOBS
  // ============================================================

  Future<void> fetchJobs() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final Uri uri = Uri.parse('$baseUrl/api/jobs');

      debugPrint('Fetching jobs: $uri');

      final response = await http.get(uri).timeout(
            const Duration(seconds: 15),
          );

      debugPrint('Status: ${response.statusCode}');
      debugPrint('Response: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
          'Server returned ${response.statusCode}',
        );
      }

      final dynamic decoded = jsonDecode(response.body);

      List<dynamic> jobsJson = [];

      if (decoded is List) {
        jobsJson = decoded;
      } else if (decoded is Map && decoded['jobs'] is List) {
        jobsJson = List<dynamic>.from(decoded['jobs']);
      } else if (decoded is Map && decoded['data'] is List) {
        jobsJson = List<dynamic>.from(decoded['data']);
      } else {
        throw Exception('Invalid jobs API response');
      }

      final List<JobModel> jobs = jobsJson
          .whereType<Map>()
          .map(
            (job) => JobModel.fromJson(
              Map<String, dynamic>.from(job),
            ),
          )
          .toList();

      debugPrint('Jobs received: ${jobs.length}');

      if (!mounted) return;

      setState(() {
        allJobs = jobs;
        filteredJobs = List<JobModel>.from(jobs);
        isLoading = false;
      });

      applyFilters();
    } catch (e) {
      debugPrint('Jobs API Error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Could not connect to Jobs server.\n\n$e';
      });
    }
  }

  // ============================================================
  // SEARCH + FILTER
  // ============================================================

  void applyFilters() {
    List<JobModel> result =
        List<JobModel>.from(allJobs);

    // SEARCH
    if (searchQuery.isNotEmpty) {
      result = result.where((job) {
        final title = job.title.toLowerCase();
        final company = job.company.toLowerCase();
        final location = job.location.toLowerCase();
        final skills =
            job.skills.join(' ').toLowerCase();
        final description =
            job.description.toLowerCase();

        return title.contains(searchQuery) ||
            company.contains(searchQuery) ||
            location.contains(searchQuery) ||
            skills.contains(searchQuery) ||
            description.contains(searchQuery);
      }).toList();
    }

    // FILTER
    if (selectedFilter != 'All') {
      result = result.where((job) {
        final mode = job.workMode.toLowerCase();
        final type = job.jobType.toLowerCase();
        final filter = selectedFilter.toLowerCase();

        return mode == filter || type == filter;
      }).toList();
    }

    // SORT BY MATCH SCORE
    result.sort(
      (a, b) => getMatchScore(b).compareTo(
        getMatchScore(a),
      ),
    );

    if (!mounted) return;

    setState(() {
      filteredJobs = result;
    });
  }

  // ============================================================
  // MATCH SCORE
  // ============================================================

  int getMatchScore(JobModel job) {
    int score = 50;

    final jobTitle = job.title.toLowerCase();
    final jobLocation = job.location.toLowerCase();
    final jobWorkMode = job.workMode.toLowerCase();
    final jobType = job.jobType.toLowerCase();
    final jobSkills =
        job.skills.join(' ').toLowerCase();

    // ROLE
    if (targetRole != null &&
        targetRole!.isNotEmpty) {
      final role = targetRole!.toLowerCase();

      if (jobTitle.contains(role)) {
        score += 25;
      } else {
        final words = role
            .split(RegExp(r'[\s/,-]+'))
            .where((word) => word.length > 2)
            .toList();

        int matched = 0;

        for (final word in words) {
          if (jobTitle.contains(word) ||
              jobSkills.contains(word)) {
            matched++;
          }
        }

        if (matched > 0) {
          score += 15;
        }
      }
    }

    // LOCATION
    if (preferredLocation != null &&
        preferredLocation!.isNotEmpty) {
      final location =
          preferredLocation!.toLowerCase();

      if (jobLocation.contains(location)) {
        score += 10;
      }

      if (jobLocation == 'remote' ||
          jobWorkMode == 'remote') {
        score += 5;
      }
    }

    // WORK MODE
    if (preferredWorkMode != null &&
        preferredWorkMode!.isNotEmpty) {
      if (jobWorkMode ==
          preferredWorkMode!.toLowerCase()) {
        score += 7;
      }
    }

    // JOB TYPE
    if (preferredJobType != null &&
        preferredJobType!.isNotEmpty) {
      if (jobType ==
          preferredJobType!.toLowerCase()) {
        score += 8;
      }
    }

    return score.clamp(0, 100);
  }

  // ============================================================
  // OPEN DETAILS
  // ============================================================

  void openJobDetails(JobModel job) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            JobDetailsScreen(job: job),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        title: const Text(
          'Find Jobs',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            onPressed: fetchJobs,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: fetchJobs,
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : errorMessage != null
                ? _buildErrorState()
                : _buildJobsContent(),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildErrorState() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height:
              MediaQuery.of(context).size.height * 0.25,
        ),
        const Icon(
          Icons.cloud_off_rounded,
          size: 70,
          color: Colors.grey,
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'Jobs server unavailable',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            errorMessage ?? '',
            textAlign: TextAlign.center,
            style:
                const TextStyle(color: Colors.grey),
          ),
        ),
        const SizedBox(height: 25),
        Center(
          child: ElevatedButton.icon(
            onPressed: fetchJobs,
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // CONTENT
  // ============================================================

  Widget _buildJobsContent() {
    return ListView(
      physics:
          const AlwaysScrollableScrollPhysics(),
      padding:
          const EdgeInsets.fromLTRB(16, 5, 16, 30),
      children: [
        _buildSearchBar(),

        const SizedBox(height: 18),

        _buildAIMatchCard(),

        const SizedBox(height: 20),

        _buildFilters(),

        const SizedBox(height: 20),

        Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${filteredJobs.length} Jobs Found',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (targetRole != null &&
                targetRole!.isNotEmpty)
              Flexible(
                child: Text(
                  targetRole!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    color: Color(0xFF6366F1),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 12),

        if (filteredJobs.isEmpty)
          _buildEmptyState()
        else
          ...filteredJobs.map(
            (job) => _buildJobCard(job),
          ),
      ],
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        decoration: InputDecoration(
          hintText:
              'Search jobs, skills, companies...',
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF6366F1),
          ),
          suffixIcon:
              searchController.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        searchController.clear();
                      },
                      icon:
                          const Icon(Icons.close),
                    )
                  : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(
            vertical: 16,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // AI CARD
  // ============================================================

  Widget _buildAIMatchCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF6366F1),
            Color(0xFF8B5CF6),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color:
                  Colors.white.withOpacity(0.2),
              borderRadius:
                  BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Job Matches',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  targetRole != null &&
                          targetRole!.isNotEmpty
                      ? 'Jobs matched with your $targetRole career goal'
                      : 'Jobs selected based on your profile',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) =>
            const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];

          final isSelected =
              selectedFilter == filter;

          return GestureDetector(
            onTap: () {
              setState(() {
                selectedFilter = filter;
              });

              applyFilters();
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.white,
                borderRadius:
                    BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF6366F1)
                      : Colors.grey.shade300,
                ),
              ),
              child: Text(
                filter,
                style: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // JOB CARD
  // ============================================================

  Widget _buildJobCard(JobModel job) {
    final score = getMatchScore(job);

    return GestureDetector(
      onTap: () => openJobDetails(job),
      child: Container(
        margin:
            const EdgeInsets.only(bottom: 14),
        padding:
            const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xFF6366F1),
                        Color(0xFF8B5CF6),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      job.company.isNotEmpty
                          ? job.company[0]
                              .toUpperCase()
                          : 'J',
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          fontSize: 17,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        job.company,
                        style:
                            const TextStyle(
                          color: Colors.grey,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFEDE9FE),
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$score%',
                    style:
                        const TextStyle(
                      color:
                          Color(0xFF6366F1),
                      fontWeight:
                          FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _infoChip(
                  Icons.location_on_outlined,
                  job.location,
                ),
                _infoChip(
                  Icons.work_outline,
                  job.workMode,
                ),
                _infoChip(
                  Icons.access_time,
                  job.jobType,
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              job.salary,
              style:
                  const TextStyle(
                color: Color(0xFF16A34A),
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 12),

            if (job.skills.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: job.skills
                    .take(4)
                    .map(
                      (skill) => Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFF3F4F6,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(8),
                        ),
                        child: Text(
                          skill,
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color:
                                Colors.black87,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),

            const SizedBox(height: 15),

            SizedBox(
              width: double.infinity,
              child:
                  ElevatedButton.icon(
                onPressed: () =>
                    openJobDetails(job),
                icon: const Icon(
                  Icons.open_in_new,
                  size: 18,
                ),
                label: const Text(
                  'View & Apply',
                ),
                style:
                    ElevatedButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF6366F1),
                  foregroundColor:
                      Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(
                    vertical: 13,
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
      ),
    );
  }

  // ============================================================
  // INFO CHIP
  // ============================================================

  Widget _infoChip(
    IconData icon,
    String text,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius:
            BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color:
                const Color(0xFF6366F1),
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style:
                const TextStyle(
              fontSize: 11,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(35),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            size: 65,
            color: Colors.grey,
          ),
          const SizedBox(height: 15),
          const Text(
            'No jobs found',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try changing your search or filters.',
            textAlign: TextAlign.center,
            style:
                TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 15),
          TextButton(
            onPressed: () {
              searchController.clear();

              setState(() {
                selectedFilter = 'All';
              });

              applyFilters();
            },
            child:
                const Text('Clear Filters'),
          ),
        ],
      ),
    );
  }
}

// ==================================================================
// JOB DETAILS SCREEN
// ==================================================================

class JobDetailsScreen extends StatelessWidget {
  final JobModel job;

  const JobDetailsScreen({
    super.key,
    required this.job,
  });

  // ================================================================
  // OPEN JOB WEBSITE
  // ================================================================

  Future<void> applyForJob(
    BuildContext context,
  ) async {
    if (job.applyUrl.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Apply link is not available for this job.',
          ),
        ),
      );

      return;
    }

    final Uri? uri =
        Uri.tryParse(job.applyUrl.trim());

    if (uri == null ||
        (uri.scheme != 'http' &&
            uri.scheme != 'https')) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Invalid job website link.',
          ),
        ),
      );

      return;
    }

    debugPrint(
      'Opening job URL: ${uri.toString()}',
    );

    try {
      // IMPORTANT:
      // Directly launch the browser.
      // We are NOT using canLaunchUrl()
      // because Android may return false
      // even when the URL can actually open.

      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        if (!context.mounted) return;

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open browser. Please check your browser.',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        'Open website error: $e',
      );

      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Unable to open job website.\n$e',
          ),
        ),
      );
    }
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F8FC),

      appBar: AppBar(
        title: const Text(
          'Job Details',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor:
            Colors.transparent,
        elevation: 0,
        foregroundColor:
            Colors.black87,
      ),

      body: ListView(
        padding:
            const EdgeInsets.all(18),
        children: [
          // HEADER
          Container(
            padding:
                const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient:
                  const LinearGradient(
                colors: [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
              ),
              borderRadius:
                  BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  job.title,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  job.company,
                  style:
                      const TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color:
                          Colors.white70,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        job.location,
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                Text(
                  '${job.workMode} • ${job.jobType}',
                  style:
                      const TextStyle(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // SALARY
          _sectionTitle('Salary'),

          const SizedBox(height: 7),

          Text(
            job.salary,
            style:
                const TextStyle(
              fontSize: 17,
              color:
                  Color(0xFF16A34A),
              fontWeight:
                  FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          // SKILLS
          _sectionTitle(
            'Required Skills',
          ),

          const SizedBox(height: 8),

          if (job.skills.isEmpty)
            const Text(
              'Skills not specified.',
              style:
                  TextStyle(
                color: Colors.grey,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: job.skills
                  .map(
                    (skill) => Chip(
                      label:
                          Text(skill),
                    ),
                  )
                  .toList(),
            ),

          const SizedBox(height: 20),

          // DESCRIPTION
          _sectionTitle(
            'Job Description',
          ),

          const SizedBox(height: 8),

          Text(
            job.description,
            style:
                const TextStyle(
              fontSize: 15,
              height: 1.6,
              color:
                  Colors.black87,
            ),
          ),

          const SizedBox(height: 30),

          // APPLY BUTTON
          SizedBox(
            height: 54,
            child:
                ElevatedButton.icon(
              onPressed: () =>
                  applyForJob(context),

              icon: const Icon(
                Icons.open_in_new,
              ),

              label: const Text(
                'Apply on Website',
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(
                  0xFF6366F1,
                ),
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          const Center(
            child: Text(
              'You will be redirected to the original job website.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // SECTION TITLE
  // ================================================================

  Widget _sectionTitle(
    String title,
  ) {
    return Text(
      title,
      style:
          const TextStyle(
        fontSize: 19,
        fontWeight:
            FontWeight.bold,
      ),
    );
  }
}