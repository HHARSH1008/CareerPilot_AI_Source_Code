import 'dart:convert';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:url_launcher/url_launcher.dart';

class JobModel {

  final String id;

  final String company;

  final String title;

  final String location;

  final String workMode;

  final String salary;

  final String experience;

  final String jobType;

  final String description;

  final List<String> skills;

  final String posted;

  final String applyUrl;

  final String source;

  const JobModel({

    required this.id,

    required this.company,

    required this.title,

    required this.location,

    required this.workMode,

    required this.salary,

    required this.experience,

    required this.jobType,

    required this.description,

    required this.skills,

    required this.posted,

    required this.applyUrl,

    required this.source,

  });

  factory JobModel.fromJson(Map<String, dynamic> json) {

    final rawSkills = json['skills'];

    return JobModel(

      id: json['id']?.toString() ??

          DateTime.now().microsecondsSinceEpoch.toString(),

      company: json['company']?.toString() ?? 'Company',

      title: json['title']?.toString() ?? 'Software Developer',

      location: json['location']?.toString() ?? 'India',

      workMode:

          (json['workMode'] ?? json['mode'])?.toString() ?? 'Not specified',

      salary: json['salary']?.toString() ?? 'Not disclosed',

      experience: json['experience']?.toString() ?? 'Fresher',

      jobType:

          (json['jobType'] ?? json['type'])?.toString() ?? 'Full-time',

      description: json['description']?.toString() ??

          'Software development opportunity.',

      skills: rawSkills is List

          ? rawSkills

              .map((e) => e.toString())

              .where((e) => e.trim().isNotEmpty)

              .toList()

          : const [],

      posted: json['posted']?.toString() ??

          json['updated']?.toString() ??

          'Recently',

      applyUrl: json['applyUrl']?.toString() ?? '',

      source: json['source']?.toString() ?? 'Jooble',

    );

  }

}

class JobsScreen extends StatefulWidget {

  const JobsScreen({super.key});

  @override

  State<JobsScreen> createState() => _JobsScreenState();

}

class _JobsScreenState extends State<JobsScreen> {

  static const String baseUrl =

      'https://career-ai-backend-fk2i.onrender.com';

  List<JobModel> allJobs = [];

  List<JobModel> filteredJobs = [];

  List<String> userSkills = [];

  String targetRole = '';

  String preferredLocation = '';

  String preferredWorkMode = '';

  String preferredJobType = '';

  bool isLoading = true;

  bool isRefreshing = false;

  bool isFilterLoading = false;

  String? errorMessage;

  final Set<String> savedJobIds = <String>{};
  final Set<String> appliedJobIds = <String>{};

  String selectedFilter = 'All';

  String searchQuery = '';

  final TextEditingController searchController =

      TextEditingController();

  final List<String> filters = const [

    'All',

    'Remote',

    'Hybrid',

    'On-site',

    'Internship',

    'Full-time',

  ];

  @override

  void initState() {

    super.initState();

    searchController.addListener(() {

      searchQuery = searchController.text.trim().toLowerCase();

      applyLocalSearch();

    });

    loadJobs();

  }

  @override

  void dispose() {

    searchController.dispose();

    super.dispose();

  }

  // ============================================================

  // LOAD INITIAL JOBS

  // ============================================================

  Future<void> loadJobs() async {

    if (mounted) {

      setState(() {

        isLoading = true;

        errorMessage = null;

      });

    }

    try {

      await _loadUserProfile();
      await _loadJobState();
      await _loadJobViewState();

      await _fetchJobs(

        filter: 'All',

        showFullLoader: false,

      );

      if (mounted) {

        setState(() {

          isLoading = false;

          isRefreshing = false;

        });

      }

    } catch (e) {

      debugPrint('Jobs API error: $e');

      if (mounted) {

        setState(() {

          isLoading = false;

          isRefreshing = false;

          isFilterLoading = false;

          errorMessage =

              'Unable to load live jobs. Please check your internet connection and try again.';

          allJobs = [];

          filteredJobs = [];

        });

      }

    }

  }

  // ============================================================

  // FETCH JOBS FROM BACKEND

  // ============================================================

