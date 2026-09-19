import 'package:flutter/material.dart';

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'ai_chat_screen.dart';

import 'discover_career_screen.dart';

import 'jobs_screen.dart';

import 'skill_learning_screen.dart'; 

class DashboardScreen extends StatefulWidget {

  const DashboardScreen({super.key});

  @override

  State<DashboardScreen> createState() => _DashboardScreenState();

}

class _DashboardScreenState extends State<DashboardScreen> {

  int selectedIndex = 0;

  bool isLoading = true;

  String name = "User";

  String targetRole = "Career Goal";

  int careerMatch = 0;

  List<String> recommendedRoles = [];

  List<String> recommendedSkills = [];

  List<String> strengths = [];

  List<String> improvements = [];

  @override

  void initState() {

    super.initState();

    loadDashboard();

  }

  // =========================================================***

  // LOAD DASHBOARD DATA***

  // =========================================================***

  Future<void> loadDashboard() async {

    try {

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {

        if (!mounted) return;

        setState(() {

          isLoading = false;

        });

        return;

      }

      final doc = await FirebaseFirestore.instance

          .collection('users')

          .doc(user.uid)

          .get();

      if (!doc.exists) {

        if (!mounted) return;

        setState(() {

          isLoading = false;

        });

        return;

      }

      final data = doc.data() ?? {};

      final analysis =

          data['careerAnalysis'] as Map<String, dynamic>? ?? {};

      if (!mounted) return;

      setState(() {

        name = data['name']?.toString().isNotEmpty == true

            ? data['name'].toString()

            : "User";

        targetRole =

            data['targetRole']?.toString().isNotEmpty == true

                ? data['targetRole'].toString()

                : "Career Goal";

        careerMatch =

            int.tryParse(

              analysis['careerMatch']?.toString() ?? '0',

            ) ??

            0;

        recommendedRoles = List<String>.from(

          analysis['recommendedRoles'] ?? [],

        );

        recommendedSkills = List<String>.from(

          analysis['recommendedSkills'] ?? [],

        );

        strengths = List<String>.from(

          analysis['strengths'] ?? [],

        );

        improvements = List<String>.from(

          analysis['improvements'] ?? [],

        );

        isLoading = false;

      });

    } catch (e) {

      debugPrint("Dashboard Error: $e");

      if (!mounted) return;

      setState(() {

        isLoading = false;

      });

    }

  }

  // =========================================================***

  // LOGOUT***

  // =========================================================***

  Future<void> logoutUser() async {

    final shouldLogout = await showDialog<bool>(

      context: context,

      builder: (context) {

        return AlertDialog(

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(20),

          ),

          title: const Text(

            'Logout',

            style: TextStyle(

              fontWeight: FontWeight.bold,

              color: Color(0xff172033),

            ),

          ),

          content: const Text(

            'Are you sure you want to logout?',

            style: TextStyle(

              color: Colors.grey,

              fontSize: 15,

            ),

          ),

          actionsPadding: const EdgeInsets.fromLTRB(

            16,

            0,

            16,

            16,

          ),

          actions: [

            TextButton(

              onPressed: () {

                Navigator.pop(context, false);

              },

              child: const Text(

                'Cancel',

                style: TextStyle(

                  color: Color(0xff667EEA),

                  fontWeight: FontWeight.w600,

                ),

              ),

            ),

            ElevatedButton(

              onPressed: () {

                Navigator.pop(context, true);

              },

              style: ElevatedButton.styleFrom(

                backgroundColor: const Color(0xff667EEA),

                foregroundColor: Colors.white,

                elevation: 0,

                shape: RoundedRectangleBorder(

                  borderRadius: BorderRadius.circular(12),

                ),

              ),

              child: const Text(

                'Logout',

                style: TextStyle(

                  fontWeight: FontWeight.w600,

                ),

              ),

            ),

          ],

        );

      },

    );

    if (shouldLogout != true) return;

