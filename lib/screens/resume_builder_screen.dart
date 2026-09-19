import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ResumeBuilderScreen extends StatefulWidget {
  const ResumeBuilderScreen({super.key});

  @override
  State<ResumeBuilderScreen> createState() => _ResumeBuilderScreenState();
}

class _ResumeBuilderScreenState extends State<ResumeBuilderScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final locationController = TextEditingController();
  final linkedinController = TextEditingController();
  final githubController = TextEditingController();

  final objectiveController = TextEditingController();
  final educationController = TextEditingController();
  final skillsController = TextEditingController();
  final experienceController = TextEditingController();
  final projectsController = TextEditingController();
  final certificationsController = TextEditingController();
  final achievementsController = TextEditingController();

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadResume();
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    locationController.dispose();
    linkedinController.dispose();
    githubController.dispose();
    objectiveController.dispose();
    educationController.dispose();
    skillsController.dispose();
    experienceController.dispose();
    projectsController.dispose();
    certificationsController.dispose();
    achievementsController.dispose();
    super.dispose();
  }

  Future<void> loadResume() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data();

      if (data == null) return;

      final resume = data['resume'];

      if (resume is Map) {
        nameController.text = resume['name']?.toString() ?? '';
        emailController.text = resume['email']?.toString() ?? '';
        phoneController.text = resume['phone']?.toString() ?? '';
        locationController.text = resume['location']?.toString() ?? '';
        linkedinController.text = resume['linkedin']?.toString() ?? '';
        githubController.text = resume['github']?.toString() ?? '';

        objectiveController.text = resume['objective']?.toString() ?? '';
        educationController.text = resume['education']?.toString() ?? '';
        skillsController.text = resume['skills']?.toString() ?? '';
        experienceController.text = resume['experience']?.toString() ?? '';
        projectsController.text = resume['projects']?.toString() ?? '';
        certificationsController.text =
            resume['certifications']?.toString() ?? '';
        achievementsController.text =
            resume['achievements']?.toString() ?? '';
      }
    } catch (e) {
      debugPrint('Resume load error: $e');
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> saveResume() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login first'),
        ),
      );
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'resume': {
            'name': nameController.text.trim(),
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'location': locationController.text.trim(),
            'linkedin': linkedinController.text.trim(),
            'github': githubController.text.trim(),
            'objective': objectiveController.text.trim(),
            'education': educationController.text.trim(),
            'skills': skillsController.text.trim(),
            'experience': experienceController.text.trim(),
            'projects': projectsController.text.trim(),
            'certifications': certificationsController.text.trim(),
            'achievements': achievementsController.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
        },
        SetOptions(merge: true),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resume saved successfully!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save resume: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> generatePDF() async {
    if (!_formKey.currentState!.validate()) return;

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(32),
        build: (context) {
          return [
            pw.Center(
              child: pw.Text(
                nameController.text.trim().isEmpty
                    ? 'Your Name'
                    : nameController.text.trim(),
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 8),

            pw.Center(
              child: pw.Text(
                [
                  emailController.text.trim(),
                  phoneController.text.trim(),
                  locationController.text.trim(),
                ].where((e) => e.isNotEmpty).join(' | '),
                style: const pw.TextStyle(fontSize: 9),
              ),
            ),

            pw.SizedBox(height: 6),

            if (linkedinController.text.trim().isNotEmpty ||
                githubController.text.trim().isNotEmpty)
              pw.Center(
                child: pw.Text(
                  [
                    linkedinController.text.trim(),
                    githubController.text.trim(),
                  ].where((e) => e.isNotEmpty).join(' | '),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ),

            pw.SizedBox(height: 20),

            _pdfSection(
              'PROFESSIONAL SUMMARY',
              objectiveController.text,
            ),

            _pdfSection(
              'EDUCATION',
              educationController.text,
            ),

            _pdfSection(
              'SKILLS',
              skillsController.text,
            ),

            _pdfSection(
              'EXPERIENCE',
              experienceController.text,
            ),

            _pdfSection(
              'PROJECTS',
              projectsController.text,
            ),

            _pdfSection(
              'CERTIFICATIONS',
              certificationsController.text,
            ),

            _pdfSection(
              'ACHIEVEMENTS',
              achievementsController.text,
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
    );
  }

  pw.Widget _pdfSection(String title, String content) {
    if (content.trim().isEmpty) {
      return pw.SizedBox();
    }

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 14),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 5),
          pw.Text(
            content.trim(),
            style: const pw.TextStyle(
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget sectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(
        top: 22,
        bottom: 12,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: const Color(0xFF4F46E5),
            size: 22,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget inputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        validator: label == 'Full Name'
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              }
            : null,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          alignLabelWithHint: maxLines > 1,
          filled: true,
          fillColor: Colors.grey.shade50,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF4F46E5),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        title: const Text(
          'Resume Builder',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Preview & PDF',
            onPressed: generatePDF,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF4F46E5),
                    Color(0xFF7C3AED),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Build Your Professional Resume',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Create, save and generate your resume in a professional format.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            sectionTitle(
              'Personal Information',
              Icons.person_outline,
            ),

            inputField(
              label: 'Full Name',
              controller: nameController,
              hint: 'e.g. Harsh Poriya',
            ),

            inputField(
              label: 'Email',
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              hint: 'your@email.com',
            ),

            inputField(
              label: 'Phone',
              controller: phoneController,
              keyboardType: TextInputType.phone,
              hint: '+91 XXXXX XXXXX',
            ),

            inputField(
              label: 'Location',
              controller: locationController,
              hint: 'Ahmedabad, Gujarat',
            ),

            inputField(
              label: 'LinkedIn',
              controller: linkedinController,
              hint: 'LinkedIn profile URL',
            ),

            inputField(
              label: 'GitHub',
              controller: githubController,
              hint: 'GitHub profile URL',
            ),

            sectionTitle(
              'Professional Summary',
              Icons.work_outline,
            ),

            inputField(
              label: 'Career Objective',
              controller: objectiveController,
              hint: 'Write a short professional summary...',
              maxLines: 5,
            ),

            sectionTitle(
              'Education',
              Icons.school_outlined,
            ),

            inputField(
              label: 'Education',
              controller: educationController,
              hint:
                  'MCA - LJ University\nBCA - College Name',
              maxLines: 5,
            ),

            sectionTitle(
              'Skills',
              Icons.code,
            ),

            inputField(
              label: 'Skills',
              controller: skillsController,
              hint:
                  'Flutter, Dart, Firebase, Python, JavaScript...',
              maxLines: 4,
            ),

            sectionTitle(
              'Experience',
              Icons.business_center_outlined,
            ),

            inputField(
              label: 'Experience',
              controller: experienceController,
              hint:
                  'Company / Role / Duration / Responsibilities',
              maxLines: 6,
            ),

            sectionTitle(
              'Projects',
              Icons.rocket_launch_outlined,
            ),

            inputField(
              label: 'Projects',
              controller: projectsController,
              hint:
                  'Project name\nTechnologies\nDescription\nAchievements',
              maxLines: 7,
            ),

            sectionTitle(
              'Certifications',
              Icons.verified_outlined,
            ),

            inputField(
              label: 'Certifications',
              controller: certificationsController,
              hint:
                  'Certification name - Organization - Year',
              maxLines: 5,
            ),

            sectionTitle(
              'Achievements',
              Icons.emoji_events_outlined,
            ),

            inputField(
              label: 'Achievements',
              controller: achievementsController,
              hint:
                  'Hackathons, awards, competitions, achievements...',
              maxLines: 5,
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSaving ? null : saveResume,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Resume'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: generatePDF,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Generate PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(54),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}