  Future<void> _fetchJobs({

    required String filter,

    bool showFullLoader = true,

  }) async {

    if (showFullLoader && mounted) {

      setState(() {

        isFilterLoading = true;

        errorMessage = null;

      });

    }

    try {

      String role = targetRole.trim();

      if (role.isEmpty ||

          role.toLowerCase() == 'any role') {

        role = 'Flutter Developer';

      }

      String location = preferredLocation.trim();

      if (location.isEmpty ||

          location.toLowerCase() == 'any location') {

        location = 'India';

      }

      // ----------------------------------------------------------

      // IMPORTANT:

      // Filter keyword is added to the backend search.

      // This makes Remote / Internship / Hybrid / On-site

      // search fresh jobs instead of filtering only 20 jobs.

      // ----------------------------------------------------------

      String searchKeywords = role;

      switch (filter) {

        case 'Remote':

          searchKeywords = '$role remote';

          location = 'India';

          break;

        case 'Hybrid':

          searchKeywords = '$role hybrid';

          break;

        case 'On-site':

          searchKeywords = '$role on-site';

          break;

        case 'Internship':

          searchKeywords = '$role internship';

          break;

        case 'Full-time':

          searchKeywords = '$role full time';

          break;

        case 'All':

        default:

          searchKeywords = role;

          break;

      }

      final queryParameters = <String, String>{

        'keywords': searchKeywords,

        'location': location,

        'page': '1',

        'radius': '25',

        'resultOnPage': '20',

      };

      final uri = Uri.parse(

        '$baseUrl/api/jobs',

      ).replace(

        queryParameters: queryParameters,

      );

      debugPrint('--------------------------------');

      debugPrint('JOBS API REQUEST');

      debugPrint('Filter: $filter');

      debugPrint('Role: $role');

      debugPrint('Location: $location');

      debugPrint('Keywords: $searchKeywords');

      debugPrint('URL: $uri');

      debugPrint('--------------------------------');

      final response = await http

          .get(

            uri,

            headers: const {

              'Accept': 'application/json',

              'Content-Type': 'application/json',

            },

          )

          .timeout(

            const Duration(seconds: 60),

          );

      debugPrint(

        'Jobs API Status: ${response.statusCode}',

      );

      if (response.statusCode != 200) {

        throw Exception(

          'Jobs server returned ${response.statusCode}',

        );

      }

      final decoded = jsonDecode(response.body);

      final rawJobs = decoded is Map &&

              decoded['jobs'] is List

          ? decoded['jobs'] as List

          : decoded is List

              ? decoded

              : <dynamic>[];

      final jobs = rawJobs

          .whereType<Map>()

          .map(

            (job) => JobModel.fromJson(

              Map<String, dynamic>.from(job),

            ),

          )

          .toList();

      allJobs = jobs;

      // Apply search text locally.

      applyLocalSearch();

      if (jobs.isEmpty) {

        if (filter == 'All') {

          errorMessage =

              'No live jobs found for your selected career profile.';

        } else {

          errorMessage =

              'No $filter jobs found for your selected role. Try another filter.';

        }

      } else {

        errorMessage = null;

      }

      if (mounted) {

        setState(() {

          isFilterLoading = false;

        });

      }

    } catch (e) {

      debugPrint(

        'Fetch jobs error for $filter: $e',

      );

      if (mounted) {

        setState(() {

          isFilterLoading = false;

          if (filter == 'All') {

            errorMessage =

                'Unable to load live jobs. Please try again.';

          } else {

            errorMessage =

                'Unable to load $filter jobs. Please try again.';

          }

          allJobs = [];

          filteredJobs = [];

        });

      }

    }

  }

  // ============================================================

  // LOAD USER PROFILE

  // ============================================================

