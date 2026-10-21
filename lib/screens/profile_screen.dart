
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';

import 'login_screen.dart';
import 'resume_builder_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color primary = Color(0xFF667EEA);
  static const Color secondary = Color(0xFF764BA2);
  static const Color dark = Color(0xFF172033);
  static const Color bg = Color(0xFFF6F7FB);

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool isLoading = true;
  bool isSaving = false;
  bool isUploadingPhoto = false;
  bool isUploadingResume = false;
  bool notificationsEnabled = true;
  bool dailyReminder = true;
  bool willingToRelocate = false;

  String name = '';
  String email = '';
  String phone = '';
  String city = '';
  String gender = '';
  String bio = '';

  String education = '';
  String degree = '';
  String graduationYear = '';

  String targetRole = '';
  String experienceLevel = '';

  String preferredLocation = '';
  String workMode = '';
  String expectedSalary = '';
  String jobType = '';
  String companyType = '';

  String? profilePhotoUrl;
  String? resumeUrl;
  String? resumeName;

  List<String> skills = [];

  int savedJobs = 0;
  int appliedJobs = 0;
  int learningCourses = 0;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final cityController = TextEditingController();
  final bioController = TextEditingController();
  final educationController = TextEditingController();
  final degreeController = TextEditingController();
  final yearController = TextEditingController();
  final targetRoleController = TextEditingController();
  final experienceController = TextEditingController();
  final locationController = TextEditingController();
  final salaryController = TextEditingController();
  final jobTypeController = TextEditingController();
  final companyTypeController = TextEditingController();

  User? get currentUser => _auth.currentUser;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _initializeNotifications();
    await _loadProfile();

    if (!mounted) return;

    await _scheduleDailyReminder();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    cityController.dispose();
    bioController.dispose();
    educationController.dispose();
    degreeController.dispose();
    yearController.dispose();
    targetRoleController.dispose();
    experienceController.dispose();
    locationController.dispose();
    salaryController.dispose();
    jobTypeController.dispose();
    companyTypeController.dispose();
    super.dispose();
  }

  // NOTIFICATIONS

  Future<void> _initializeNotifications() async {
    try {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const settings = InitializationSettings(
        android: androidSettings,
      );

      await _notifications.initialize(settings: settings);

      final androidPlugin = _notifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'daily_study_reminders',
          'Daily Study Reminders',
          description: 'Reminders to continue your study plan',
          importance: Importance.high,
        ),
      );

      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Notification initialization error: $e');
    }
  }

  Future<void> _scheduleDailyReminder() async {
    try {
      if (!notificationsEnabled || !dailyReminder) {
        await _notifications.cancel(id: 100);
        return;
      }

      const details = NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_study_reminders',
          'Daily Study Reminders',
          channelDescription: 'Reminders to continue your study plan',
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

      await _notifications.periodicallyShow(
        id: 100,
        title: 'CareerPilot AI 📚',
        body: 'Time to work on your placement preparation!',
        repeatInterval: RepeatInterval.daily,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      debugPrint('Daily reminder scheduling error: $e');
      if (mounted) {
        _message('Unable to schedule reminder', error: true);
      }
    }
  }

  Future<void> _saveNotificationSettings() async {
    final user = currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).set({
        'profileSettings': {
          'notifications': {
            'enabled': notificationsEnabled,
            'dailyReminder': dailyReminder,
          },
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _scheduleDailyReminder();

      if (mounted) {
        _message('Notification settings saved');
      }
    } catch (e) {
      debugPrint('Notification settings error: $e');
      if (mounted) {
        _message('Unable to save notification settings', error: true);
      }
    }
  }

  // LOAD PROFILE

  Future<void> _loadProfile() async {
    try {
      final user = currentUser;

      if (user == null) {
        if (mounted) setState(() => isLoading = false);
        return;
      }

      final snapshot =
          await _firestore.collection('users').doc(user.uid).get();

      final data = snapshot.data() ?? <String, dynamic>{};

      name = (data['name'] ?? user.displayName ?? '').toString();
      email = (data['email'] ?? user.email ?? '').toString();
      phone = (data['phone'] ?? '').toString();
      city = (data['city'] ?? '').toString();
      gender = (data['gender'] ?? '').toString();
      bio = (data['bio'] ?? '').toString();

      education = (data['education'] ?? '').toString();
      degree = (data['degree'] ?? '').toString();
      graduationYear = (data['graduationYear'] ?? '').toString();

      targetRole = (data['targetRole'] ?? '').toString();
      experienceLevel = (data['experienceLevel'] ?? '').toString();

      preferredLocation = (data['preferredLocation'] ?? '').toString();
      workMode = (data['workMode'] ?? '').toString();
      expectedSalary = (data['expectedSalary'] ?? '').toString();
      jobType = (data['jobType'] ?? '').toString();
      companyType = (data['companyType'] ?? '').toString();

      willingToRelocate = data['relocation'] == true;

      profilePhotoUrl = data['profilePhotoUrl']?.toString();
      resumeUrl = data['resumeUrl']?.toString();
      resumeName = data['resumeName']?.toString();

      final rawSkills = data['skills'];
      skills = rawSkills is List
          ? rawSkills.map((e) => e.toString()).toSet().toList()
          : <String>[];

      final settings = data['profileSettings'];
      if (settings is Map) {
        final notifications = settings['notifications'];
        if (notifications is Map) {
          notificationsEnabled = notifications['enabled'] != false;
          dailyReminder = notifications['dailyReminder'] != false;
        }
      }

      nameController.text = name;
      phoneController.text = phone;
      cityController.text = city;
      bioController.text = bio;
      educationController.text = education;
      degreeController.text = degree;
      yearController.text = graduationYear;
      targetRoleController.text = targetRole;
      experienceController.text = experienceLevel;
      locationController.text = preferredLocation;
      salaryController.text = expectedSalary;
      jobTypeController.text = jobType;
      companyTypeController.text = companyType;

      await _loadPlacementStats(user.uid);

      if (mounted) {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint('Profile load error: $e');

      if (mounted) {
        setState(() => isLoading = false);
        _message('Unable to load profile', error: true);
      }
    }
  }

  Future<void> _loadPlacementStats(String uid) async {
    try {
      final userRef = _firestore.collection('users').doc(uid);

      final saved = await userRef.collection('savedJobs').get();
      final applied = await userRef.collection('appliedJobs').get();
      final courses = await userRef.collection('learningCourses').get();

      savedJobs = saved.docs.length;
      appliedJobs = applied.docs.length;
      learningCourses = courses.docs.length;
    } catch (e) {
      debugPrint('Placement stats error: $e');
    }
  }

  Future<void> _refreshProfile() async {
    if (mounted) setState(() => isLoading = true);
    await _loadProfile();
    if (mounted) await _scheduleDailyReminder();
  }

  // PROFILE PHOTO
  Future<void> _changeProfilePhoto() async {
  final user = currentUser;

  if (user == null) {
    _message('Please log in first', error: true);
    return;
  }

  try {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (image == null || !mounted) return;

    setState(() => isUploadingPhoto = true);

    final Uint8List bytes = await image.readAsBytes();

    final reference = _storage
        .ref()
        .child('users/${user.uid}/profile/profile.jpg');

    // Step 1: Upload the image
    final uploadResult = await reference.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );

   debugPrint('Upload completed: ${uploadResult.ref.fullPath}');

    // Step 2: Get download URL
    final url = await uploadResult.ref.getDownloadURL();

    debugPrint('Download URL received successfully');

    // Step 3: Save URL in Firestore
    await _firestore.collection('users').doc(user.uid).set({
      'profilePhotoUrl': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (!mounted) return;

    setState(() {
      profilePhotoUrl = url;
      isUploadingPhoto = false;
    });

    _message('Profile photo updated successfully');
  } on FirebaseException catch (e) {
    debugPrint('Firebase error code: ${e.code}');
    debugPrint('Firebase error message: ${e.message}');

    if (mounted) {
      setState(() => isUploadingPhoto = false);
      _message('Photo upload failed: ${e.code}', error: true);
    }
  } catch (e) {
    debugPrint('Unexpected photo error: $e');

    if (mounted) {
      setState(() => isUploadingPhoto = false);
      _message('Photo upload failed.', error: true);
    }
  }
}
  // SAVE PROFILE

  Future<void> _saveProfile() async {
    final user = currentUser;
    if (user == null) {
      _message('Please log in first', error: true);
      return;
    }

    setState(() => isSaving = true);

    try {
      final updatedName = nameController.text.trim();

      final updatedData = <String, dynamic>{
        'name': updatedName,
        'email': user.email ?? email,
        'phone': phoneController.text.trim(),
        'city': cityController.text.trim(),
        'gender': gender,
        'bio': bioController.text.trim(),
        'education': educationController.text.trim(),
        'degree': degreeController.text.trim(),
        'graduationYear': yearController.text.trim(),
        'targetRole': targetRoleController.text.trim(),
        'experienceLevel': experienceController.text.trim(),
        'preferredLocation': locationController.text.trim(),
        'workMode': workMode,
        'expectedSalary': salaryController.text.trim(),
        'jobType': jobTypeController.text.trim(),
        'companyType': companyTypeController.text.trim(),
        'relocation': willingToRelocate,
        'skills': skills,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('users').doc(user.uid).set(
            updatedData,
            SetOptions(merge: true),
          );

      if (updatedName.isNotEmpty && updatedName != user.displayName) {
        await user.updateDisplayName(updatedName);
      }

      if (!mounted) return;

      setState(() {
        name = updatedName;
        email = user.email ?? email;
        phone = phoneController.text.trim();
        city = cityController.text.trim();
        bio = bioController.text.trim();
        education = educationController.text.trim();
        degree = degreeController.text.trim();
        graduationYear = yearController.text.trim();
        targetRole = targetRoleController.text.trim();
        experienceLevel = experienceController.text.trim();
        preferredLocation = locationController.text.trim();
        expectedSalary = salaryController.text.trim();
        jobType = jobTypeController.text.trim();
        companyType = companyTypeController.text.trim();
        isSaving = false;
      });

      Navigator.of(context).pop();
      _message('Profile updated successfully');
    } catch (e) {
      debugPrint('Save profile error: $e');

      if (mounted) {
        setState(() => isSaving = false);
        _message('Failed to save profile', error: true);
      }
    }
  }

  // EDIT PROFILE

  void _editProfile(String title, List<Widget> fields) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(26),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: dark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ...fields,
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          filled: true,
          fillColor: const Color(0xFFF6F7FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: DropdownButtonFormField<String>(
        initialValue: options.contains(value) ? value : null,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: const Color(0xFFF6F7FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(13),
            borderSide: BorderSide.none,
          ),
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                value: option,
                child: Text(option),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    );
  }

  void _editPersonal() {
    _editProfile('Personal Information', [
      _field(nameController, 'Full Name'),
      _field(
        phoneController,
        'Phone Number',
        keyboardType: TextInputType.phone,
      ),
      _field(cityController, 'City'),
      _dropdown(
        'Gender',
        gender,
        const ['Male', 'Female', 'Other', 'Prefer not to say'],
        (value) => setState(() => gender = value ?? ''),
      ),
      _field(bioController, 'Bio', maxLines: 3),
    ]);
  }

  void _editEducation() {
    _editProfile('Education', [
      _field(educationController, 'Education', hint: 'Example: MCA'),
      _field(degreeController, 'Degree / Specialization'),
      _field(
        yearController,
        'Graduation Year',
        keyboardType: TextInputType.number,
      ),
    ]);
  }

  void _editCareer() {
    _editProfile('Career Profile', [
      _field(targetRoleController, 'Target Role',
          hint: 'Example: Flutter Developer'),
      _field(experienceController, 'Experience Level',
          hint: 'Fresher / Intern / 1–2 Years'),
    ]);
  }

  void _editPreferences() {
    _editProfile('Job Preferences', [
      _field(locationController, 'Preferred Location'),
      _dropdown(
        'Work Mode',
        workMode,
        const ['On-site', 'Hybrid', 'Remote'],
        (value) => setState(() => workMode = value ?? ''),
      ),
      _field(salaryController, 'Expected Salary', hint: 'Example: 6 LPA'),
      _field(jobTypeController, 'Job Type', hint: 'Full Time / Internship'),
      _field(
        companyTypeController,
        'Company Type',
        hint: 'Product / Service / Startup',
      ),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Willing to relocate'),
        value: willingToRelocate,
        activeThumbColor: primary,
        onChanged: (value) => setState(() => willingToRelocate = value),
      ),
    ]);
  }

  // SKILLS

  void _editSkills() {
    final controller = TextEditingController(text: skills.join(', '));

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit Skills'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Flutter, Dart, Firebase, SQL',
            helperText: 'Separate skills with commas.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedSkills = controller.text
                  .split(',')
                  .map((skill) => skill.trim())
                  .where((skill) => skill.isNotEmpty)
                  .toSet()
                  .toList();

              final user = currentUser;
              if (user == null) {
                _message('Please log in first', error: true);
                return;
              }

              try {
                await _firestore.collection('users').doc(user.uid).set({
                  'skills': updatedSkills,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));

                if (!mounted) return;

                setState(() => skills = updatedSkills);
                Navigator.pop(dialogContext);
                _message('Skills updated');
              } catch (e) {
                debugPrint('Skills save error: $e');
                if (mounted) {
                  _message('Could not save skills', error: true);
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  // RESUME UPLOAD

  Future<void> _uploadResume() async {
    final user = currentUser;
    if (user == null) {
      _message('Please log in first', error: true);
      return;
    }

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        withData: true,
      );

      if (result == null || result.files.isEmpty || !mounted) return;

      final file = result.files.first;
      final Uint8List? bytes = file.bytes;

      if (bytes == null) {
        _message('Unable to read selected file', error: true);
        return;
      }

      setState(() => isUploadingResume = true);

      final reference = _storage
          .ref()
          .child('users/${user.uid}/resume/${file.name}');

      await reference.putData(bytes);
      final url = await reference.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).set({
        'resumeUrl': url,
        'resumeName': file.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      setState(() {
        resumeUrl = url;
        resumeName = file.name;
        isUploadingResume = false;
      });

      _message('Resume uploaded successfully');
    } catch (e) {
      debugPrint('Resume upload error: $e');

      if (mounted) {
        setState(() => isUploadingResume = false);
        _message('Resume upload failed. Check Firebase Storage.', error: true);
      }
    }
  }

  // ACCOUNT

  Future<void> _resetPassword() async {
    final user = currentUser;

    if (user?.email == null) {
      _message('Email address not available', error: true);
      return;
    }

    try {
      await _auth.sendPasswordResetEmail(email: user!.email!);
      if (mounted) _message('Password reset email sent');
    } catch (e) {
      debugPrint('Password reset error: $e');
      if (mounted) {
        _message('Unable to send reset email', error: true);
      }
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await _auth.signOut();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // UI COMPONENTS

  Widget _section({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFEAECF3)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 5,
        ),
        leading: Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF0FF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: primary),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: dark,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            subtitle,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ),
    );
  }

  Widget _statCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFFEAECF3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: primary, size: 22),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: dark,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primary, secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 46,
                backgroundColor: Colors.white,
                backgroundImage:
                    profilePhotoUrl != null && profilePhotoUrl!.isNotEmpty
                        ? NetworkImage(profilePhotoUrl!)
                        : null,
                child: profilePhotoUrl == null || profilePhotoUrl!.isEmpty
                    ? const Icon(
                        Icons.person,
                        size: 48,
                        color: primary,
                      )
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: Colors.white,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: isUploadingPhoto ? null : _changeProfilePhoto,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: isUploadingPhoto
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              color: primary,
                              size: 19,
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Text(
            name.isEmpty ? 'Complete Your Profile' : name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            email,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          if (targetRole.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                targetRole,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: isUploadingPhoto ? null : _changeProfilePhoto,
            icon: const Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
            ),
            label: const Text(
              'Change Profile Photo',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  // MAIN SCREEN

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: dark,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshProfile,
            icon: const Icon(Icons.refresh_rounded, color: dark),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: primary),
            )
          : RefreshIndicator(
              color: primary,
              onRefresh: _refreshProfile,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 35),
                children: [
                  _profileHeader(),
                  const SizedBox(height: 22),

                  const Text(
                    'Placement Overview',
                    style: TextStyle(
                      fontSize: 18,
                      color: dark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statCard(
                        '$savedJobs',
                        'Saved Jobs',
                        Icons.bookmark_outline,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        '$appliedJobs',
                        'Applied',
                        Icons.send_outlined,
                      ),
                      const SizedBox(width: 10),
                      _statCard(
                        '$learningCourses',
                        'Courses',
                        Icons.school_outlined,
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),
                  const Text(
                    'Profile Details',
                    style: TextStyle(
                      fontSize: 18,
                      color: dark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _section(
                    title: 'Personal Information',
                    subtitle: name.isEmpty
                        ? 'Add your personal information'
                        : '$name • ${city.isEmpty ? "City not set" : city}',
                    icon: Icons.person_outline,
                    onTap: _editPersonal,
                  ),
                  _section(
                    title: 'Education',
                    subtitle: degree.isEmpty
                        ? 'Add your education details'
                        : '$degree • $graduationYear',
                    icon: Icons.school_outlined,
                    onTap: _editEducation,
                  ),
                  _section(
                    title: 'Career Profile',
                    subtitle: targetRole.isEmpty
                        ? 'Set your target career'
                        : '$targetRole • ${experienceLevel.isEmpty ? "Experience not set" : experienceLevel}',
                    icon: Icons.work_outline,
                    onTap: _editCareer,
                  ),
                  _section(
                    title: 'Skills',
                    subtitle: skills.isEmpty
                        ? 'Add your technical skills'
                        : skills.take(4).join(' • '),
                    icon: Icons.psychology_outlined,
                    onTap: _editSkills,
                  ),
                  _section(
                    title: 'Job Preferences',
                    subtitle: preferredLocation.isEmpty && workMode.isEmpty
                        ? 'Set your job preferences'
                        : '${preferredLocation.isEmpty ? "Location not set" : preferredLocation} • ${workMode.isEmpty ? "Work mode not set" : workMode}',
                    icon: Icons.tune_rounded,
                    onTap: _editPreferences,
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Career Tools',
                    style: TextStyle(
                      fontSize: 18,
                      color: dark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _section(
                    title: 'Resume Builder',
                    subtitle: resumeName ?? 'Create and manage your resume',
                    icon: Icons.description_outlined,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ResumeBuilderScreen(),
                        ),
                      );
                    },
                  ),
                  _section(
                    title: 'Upload Resume',
                    subtitle: isUploadingResume
                        ? 'Uploading resume...'
                        : resumeName ?? 'PDF, DOC or DOCX',
                    icon: Icons.upload_file_outlined,
                    onTap: isUploadingResume ? () {} : _uploadResume,
                    trailing: isUploadingResume
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
                  ),

                  const SizedBox(height: 14),
                  const Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 18,
                      color: dark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  _section(
                    title: 'Notifications',
                    subtitle: notificationsEnabled
                        ? 'Notifications are enabled'
                        : 'Notifications are disabled',
                    icon: Icons.notifications_outlined,
                    onTap: () {},
                    trailing: Switch(
                      value: notificationsEnabled,
                      activeThumbColor: primary,
                      onChanged: (value) async {
                        setState(() => notificationsEnabled = value);
                        await _saveNotificationSettings();
                      },
                    ),
                  ),
                  if (notificationsEnabled)
                    _section(
                      title: 'Daily Study Reminder',
                      subtitle: dailyReminder
                          ? 'Daily reminder enabled'
                          : 'Daily reminder disabled',
                      icon: Icons.alarm_outlined,
                      onTap: () {},
                      trailing: Switch(
                        value: dailyReminder,
                        activeThumbColor: primary,
                        onChanged: (value) async {
                          setState(() => dailyReminder = value);
                          await _saveNotificationSettings();
                        },
                      ),
                    ),
                  _section(
                    title: 'Change Password',
                    subtitle: 'Send a reset link to your email',
                    icon: Icons.lock_reset_outlined,
                    onTap: _resetPassword,
                  ),

                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout, color: Colors.red),
                      label: const Text(
                        'Logout',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: Color(0xFFF1CACA),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),
                  const Center(
                    child: Text(
                      'CareerPilot AI • Profile',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