    try {

      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(

        context,

        MaterialPageRoute(

          builder: (context) => const DiscoverCareerScreen(),

        ),

        (route) => false,

      );

    } catch (e) {

      debugPrint("Logout Error: $e");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text(

            'Logout failed. Please try again.',

          ),

        ),

      );

    }

  }

  // =========================================================***

  // BUILD***

  // =========================================================***

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xffF6F7FB),

      body: SafeArea(

        child: isLoading

            ? const Center(

                child: CircularProgressIndicator(

                  color: Color(0xff667EEA),

                ),

              )

            : RefreshIndicator(

                onRefresh: loadDashboard,

                child: SingleChildScrollView(

                  physics:

                      const AlwaysScrollableScrollPhysics(),

                  padding: const EdgeInsets.fromLTRB(

                    20,

                    20,

                    20,

                    100,

                  ),

                  child: Column(

                    crossAxisAlignment:

                        CrossAxisAlignment.start,

                    children: [

                      // =================================================***

                      // HEADER***

                      // =================================================***

                      Row(

                        children: [

                          Expanded(

                            child: Column(

                              crossAxisAlignment:

                                  CrossAxisAlignment.start,

                              children: [

                                Text(

                                  "Hello, $name 👋",

                                  style: const TextStyle(

                                    fontSize: 26,

                                    fontWeight:

                                        FontWeight.bold,

                                    color:

                                        Color(0xff172033),

                                  ),

                                ),

                                const SizedBox(height: 5),

                                const Text(

                                  "Let's build your career 🚀",

                                  style: TextStyle(

                                    fontSize: 14,

                                    color: Colors.grey,

                                  ),

                                ),

                              ],

                            ),

                          ),

                          // =================================================***

                          // LOGOUT BUTTON***

                          // =================================================***

                          GestureDetector(

                            onTap: logoutUser,

                            child: Container(

                              width: 48,

                              height: 48,

                              decoration: BoxDecoration(

                                gradient:

                                    const LinearGradient(

                                  colors: [

                                    Color(0xff667EEA),

                                    Color(0xff764BA2),

                                  ],

                                ),

                                borderRadius:

                                    BorderRadius.circular(

                                  16,

                                ),

                                boxShadow: [

                                  BoxShadow(

                                    color: const Color(

                                      0xff667EEA,

                                    ).withOpacity(0.20),

                                    blurRadius: 10,

                                    offset:

                                        const Offset(0, 4),

                                  ),

                                ],

                              ),

                              child: const Icon(

                                Icons.logout_rounded,

                                color: Colors.white,

                                size: 22,

                              ),

                            ),

                          ),

                        ],

                      ),

                      const SizedBox(height: 25),

                      // =================================================***

                      // CAREER MATCH CARD***

                      // =================================================***

                      Container(

                        width: double.infinity,

                        padding: const EdgeInsets.all(22),

                        decoration: BoxDecoration(

                          gradient:

                              const LinearGradient(

                            colors: [

                              Color(0xff667EEA),

                              Color(0xff764BA2),

                            ],

                          ),

                          borderRadius:

                              BorderRadius.circular(24),

                          boxShadow: [

                            BoxShadow(

                              color: Colors.deepPurple

                                  .withOpacity(0.18),

                              blurRadius: 18,

                              offset:

                                  const Offset(0, 8),

                            ),

                          ],

                        ),

                        child: Row(

                          children: [

                            // MATCH CIRCLE***

                            SizedBox(

                              width: 90,

                              height: 90,

                              child: Stack(

                                alignment:

                                    Alignment.center,

                                children: [

                                  SizedBox(

                                    width: 90,

                                    height: 90,

                                    child:

                                        CircularProgressIndicator(

                                      value:

                                          careerMatch / 100,

                                      strokeWidth: 8,

                                      backgroundColor:

                                          Colors.white24,

                                      valueColor:

                                          const AlwaysStoppedAnimation<

                                              Color>(

                                        Colors.white,

                                      ),

                                    ),

                                  ),

                                  Text(

                                    "$careerMatch%",

                                    style:

                                        const TextStyle(

                                      color: Colors.white,

                                      fontSize: 20,

                                      fontWeight:

                                          FontWeight.bold,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                            const SizedBox(width: 20),

                            Expanded(

                              child: Column(

                                crossAxisAlignment:

                                    CrossAxisAlignment.start,

                                children: [

                                  const Text(

                                    "Career Match",

                                    style: TextStyle(

                                      color:

                                          Colors.white70,

                                      fontSize: 14,

                                    ),

                                  ),

                                  const SizedBox(height: 5),

                                  Text(

                                    targetRole,

                                    maxLines: 2,

                                    overflow:

                                        TextOverflow.ellipsis,

                                    style:

                                        const TextStyle(

                                      color: Colors.white,

                                      fontSize: 20,

                                      fontWeight:

                                          FontWeight.bold,

                                    ),

                                  ),

                                  const SizedBox(height: 5),

                                  const Text(

                                    "Based on your profile",

                                    style: TextStyle(

                                      color:

                                          Colors.white70,

                                      fontSize: 12,

                                    ),

                                  ),

                                ],

                              ),

                            ),

                          ],

                        ),

                      ),

                      const SizedBox(height: 28),

                      // =================================================***

                      // RECOMMENDED ROLES***

                      // =================================================***

                      _sectionTitle(

                        "Recommended Roles",

                        "Best roles for you",

                      ),

                      const SizedBox(height: 12),

                      if (recommendedRoles.isEmpty)

                        _emptyCard(

                          "No recommended roles available yet.",

                        )

                      else

                        SizedBox(

                          height: 105,

                          child: ListView.builder(

                            scrollDirection:

                                Axis.horizontal,

                            itemCount:

                                recommendedRoles.length,

                            itemBuilder:

                                (context, index) {

                              return _roleCard(

                                recommendedRoles[index],

                              );

                            },

                          ),

                        ),

                      const SizedBox(height: 28),

                      // =================================================***

                      // AI CAREER MENTOR***

                      // =================================================***

                      _aiMentorCard(),

                      const SizedBox(height: 16),

                      _resumeBuilderCard(),

                      const SizedBox(height: 28),

                      // =================================================***

                      // SKILLS***

                      // =================================================***

                      _sectionTitle(

                        "Skills to Learn",

                        "Improve your career match",

                      ),

                      const SizedBox(height: 12),

                      if (recommendedSkills.isEmpty)

                        _emptyCard(

                          "No skill recommendations yet.",

                        )

                      else

                        Column(


                          children: recommendedSkills


                              .take(8)


                              .map(


                                (skill) => Padding(


                                  padding: const EdgeInsets.only(bottom: 10),


                                  child: _skillChip(skill),


                                ),


                              )


                              .toList(),


                        ),

                      const SizedBox(height: 28),

                      // =================================================***

                      // LEARNING***

                      // =================================================***

                      _sectionTitle(

                        "Learning",

                        "Upgrade your skills",

                      ),

                      const SizedBox(height: 12),

                      _learningCard(

                        icon:

                            Icons.play_circle_fill,

                        title:

                            "Learn AI & Machine Learning",

                        subtitle:

                            "Video lessons • Projects • Practice",

                        onTap: () {},

                      ),

                      const SizedBox(height: 12),

                      _learningCard(

                        icon: Icons.code,

                        title:

                            "Improve Programming Skills",

                        subtitle:

                            "Python • Flutter • JavaScript",

                        onTap: () {},

                      ),

                      const SizedBox(height: 28),

                      // =================================================***

                      // ROADMAP***

                      // =================================================***

                      _sectionTitle(

                        "Your Career Roadmap",

                        "Your journey to your dream job",

                      ),

                      const SizedBox(height: 12),

                      _roadmapCard(),

                      const SizedBox(height: 28),

                      // =================================================***

                      // STRENGTHS***

                      // =================================================***

                      if (strengths.isNotEmpty) ...[

                        _sectionTitle(

                          "Your Strengths",

                          "What you are already good at",

                        ),

                        const SizedBox(height: 12),

                        ...strengths.take(3).map(

                              (item) => _infoCard(

                                Icons.check_circle,

                                item,

                              ),

                            ),

                        const SizedBox(height: 20),

                      ],

                      // =================================================***

                      // IMPROVEMENTS***

                      // =================================================***

                      if (improvements.isNotEmpty) ...[

                        _sectionTitle(

                          "Areas to Improve",

                          "Focus on these areas",

                        ),

                        const SizedBox(height: 12),

                        ...improvements.take(3).map(

                              (item) => _infoCard(

                                Icons.trending_up,

                                item,

                              ),

                            ),

                      ],

                    ],

                  ),

                ),

              ),

      ),

      // =========================================================***

      // BOTTOM NAVIGATION***

      // =========================================================***

      bottomNavigationBar: _bottomNavigation(),

    );

  }

  // =========================================================***

  // SECTION TITLE***

  // =========================================================***

  Widget _resumeBuilderCard() {

    return InkWell(

      onTap: () {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text('Resume Builder is Coming Soon 🚀'),

            behavior: SnackBarBehavior.floating,

          ),

        );

      },

      borderRadius: BorderRadius.circular(20),

      child: Container(

        width: double.infinity,

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: const Color(0xffE8E9F0)),

        ),

        child: Row(

          children: [

            Container(

              width: 55,

              height: 55,

              decoration: BoxDecoration(

                color: const Color(0xffEEF0FF),

                borderRadius: BorderRadius.circular(16),

              ),

              child: const Icon(

                Icons.description_outlined,

                color: Color(0xff667EEA),

                size: 28,

              ),

            ),

            const SizedBox(width: 15),

            const Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Row(

                    children: [

                      Flexible(

                        child: Text(

                          'Resume Builder',

                          overflow: TextOverflow.ellipsis,

                          style: TextStyle(

                            fontSize: 16,

                            fontWeight: FontWeight.bold,

                            color: Color(0xff172033),

                          ),

                        ),

                      ),

                      SizedBox(width: 8),

                      Text(

                        'Coming Soon',

                        style: TextStyle(

                          fontSize: 10,

                          fontWeight: FontWeight.bold,

                          color: Color(0xff667EEA),

                        ),

                      ),

                    ],

                  ),

                  SizedBox(height: 5),

                  Text(

                    'Create a professional resume with AI',

                    style: TextStyle(fontSize: 12, color: Colors.grey),

                  ),

                ],

              ),

            ),

            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),

          ],

        ),

      ),

    );

  }

  Widget _sectionTitle(

    String title,

    String subtitle,

  ) {

    return Row(

      children: [

        Expanded(

          child: Column(

            crossAxisAlignment:

                CrossAxisAlignment.start,

            children: [

              Text(

                title,

                style: const TextStyle(

                  fontSize: 19,

                  fontWeight: FontWeight.bold,

                  color: Color(0xff172033),

                ),

              ),

              const SizedBox(height: 3),

              Text(

                subtitle,

                style: const TextStyle(

                  fontSize: 12,

                  color: Colors.grey,

                ),

              ),

            ],

          ),

        ),

        const Icon(

          Icons.arrow_forward_ios,

          size: 14,

          color: Colors.grey,

        ),

      ],

    );

  }

  // =========================================================***

  // ROLE CARD***

  // =========================================================***

  Widget _roleCard(String role) {

    return Container(

      width: 190,

      margin:

          const EdgeInsets.only(right: 12),

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(18),

        border: Border.all(

          color: const Color(0xffE7E8F0),

        ),

      ),

      child: Row(

        children: [

          Container(

            width: 45,

            height: 45,

            decoration: BoxDecoration(

              color:

                  const Color(0xffEEF0FF),

              borderRadius:

                  BorderRadius.circular(14),

            ),

            child: const Icon(

              Icons.work_outline,

              color: Color(0xff667EEA),

            ),

          ),

          const SizedBox(width: 10),

          Expanded(

            child: Text(

              role,

              maxLines: 2,

              overflow:

                  TextOverflow.ellipsis,

              style: const TextStyle(

                fontSize: 14,

                fontWeight:

                    FontWeight.w600,

              ),

            ),

          ),

        ],

      ),

    );

  }

  // =========================================================***

  // AI MENTOR CARD***

  // =========================================================***

  Widget _aiMentorCard() {

    return InkWell(

      onTap: () {

        Navigator.push(

          context,

          MaterialPageRoute(

            builder: (context) =>

                const AIChatScreen(),

          ),

        );

      },

      borderRadius:

          BorderRadius.circular(22),

      child: Container(

        width: double.infinity,

        padding: const EdgeInsets.all(20),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius:

              BorderRadius.circular(22),

          boxShadow: [

            BoxShadow(

              color:

                  Colors.black.withOpacity(0.04),

              blurRadius: 15,

              offset:

                  const Offset(0, 5),

            ),

          ],

        ),

        child: Row(

          children: [

            Container(

              width: 55,

              height: 55,

              decoration: BoxDecoration(

                gradient:

                    const LinearGradient(

                  colors: [

                    Color(0xff667EEA),

                    Color(0xff764BA2),

                  ],

                ),

                borderRadius:

                    BorderRadius.circular(18),

              ),

              child: const Icon(

                Icons.smart_toy_outlined,

                color: Colors.white,

                size: 28,

              ),

            ),

            const SizedBox(width: 15),

            const Expanded(

              child: Column(

                crossAxisAlignment:

                    CrossAxisAlignment.start,

                children: [

                  Text(

                    "Ask AI Career Mentor",

                    style: TextStyle(

                      fontSize: 16,

                      fontWeight:

                          FontWeight.bold,

                    ),

                  ),

                  SizedBox(height: 5),

                  Text(

                    "Get personalized career guidance anytime.",

                    style: TextStyle(

                      fontSize: 12,

                      color: Colors.grey,

                    ),

                  ),

                ],

              ),

            ),

            const Icon(

              Icons.arrow_forward_ios,

              size: 17,

              color: Colors.grey,

            ),

          ],

        ),

      ),

    );

  }

  // =========================================================***

  // LEARNING CARD***

  // =========================================================***

  Widget _learningCard({

    required IconData icon,

    required String title,

    required String subtitle,

    required VoidCallback onTap,

  }) {

    return InkWell(

      onTap: onTap,

      borderRadius:

          BorderRadius.circular(20),

      child: Container(

        padding: const EdgeInsets.all(16),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius:

              BorderRadius.circular(20),

          border: Border.all(

            color: const Color(0xffE8E9F0),

          ),

        ),

        child: Row(

          children: [

            Container(

              width: 55,

              height: 55,

              decoration: BoxDecoration(

                color:

                    const Color(0xffEEF0FF),

                borderRadius:

                    BorderRadius.circular(17),

              ),

              child: Icon(

                icon,

                color:

                    const Color(0xff667EEA),

                size: 28,

              ),

            ),

            const SizedBox(width: 15),

            Expanded(

              child: Column(

                crossAxisAlignment:

                    CrossAxisAlignment.start,

                children: [

                  Text(

                    title,

                    style: const TextStyle(

                      fontSize: 15,

                      fontWeight:

                          FontWeight.bold,

                    ),

                  ),

                  const SizedBox(height: 5),

                  Text(

                    subtitle,

                    style: const TextStyle(

                      fontSize: 12,

                      color: Colors.grey,

                    ),

                  ),

                ],

              ),

            ),

            const Icon(

              Icons.arrow_forward_ios,

              size: 16,

              color: Colors.grey,

            ),

          ],

        ),

      ),

    );

  }

  // =========================================================***

  // ROADMAP***

  // =========================================================***

  Widget _roadmapCard() {

    return Container(

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(20),

      ),

      child: Column(

        children: [

          _roadmapStep(

            1,

            "Build Core Skills",

            "Learn required technologies",

            true,

          ),

          _roadmapStep(

            2,

            "Build Projects",

            "Create real-world projects",

            false,

          ),

          _roadmapStep(

            3,

            "Prepare for Interviews",

            "Practice technical interviews",

            false,

          ),

          _roadmapStep(

            4,

            "Get Your Dream Job",

            "Apply and crack interviews",

            false,

          ),

        ],

      ),

    );

  }

  Widget _roadmapStep(

    int number,

    String title,

    String subtitle,

    bool completed,

  ) {

    return Padding(

      padding:

          const EdgeInsets.only(bottom: 18),

      child: Row(

        children: [

          Container(

            width: 38,

            height: 38,

            decoration: BoxDecoration(

              color: completed

                  ? const Color(0xff667EEA)

                  : const Color(0xffEEF0FF),

              shape: BoxShape.circle,

            ),

            child: Center(

              child: completed

                  ? const Icon(

                      Icons.check,

                      color: Colors.white,

                      size: 20,

                    )

                  : Text(

                      "$number",

                      style:

                          const TextStyle(

                        color:

                            Color(0xff667EEA),

                        fontWeight:

                            FontWeight.bold,

                      ),

                    ),

            ),

          ),

          const SizedBox(width: 14),

          Expanded(

            child: Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [

                Text(

                  title,

                  style: const TextStyle(

                    fontWeight:

                        FontWeight.bold,

                    fontSize: 14,

                  ),

                ),

                const SizedBox(height: 3),

                Text(

                  subtitle,

                  style: const TextStyle(

                    fontSize: 12,

                    color: Colors.grey,

                  ),

                ),

              ],

            ),

          ),

        ],

      ),

    );

  }

  // =========================================================***

  // SKILL CHIP***

  // =========================================================***

  Widget _skillChip(String skill) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => SkillLearningScreen(
              skill: skill,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xffE1E3ED),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.school_outlined,
              size: 16,
              color: Color(0xff667EEA),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                skill,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff4C55A5),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 11,
              color: Color(0xff667EEA),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(

    IconData icon,

    String text,

  ) {

    return Container(

      width: double.infinity,

      margin:

          const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(14),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(15),

      ),

      child: Row(

        children: [

          Icon(

            icon,

            color:

                const Color(0xff667EEA),

            size: 20,

          ),

          const SizedBox(width: 12),

          Expanded(

            child: Text(

              text,

              style: const TextStyle(

                fontSize: 13,

              ),

            ),

          ),

        ],

      ),

    );

  }

  // =========================================================***

  // EMPTY CARD***

  // =========================================================***

  Widget _emptyCard(String text) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:

            BorderRadius.circular(18),

      ),

      child: Text(

        text,

        style: const TextStyle(

          color: Colors.grey,

        ),

      ),

    );

  }

  // =========================================================***

  // BOTTOM NAVIGATION***

  // =========================================================***

  Widget _bottomNavigation() {

    return BottomNavigationBar(

      currentIndex: selectedIndex,

      type: BottomNavigationBarType.fixed,

      selectedItemColor:

          const Color(0xff667EEA),

      unselectedItemColor:

          Colors.grey,

      onTap: (index) {

  if (index == 1) {

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (context) => const JobsScreen(),

      ),

    );

    return;

  }

  setState(() {

    selectedIndex = index;

  });

},

      items: const [

        BottomNavigationBarItem(

          icon:

              Icon(Icons.home_outlined),

          activeIcon:

              Icon(Icons.home),

          label: "Home",

        ),

        BottomNavigationBarItem(

          icon:

              Icon(Icons.work_outline),

          activeIcon:

              Icon(Icons.work),

          label: "Jobs",

        ),

        BottomNavigationBarItem(

          icon:

              Icon(Icons.map_outlined),

          activeIcon:

              Icon(Icons.map),

          label: "Roadmap",

        ),

        BottomNavigationBarItem(

          icon:

              Icon(Icons.person_outline),

          activeIcon:

              Icon(Icons.person),

          label: "Profile",

        ),

      ],

    );

  }

}