  Future<void> _loadUserProfile() async {

    try {

      final user =

          FirebaseAuth.instance.currentUser;

      if (user == null) {

        return;

      }

      final doc = await FirebaseFirestore

          .instance

          .collection('users')

          .doc(user.uid)

          .get();

      final data = doc.data() ?? {};

      // ----------------------------------------------------------

      // Skills

      // ----------------------------------------------------------

      final rawSkills = data['skills'];

      if (rawSkills is List) {

        userSkills = rawSkills

            .map((e) => e.toString().trim())

            .where((e) => e.isNotEmpty)

            .toSet()

            .toList();

      }

      // ----------------------------------------------------------

      // Target Role

      // ----------------------------------------------------------

      targetRole =

          data['targetRole']?.toString().trim() ?? '';

      // ----------------------------------------------------------

      // Preferred Location

      // ----------------------------------------------------------

      preferredLocation =

          data['preferredLocation']?.toString().trim() ?? '';

      // ----------------------------------------------------------

      // Work Mode

      // ----------------------------------------------------------

      preferredWorkMode =

          data['workMode']?.toString().trim() ?? '';

      // ----------------------------------------------------------

      // Job Type

      // ----------------------------------------------------------

      preferredJobType =

          data['jobType']?.toString().trim() ?? '';

      debugPrint('--------------------------------');

      debugPrint('USER JOB PROFILE');

      debugPrint('Target Role: $targetRole');

      debugPrint(

        'Preferred Location: $preferredLocation',

      );

      debugPrint(

        'Work Mode: $preferredWorkMode',

      );

      debugPrint(

        'Job Type: $preferredJobType',

      );

      debugPrint('Skills: $userSkills');

      debugPrint('--------------------------------');

    } catch (e) {

      debugPrint(

        'User profile loading error: $e',

      );

    }

  }

  // ============================================================

  // ============================================================
  // PERSISTENT JOB STATE
  // ============================================================

  String? _currentUid() => FirebaseAuth.instance.currentUser?.uid;

  String _jobDocumentId(String jobId) => base64UrlEncode(utf8.encode(jobId)).replaceAll('=', '');

