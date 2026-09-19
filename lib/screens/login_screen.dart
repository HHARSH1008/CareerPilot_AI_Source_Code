import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'forgot_password_screen.dart';
import 'signup_screen.dart';
import 'about_yourself_screen.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;
  bool _googleReady = false;

  @override
  void initState() {
    super.initState();
    initializeGoogleSignIn();
  }

  // =========================================================
  // GOOGLE SIGN-IN INITIALIZATION
  // =========================================================

  Future<void> initializeGoogleSignIn() async {
    try {
      await GoogleSignIn.instance.initialize(
        serverClientId:
            '359617287559-dmd600e03glj5r43tf8rr22qnqt6g49c5.apps.googleusercontent.com',
      );

      if (mounted) {
        setState(() {
          _googleReady = true;
        });
      }

      debugPrint(
        "Google Sign-In initialized successfully",
      );
    } catch (e) {
      debugPrint(
        "Google Sign-In initialization failed: $e",
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // =========================================================
  // INPUT DECORATION
  // =========================================================

  InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF64748B),
      ),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFFE2E8F0),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: Color(0xFF4F46E5),
          width: 1.5,
        ),
      ),
    );
  }

  // =========================================================
  // CHECK PROFILE AND NAVIGATE
  // =========================================================

  Future<void> checkUserProfileAndNavigate() async {
    final User? user = FirebaseAuth.instance.currentUser;

    if (user == null || !mounted) {
      return;
    }

    try {
      debugPrint(
        "Checking profile for user: ${user.uid}",
      );

      final DocumentSnapshot<Map<String, dynamic>> doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

      final Map<String, dynamic>? data = doc.data();

      final bool profileCompleted =
          data != null &&
          data['profileCompleted'] == true;

      debugPrint(
        "Profile document exists: ${doc.exists}",
      );

      debugPrint(
        "Profile completed: $profileCompleted",
      );

      if (!mounted) return;

      // =====================================================
      // EXISTING USER - PROFILE COMPLETED
      // =====================================================

      if (profileCompleted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const DashboardScreen(),
          ),
          (route) => false,
        );
      }

      // =====================================================
      // NEW USER / PROFILE NOT COMPLETED
      // =====================================================

      else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                const AboutYourselfScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint(
        "Profile check error: $e",
      );

      if (!mounted) return;

      showMessage(
        "Unable to load your profile. Please try again.",
      );
    }
  }

  // =========================================================
  // EMAIL LOGIN
  // =========================================================

  Future<void> loginUser() async {
    final email =
        emailController.text.trim();

    final password =
        passwordController.text.trim();

    // Email validation
    if (email.isEmpty) {
      showMessage(
        "Please enter your email",
      );
      return;
    }

    // Password validation
    if (password.isEmpty) {
      showMessage(
        "Please enter your password",
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // -------------------------------------------------------
      // FIREBASE EMAIL LOGIN
      // -------------------------------------------------------

      await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (!mounted) return;

      // -------------------------------------------------------
      // CHECK PROFILE
      // -------------------------------------------------------

      await checkUserProfileAndNavigate();
    } on FirebaseAuthException catch (e) {
      String message =
          "Login failed";

      if (e.code == 'user-not-found') {
        message =
            "No account found with this email";
      } else if (e.code == 'wrong-password') {
        message =
            "Incorrect password";
      } else if (e.code == 'invalid-credential') {
        message =
            "Incorrect email or password";
      } else if (e.code == 'invalid-email') {
        message =
            "Please enter a valid email";
      } else if (e.code == 'user-disabled') {
        message =
            "This account has been disabled";
      } else if (e.code ==
          'network-request-failed') {
        message =
            "Please check your internet connection";
      }

      if (mounted) {
        showMessage(message);
      }
    } catch (e) {
      debugPrint(
        "Email Login Error: $e",
      );

      if (mounted) {
        showMessage(
          "Something went wrong. Please try again.",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // GOOGLE LOGIN
  // =========================================================

  Future<void> signInWithGoogle() async {
    if (!_googleReady) {
      showMessage(
        "Google Sign-In is still loading. Please try again.",
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // -------------------------------------------------------
      // STEP 1: OPEN GOOGLE ACCOUNT SELECTION
      // -------------------------------------------------------

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      // -------------------------------------------------------
      // STEP 2: GET GOOGLE AUTHENTICATION
      // -------------------------------------------------------

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      // -------------------------------------------------------
      // STEP 3: CREATE FIREBASE CREDENTIAL
      // -------------------------------------------------------

      final OAuthCredential credential =
          GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // -------------------------------------------------------
      // STEP 4: LOGIN TO FIREBASE
      // -------------------------------------------------------

      final UserCredential userCredential =
          await FirebaseAuth.instance
              .signInWithCredential(
        credential,
      );

      final User? user =
          userCredential.user;

      // -------------------------------------------------------
      // STEP 5: SAVE BASIC GOOGLE USER DATA
      // -------------------------------------------------------

      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(
          {
            'uid': user.uid,
            'name': user.displayName ?? '',
            'email': user.email ?? '',
            'photoUrl': user.photoURL ?? '',
            'updatedAt':
                FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      if (!mounted) return;

      // -------------------------------------------------------
      // STEP 6: CHECK PROFILE
      // -------------------------------------------------------

      await checkUserProfileAndNavigate();
    } on FirebaseAuthException catch (e) {
      debugPrint(
        "Google Firebase Auth Error: ${e.code}",
      );

      String message =
          "Google Login failed";

      if (e.code ==
          'account-exists-with-different-credential') {
        message =
            "This email is already registered with another login method.";
      } else if (e.code ==
          'network-request-failed') {
        message =
            "Please check your internet connection.";
      } else if (e.code ==
          'invalid-credential') {
        message =
            "Google credential is invalid. Please try again.";
      } else if (e.code ==
          'operation-not-allowed') {
        message =
            "Google Sign-In is not enabled in Firebase.";
      }

      if (mounted) {
        showMessage(message);
      }
    } catch (e) {
      debugPrint(
        "Google Sign-In Error: $e",
      );

      if (mounted) {
        showMessage(
          "Google Sign-In failed. Please try again.",
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // =========================================================
  // SHOW MESSAGE
  // =========================================================

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color.fromARGB(
        255,
        93,
        136,
        210,
      ),

      // =======================================================
      // APP BAR
      // =======================================================

      appBar: AppBar(
        backgroundColor:
            Colors.transparent,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
          onPressed: () =>
              Navigator.pop(context),
        ),
      ),

      // =======================================================
      // BODY
      // =======================================================

      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.fromLTRB(
            24,
            10,
            24,
            30,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [

              // =================================================
              // TITLE
              // =================================================

              const Text(
                'Welcome Back 👋',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight:
                      FontWeight.w800,
                  color:
                      Color(0xFF111827),
                ),
              ),

              const SizedBox(height: 8),

              // =================================================
              // SUBTITLE
              // =================================================

              const Text(
                'Login to continue your career journey.',
                style: TextStyle(
                  fontSize: 15,
                  color: Color.fromARGB(
                    255,
                    226,
                    227,
                    229,
                  ),
                ),
              ),

              const SizedBox(height: 35),

              // =================================================
              // EMAIL LABEL
              // =================================================

              const Text(
                'Email Address',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                  color: Color.fromARGB(
                    255,
                    216,
                    219,
                    223,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // =================================================
              // EMAIL FIELD
              // =================================================

              TextField(
                controller:
                    emailController,
                keyboardType:
                    TextInputType.emailAddress,
                decoration:
                    inputDecoration(
                  hint:
                      'Enter your email',
                  icon:
                      Icons.email_outlined,
                ),
              ),

              const SizedBox(height: 20),

              // =================================================
              // PASSWORD LABEL
              // =================================================

              const Text(
                'Password',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                  color: Color.fromARGB(
                    255,
                    236,
                    237,
                    238,
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // =================================================
              // PASSWORD FIELD
              // =================================================

              TextField(
                controller:
                    passwordController,
                obscureText:
                    hidePassword,
                decoration:
                    inputDecoration(
                  hint:
                      'Enter your password',
                  icon: Icons
                      .lock_outline_rounded,
                  suffix:
                      IconButton(
                    onPressed: () {
                      setState(() {
                        hidePassword =
                            !hidePassword;
                      });
                    },
                    icon: Icon(
                      hidePassword
                          ? Icons
                              .visibility_off_outlined
                          : Icons
                              .visibility_outlined,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // =================================================
              // FORGOT PASSWORD
              // =================================================

              Align(
                alignment:
                    Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ForgotPasswordScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Forgot Password?',
                    style: TextStyle(
                      color:
                          Color(0xFF4F46E5),
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 15),

              // =================================================
              // LOGIN BUTTON
              // =================================================

              SizedBox(
                width:
                    double.infinity,
                height: 56,
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(
                    gradient:
                        const LinearGradient(
                      colors: [
                        Color(0xFF2563EB),
                        Color(0xFF7C3AED),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),
                  child:
                      ElevatedButton(
                    onPressed: isLoading
                        ? null
                        : loginUser,
                    style:
                        ElevatedButton
                            .styleFrom(
                      backgroundColor:
                          Colors.transparent,
                      disabledBackgroundColor:
                          Colors.transparent,
                      shadowColor:
                          Colors.transparent,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          16,
                        ),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2.5,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style:
                                TextStyle(
                              color:
                                  Colors.white,
                              fontSize: 16,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // =================================================
              // OR DIVIDER
              // =================================================

              Row(
                children: const [
                  Expanded(
                    child: Divider(),
                  ),
                  Padding(
                    padding:
                        EdgeInsets.symmetric(
                      horizontal: 15,
                    ),
                    child: Text(
                      'OR',
                      style: TextStyle(
                        color:
                            Color(0xFF94A3B8),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Divider(),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              // =================================================
              // GOOGLE LOGIN BUTTON
              // =================================================

              SizedBox(
                width:
                    double.infinity,
                height: 54,
                child:
                    OutlinedButton.icon(
                  onPressed: isLoading
                      ? null
                      : signInWithGoogle,
                  icon: const Text(
                    'G',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                  label: const Text(
                    'Continue with Google',
                    style: TextStyle(
                      color: Color.fromARGB(
                        255,
                        80,
                        80,
                        80,
                      ),
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    backgroundColor:
                        Colors.white,
                    side:
                        const BorderSide(
                      color:
                          Color(0xFFE2E8F0),
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius
                              .circular(
                        16,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 25),

              // =================================================
              // SIGN UP
              // =================================================

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don't have an account? ",
                    style: TextStyle(
                      color: Color.fromARGB(
                        255,
                        242,
                        243,
                        244,
                      ),
                    ),
                  ),

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const SignUpScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      'Sign Up',
                      style: TextStyle(
                        color:
                            Color(0xFF4F46E5),
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}