  Map<String, dynamic> _jobToMap(JobModel job) => {
    'jobId': job.id, 'company': job.company, 'title': job.title, 'location': job.location,
    'workMode': job.workMode, 'salary': job.salary, 'experience': job.experience, 'jobType': job.jobType,
    'description': job.description, 'skills': job.skills, 'posted': job.posted, 'applyUrl': job.applyUrl, 'source': job.source,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Future<void> _loadJobState() async {
    final uid = _currentUid(); if (uid == null) return;
    try {
      final db = FirebaseFirestore.instance;
      final saved = await db.collection('users').doc(uid).collection('savedJobs').get();
      final applied = await db.collection('users').doc(uid).collection('appliedJobs').get();
      savedJobIds..clear()..addAll(saved.docs.map((d) => d.data()['jobId']?.toString() ?? d.id));
      appliedJobIds..clear()..addAll(applied.docs.map((d) => d.data()['jobId']?.toString() ?? d.id));
    } catch (e) { debugPrint('Load job state error: $e'); }
  }

  Future<void> _toggleSavedJob(JobModel job) async {
    final uid = _currentUid(); if (uid == null) { _showJobMessage('Please login first.'); return; }
    final isSaved = savedJobIds.contains(job.id);
    final ref = FirebaseFirestore.instance.collection('users').doc(uid).collection('savedJobs').doc(_jobDocumentId(job.id));
    try {
      if (isSaved) { await ref.delete(); savedJobIds.remove(job.id); } else { await ref.set(_jobToMap(job)); savedJobIds.add(job.id); }
      if (mounted) setState(() {});
      _showJobMessage(isSaved ? 'Job removed from saved jobs.' : 'Job saved successfully.');
    } catch (e) { debugPrint('Save job error: $e'); _showJobMessage('Unable to save this job. Please try again.'); }
  }

  Future<void> _markApplied(JobModel job) async {
    final uid = _currentUid(); if (uid == null) { _showJobMessage('Please login first.'); return; }
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).collection('appliedJobs').doc(_jobDocumentId(job.id)).set({..._jobToMap(job), 'appliedAt': FieldValue.serverTimestamp(), 'status': 'Applied'}, SetOptions(merge: true));
      appliedJobIds.add(job.id); if (mounted) setState(() {});
      _showJobMessage('Application marked as applied.');
    } catch (e) { debugPrint('Mark applied error: $e'); _showJobMessage('Unable to save application status.'); }
  }

  Future<void> _saveJobViewState() async {
    final uid = _currentUid(); if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({'jobViewState': {'selectedFilter': selectedFilter, 'searchQuery': searchController.text.trim(), 'updatedAt': FieldValue.serverTimestamp()}}, SetOptions(merge: true));
    } catch (e) { debugPrint('Save job view state error: $e'); }
  }

  Future<void> _loadJobViewState() async {
    final uid = _currentUid(); if (uid == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final state = (doc.data() ?? {})['jobViewState'];
      if (state is Map) {
        final filter = state['selectedFilter']?.toString(); final search = state['searchQuery']?.toString() ?? '';
        if (filter != null && filters.contains(filter)) selectedFilter = filter;
        searchController.text = search; searchQuery = search.toLowerCase();
      }
    } catch (e) { debugPrint('Load job view state error: $e'); }
  }

  void _showJobMessage(String message) { if (!mounted) return; ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message))); }

  // LOCAL SEARCH

  // ============================================================

  void applyLocalSearch() {

    List<JobModel> jobs = List.from(allJobs);

    if (searchQuery.isNotEmpty) {

      jobs = jobs.where((job) {

        final searchableText = [

          job.title,

          job.company,

          job.location,

          job.workMode,

          job.jobType,

          job.salary,

          job.experience,

          job.description,

          job.skills.join(' '),

        ].join(' ').toLowerCase();

        return searchableText.contains(

          searchQuery,

        );

      }).toList();

    }

    if (mounted) {

      setState(() {

        filteredJobs = jobs;

      });

    }

  }

  // ============================================================

  // FILTER SELECT

  // ============================================================

  Future<void> selectFilter(

    String filter,

  ) async {

    if (isFilterLoading) {

      return;

    }

    setState(() {

      selectedFilter = filter;

      isFilterLoading = true;

      errorMessage = null;

    });

    await _saveJobViewState();

    await _fetchJobs(

      filter: filter,

      showFullLoader: true,

    );

  }

  // ============================================================

  // REFRESH

  // ============================================================

  Future<void> refreshJobs() async {

    if (isRefreshing ||

        isFilterLoading) {

      return;

    }

    setState(() {

      isRefreshing = true;

    });

    try {

      await _loadUserProfile();

      await _fetchJobs(

        filter: selectedFilter,

        showFullLoader: false,

      );

    } finally {

      if (mounted) {

        setState(() {

          isRefreshing = false;

        });

      }

    }

  }

  // ============================================================

  // APPLY NOW

  // ============================================================

  Future<void> openApply(

    JobModel job,

  ) async {

    final url = job.applyUrl.trim();

    if (url.isEmpty) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)

          .showSnackBar(

        const SnackBar(

          content: Text(

            'Application link is not available for this job.',

          ),

        ),

      );

      return;

    }

    final uri = Uri.tryParse(url);

    if (uri == null ||

        !(uri.scheme == 'http' ||

            uri.scheme == 'https')) {

      if (!mounted) return;

      ScaffoldMessenger.of(context)

          .showSnackBar(

        const SnackBar(

          content: Text(

            'Invalid application link.',

          ),

        ),

      );

      return;

    }

    try {

      final opened = await launchUrl(

        uri,

        mode: LaunchMode.externalApplication,

      );

      if (opened) {
        if (!mounted) return;
        final submitted = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Application Status'),
            content: const Text('Did you submit the application for this job?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Not yet'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes, Applied'),
              ),
            ],
          ),
        );
        if (submitted == true) {
          await _markApplied(job);
        }
      } else if (mounted) {

        ScaffoldMessenger.of(context)

            .showSnackBar(

          const SnackBar(

            content: Text(

              'Unable to open the application link.',

            ),

          ),

        );

      }

    } catch (e) {

      debugPrint(

        'Apply URL error: $e',

      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)

          .showSnackBar(

        const SnackBar(

          content: Text(

            'Unable to open the application link.',

          ),

        ),

      );

    }

  }

  // ============================================================

  // BUILD

  // ============================================================

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:

          const Color(0xffF6F7FB),

      appBar: AppBar(

        title: const Text(

          'Jobs For You',

          style: TextStyle(

            fontWeight: FontWeight.bold,

            color: Color(0xff172033),

          ),

        ),

        backgroundColor: Colors.white,

        elevation: 0,

        iconTheme: const IconThemeData(

          color: Color(0xff172033),

        ),

        actions: [

          IconButton(

            onPressed:

                isRefreshing || isFilterLoading

                    ? null

                    : refreshJobs,

            icon: isRefreshing

                ? const SizedBox(

                    width: 20,

                    height: 20,

                    child:

                        CircularProgressIndicator(

                      strokeWidth: 2,

                      color:

                          Color(0xff667EEA),

                    ),

                  )

                : const Icon(

                    Icons.refresh_rounded,

                    color:

                        Color(0xff667EEA),

                  ),

          ),

        ],

      ),

      body: isLoading

          ? const Center(

              child:

                  CircularProgressIndicator(

                color: Color(0xff667EEA),

              ),

            )

          : RefreshIndicator(

              onRefresh: refreshJobs,

              color: const Color(0xff667EEA),

              child: ListView(

                physics:

                    const AlwaysScrollableScrollPhysics(),

                padding:

                    const EdgeInsets.fromLTRB(

                  20,

                  18,

                  20,

                  30,

                ),

                children: [

                  _profileHeader(),

                  const SizedBox(height: 16),

                  _searchBox(),

                  const SizedBox(height: 14),

                  _filters(),

                  const SizedBox(height: 20),

                  _jobsHeader(),

                  if (errorMessage != null) ...[

                    const SizedBox(height: 10),

                    _errorBox(),

                  ],

                  const SizedBox(height: 12),

                  if (isFilterLoading)

                    const Padding(

                      padding:

                          EdgeInsets.symmetric(

                        vertical: 35,

                      ),

                      child: Center(

                        child:

                            CircularProgressIndicator(

                          color:

                              Color(0xff667EEA),

                        ),

                      ),

                    )

                  else if (filteredJobs.isEmpty)

                    _emptyState()

                  else

                    ...filteredJobs.map(

                      _jobCard,

                    ),

                ],

              ),

            ),

    );

  }

  // ============================================================

  // PROFILE HEADER

  // ============================================================

  Widget _profileHeader() {

    return Container(

      padding: const EdgeInsets.all(22),

      decoration: BoxDecoration(

        gradient:

            const LinearGradient(

          colors: [

            Color(0xff667EEA),

            Color(0xff764BA2),

          ],

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

        ),

        borderRadius:

            BorderRadius.circular(24),

      ),

      child: Column(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          const Text(

            'Jobs matched for you',

            style: TextStyle(

              color: Colors.white,

              fontSize: 22,

              fontWeight: FontWeight.bold,

            ),

          ),

          const SizedBox(height: 8),

          const Text(

            'Live jobs based on your career goal and preferences.',

            style: TextStyle(

              color: Colors.white70,

              fontSize: 13,

              height: 1.4,

            ),

          ),

          const SizedBox(height: 16),

          if (targetRole.isNotEmpty)

            _profileChip(

              Icons.work_outline_rounded,

              targetRole,

            ),

          if (preferredLocation.isNotEmpty)

            _profileChip(

              Icons.location_on_outlined,

              preferredLocation,

            ),

          if (preferredWorkMode.isNotEmpty)

            _profileChip(

              Icons.laptop_mac_outlined,

              preferredWorkMode,

            ),

          if (preferredJobType.isNotEmpty)

            _profileChip(

              Icons.business_center_outlined,

              preferredJobType,

            ),

          if (userSkills.isNotEmpty) ...[

            const SizedBox(height: 12),

            const Text(

              'Your Skills',

              style: TextStyle(

                color: Colors.white70,

                fontSize: 12,

                fontWeight: FontWeight.w600,

              ),

            ),

            const SizedBox(height: 8),

            Wrap(

              spacing: 8,

              runSpacing: 8,

              children: userSkills

                  .take(8)

                  .map(

                    (skill) => Container(

                      padding:

                          const EdgeInsets.symmetric(

                        horizontal: 12,

                        vertical: 8,

                      ),

                      decoration:

                          BoxDecoration(

                        color:

                            Colors.white24,

                        borderRadius:

                            BorderRadius.circular(

                          20,

                        ),

                      ),

                      child: Text(

                        skill,

                        style:

                            const TextStyle(

                          color: Colors.white,

                          fontSize: 12,

                          fontWeight:

                              FontWeight.w600,

                        ),

                      ),

                    ),

                  )

                  .toList(),

            ),

          ],

        ],

      ),

    );

  }

  // ============================================================

  // PROFILE CHIP

  // ============================================================

  Widget _profileChip(

    IconData icon,

    String text,

  ) {

    return Padding(

      padding:

          const EdgeInsets.only(bottom: 8),

      child: Container(

        padding:

            const EdgeInsets.symmetric(

          horizontal: 12,

          vertical: 8,

        ),

        decoration: BoxDecoration(

          color: Colors.white.withOpacity(

            0.15,

          ),

          borderRadius:

              BorderRadius.circular(14),

        ),

        child: Row(

          mainAxisSize: MainAxisSize.min,

          children: [

            Icon(

              icon,

              color: Colors.white,

              size: 15,

            ),

            const SizedBox(width: 6),

            Text(

              text,

              style: const TextStyle(

                color: Colors.white,

                fontSize: 12,

                fontWeight: FontWeight.w600,

              ),

            ),

          ],

        ),

      ),

    );

  }

  // ============================================================

  // SEARCH BOX

  // ============================================================

  Widget _searchBox() {

    return Container(

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(18),

        border: Border.all(

          color:

              const Color(0xffE5E7EF),

        ),

      ),

      child: TextField(

        controller: searchController,

        textInputAction:

            TextInputAction.search,

        decoration: InputDecoration(

          prefixIcon: const Icon(

            Icons.search_rounded,

            size: 28,

            color: Color(0xff667EEA),

          ),

          suffixIcon:

              searchController.text.isNotEmpty

                  ? IconButton(

                      onPressed: () {

                        searchController

                            .clear();

                      },

                      icon: const Icon(

                        Icons.close_rounded,

                      ),

                    )

                  : null,

          hintText:

              'Search jobs, company, skills...',

          hintStyle:

              const TextStyle(

            color: Colors.grey,

            fontSize: 14,

          ),

          border: InputBorder.none,

          contentPadding:

              const EdgeInsets.symmetric(

            vertical: 18,

          ),

        ),

      ),

    );

  }

  // ============================================================

  // FILTERS

  // ============================================================

  Widget _filters() {

    return SizedBox(

      height: 48,

      child: ListView.separated(

        scrollDirection:

            Axis.horizontal,

        itemCount: filters.length,

        separatorBuilder: (_, __) =>

            const SizedBox(width: 10),

        itemBuilder: (_, index) {

          final filter = filters[index];

          final selected =

              filter == selectedFilter;

          return ChoiceChip(

            label: Row(

              mainAxisSize:

                  MainAxisSize.min,

              children: [

                if (filter == 'Remote')

                  const Icon(

                    Icons.wifi_rounded,

                    size: 15,

                  ),

                if (filter == 'Hybrid')

                  const Icon(

                    Icons.sync_alt_rounded,

                    size: 15,

                  ),

                if (filter == 'On-site')

                  const Icon(

                    Icons.business_rounded,

                    size: 15,

                  ),

                if (filter == 'Internship')

                  const Icon(

                    Icons.school_rounded,

                    size: 15,

                  ),

                if (filter == 'Full-time')

                  const Icon(

                    Icons.work_rounded,

                    size: 15,

                  ),

                if (filter != 'All')

                  const SizedBox(width: 5),

                Text(filter),

              ],

            ),

            selected: selected,

            onSelected: (_) {

              selectFilter(filter);

            },

            selectedColor:

                const Color(0xff667EEA),

            backgroundColor:

                Colors.white,

            labelStyle: TextStyle(

              color: selected

                  ? Colors.white

                  : const Color(

                      0xff172033,

                    ),

              fontWeight:

                  FontWeight.w600,

            ),

            side: BorderSide(

              color: selected

                  ? const Color(

                      0xff667EEA,

                    )

                  : const Color(

                      0xffD8DBE5,

                    ),

            ),

          );

        },

      ),

    );

  }

  // ============================================================

  // JOBS HEADER

  // ============================================================

  Widget _jobsHeader() {

    return Row(

      children: [

        Expanded(

          child: Text(

            selectedFilter == 'All'

                ? '${filteredJobs.length} matching jobs'

                : '${filteredJobs.length} $selectedFilter jobs',

            style: const TextStyle(

              fontSize: 20,

              fontWeight: FontWeight.bold,

              color: Color(0xff172033),

            ),

          ),

        ),

        Container(

          padding:

              const EdgeInsets.symmetric(

            horizontal: 10,

            vertical: 6,

          ),

          decoration: BoxDecoration(

            color:

                const Color(0xffEEF0FF),

            borderRadius:

                BorderRadius.circular(10),

          ),

          child: const Text(

            'LIVE',

            style: TextStyle(

              color: Color(0xff667EEA),

              fontSize: 11,

              fontWeight: FontWeight.bold,

            ),

          ),

        ),

      ],

    );

  }

  // ============================================================

  // ERROR BOX

  // ============================================================

  Widget _errorBox() {

    return Container(

      padding:

          const EdgeInsets.all(13),

      decoration: BoxDecoration(

        color:

            const Color(0xfffff4e5),

        borderRadius:

            BorderRadius.circular(14),

        border: Border.all(

          color:

              const Color(0xffffd9a3),

        ),

      ),

      child: Row(

        crossAxisAlignment:

            CrossAxisAlignment.start,

        children: [

          const Icon(

            Icons.info_outline_rounded,

            color: Color(0xffd98200),

            size: 20,

          ),

          const SizedBox(width: 8),

          Expanded(

            child: Text(

              errorMessage!,

              style: const TextStyle(

                color: Color(0xff8a5a00),

                fontSize: 12,

                height: 1.4,

              ),

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // JOB CARD

  // ============================================================

  Widget _jobCard(

    JobModel job,

  ) {

    return Container(

      margin:

          const EdgeInsets.only(

        bottom: 14,

      ),

      padding:

          const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(20),

        border: Border.all(

          color:

              const Color(0xffE5E7EF),

        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black

                .withOpacity(0.03),

            blurRadius: 10,

            offset:

                const Offset(0, 4),

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

                decoration:

                    BoxDecoration(

                  color:

                      const Color(0xffEEF0FF),

                  borderRadius:

                      BorderRadius.circular(

                    15,

                  ),

                ),

                child: const Icon(

                  Icons.work_outline_rounded,

                  color:

                      Color(0xff667EEA),

                  size: 27,

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

                        color:

                            Color(0xff172033),

                      ),

                    ),

                    const SizedBox(height: 5),

                    Text(

                      job.company,

                      maxLines: 1,

                      overflow:

                          TextOverflow.ellipsis,

                      style:

                          const TextStyle(

                        color:

                            Color(0xff667EEA),

                        fontWeight:

                            FontWeight.w600,

                      ),

                    ),

                  ],

                ),

              ),


              const SizedBox(width: 8),
              IconButton(
                tooltip: savedJobIds.contains(job.id) ? 'Remove saved job' : 'Save job',
                onPressed: () => _toggleSavedJob(job),
                icon: Icon(
                  savedJobIds.contains(job.id) ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                  color: const Color(0xff667EEA),
                ),
              ),            ],

          ),

          const SizedBox(height: 14),

          Text(

            job.description,

            maxLines: 4,

            overflow:

                TextOverflow.ellipsis,

            style: const TextStyle(

              color: Color(0xff687086),

              height: 1.4,

              fontSize: 13,

            ),

          ),

          const SizedBox(height: 12),

          Wrap(

            spacing: 8,

            runSpacing: 8,

            children: [

              _tag(

                Icons.location_on_outlined,

                job.location,

              ),

              _tag(

                Icons.laptop_mac_outlined,

                job.workMode,

              ),

              if (job.salary.isNotEmpty)

                _tag(

                  Icons.payments_outlined,

                  job.salary,

                ),

              if (job.experience.isNotEmpty)

                _tag(

                  Icons.schedule_outlined,

                  job.experience,

                ),

              if (job.jobType.isNotEmpty)

                _tag(

                  Icons.business_center_outlined,

                  job.jobType,

                ),

            ],

          ),

          if (job.skills.isNotEmpty) ...[

            const SizedBox(height: 12),

            Wrap(

              spacing: 6,

              runSpacing: 6,

              children: job.skills

                  .take(8)

                  .map(

                    (skill) => Container(

                      padding:

                          const EdgeInsets

                              .symmetric(

                        horizontal: 9,

                        vertical: 6,

                      ),

                      decoration:

                          BoxDecoration(

                        color:

                            const Color(

                          0xffF1F3FA,

                        ),

                        borderRadius:

                            BorderRadius

                                .circular(

                          10,

                        ),

                      ),

                      child: Text(

                        skill,

                        style:

                            const TextStyle(

                          fontSize: 11,

                          color:

                              Color(

                            0xff4C55A5,

                          ),

                          fontWeight:

                              FontWeight.w600,

                        ),

                      ),

                    ),

                  )

                  .toList(),

            ),

          ],

          const SizedBox(height: 15),

          Row(

            children: [

              Expanded(

                child: Column(

                  crossAxisAlignment:

                      CrossAxisAlignment.start,

                  children: [

                    Text(

                      job.posted,

                      maxLines: 1,

                      overflow:

                          TextOverflow.ellipsis,

                      style:

                          const TextStyle(

                        color: Colors.grey,

                        fontSize: 11,

                      ),

                    ),

                    const SizedBox(height: 3),

                    Text(

                      'Source: ${job.source}',

                      maxLines: 1,

                      overflow:

                          TextOverflow.ellipsis,

                      style:

                          const TextStyle(

                        color:

                            Color(0xff667EEA),

                        fontSize: 10,

                        fontWeight:

                            FontWeight.w600,

                      ),

                    ),

                  ],

                ),

              ),

              const SizedBox(width: 10),

              if (appliedJobIds.contains(job.id))
                const Icon(Icons.check_circle_rounded, color: Color(0xff219653), size: 22),
              const SizedBox(width: 8),
              ElevatedButton.icon(

                onPressed: () =>

                    openApply(job),

                icon: const Icon(

                  Icons.open_in_new_rounded,

                  size: 16,

                ),

                label: const Text(

                  'Apply Now',

                ),

                style:

                    ElevatedButton.styleFrom(

                  backgroundColor:

                      const Color(

                    0xff667EEA,

                  ),

                  foregroundColor:

                      Colors.white,

                  elevation: 0,

                  padding:

                      const EdgeInsets

                          .symmetric(

                    horizontal: 15,

                    vertical: 12,

                  ),

                  shape:

                      RoundedRectangleBorder(

                    borderRadius:

                        BorderRadius.circular(

                      12,

                    ),

                  ),

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }

  // ============================================================

  // TAG

  // ============================================================

  Widget _tag(

    IconData icon,

    String text,

  ) {

    return Container(

      constraints:

          const BoxConstraints(

        maxWidth: 250,

      ),

      padding:

          const EdgeInsets.symmetric(

        horizontal: 9,

        vertical: 7,

      ),

      decoration: BoxDecoration(

        color:

            const Color(0xffF7F8FC),

        borderRadius:

            BorderRadius.circular(10),

      ),

      child: Row(

        mainAxisSize:

            MainAxisSize.min,

        children: [

          Icon(

            icon,

            size: 14,

            color: Colors.grey,

          ),

          const SizedBox(width: 4),

          Flexible(

            child: Text(

              text,

              maxLines: 1,

              overflow:

                  TextOverflow.ellipsis,

              style:

                  const TextStyle(

                fontSize: 11,

                color:

                    Color(0xff596174),

              ),

            ),

          ),

        ],

      ),

    );

  }

  // ============================================================

  // EMPTY STATE

  // ============================================================

  Widget _emptyState() {

    return Container(

      padding:

          const EdgeInsets.all(30),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(22),

        border: Border.all(

          color:

              const Color(0xffE5E7EF),

        ),

      ),

      child: Column(

        children: [

          const Icon(

            Icons.work_off_rounded,

            size: 60,

            color: Color(0xff667EEA),

          ),

          const SizedBox(height: 14),

          Text(

            selectedFilter == 'All'

                ? 'No live jobs found'

                : 'No $selectedFilter jobs found',

            textAlign:

                TextAlign.center,

            style:

                const TextStyle(

              fontSize: 19,

              fontWeight:

                  FontWeight.bold,

              color:

                  Color(0xff172033),

            ),

          ),

          const SizedBox(height: 7),

          Text(

            selectedFilter == 'All'

                ? 'Try refreshing the jobs or change your career preferences.'

                : 'Try another filter or refresh the jobs.',

            textAlign:

                TextAlign.center,

            style:

                const TextStyle(

              color: Colors.grey,

              height: 1.4,

            ),

          ),

          const SizedBox(height: 16),

          Row(

            mainAxisAlignment:

                MainAxisAlignment.center,

            children: [

              OutlinedButton(

                onPressed: () {

                  setState(() {

                    selectedFilter =

                        'All';

                    searchController

                        .clear();

                  });

                  _fetchJobs(

                    filter: 'All',

                    showFullLoader: true,

                  );

                },

                child:

                    const Text(

                  'All Jobs',

                ),

              ),

              const SizedBox(width: 10),

              ElevatedButton(

                onPressed:

                    refreshJobs,

                style:

                    ElevatedButton.styleFrom(

                  backgroundColor:

                      const Color(

                    0xff667EEA,

                  ),

                  foregroundColor:

                      Colors.white,

                ),

                child:

                    const Text(

                  'Refresh',

                ),

              ),

            ],

          ),

        ],

      ),

    );

  }

}