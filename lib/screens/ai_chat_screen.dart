import 'dart:convert';

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:image_picker/image_picker.dart';

class AIChatScreen extends StatefulWidget {

  const AIChatScreen({super.key});

  @override

  State<AIChatScreen> createState() => _AIChatScreenState();

}

class _AIChatScreenState extends State<AIChatScreen> {

  // ============================================================*

  // API*

  // ============================================================*

 static const String apiUrl =

    'https://career-ai-backend-fk2i.onrender.com/api/chat';

  // ============================================================*

  // CONTROLLERS*

  // ============================================================*

  final TextEditingController messageController =

      TextEditingController();

  final ScrollController scrollController =

      ScrollController();

  final ImagePicker imagePicker = ImagePicker();

  // ============================================================*

  // MESSAGES*

  // ============================================================*

  final List<Map<String, dynamic>> messages = [

    {

      "isUser": false,

      "message":

          "Hi! I'm your AI Career Mentor 🤖\n\n"

          "I can help you with career planning, skills, jobs, "

          "interviews, projects and learning.\n\n"

          "What would you like to know?",

    },

  ];

  // ============================================================*

  // STATE*

  // ============================================================*

  bool isTyping = false;

  XFile? selectedImage;

  // Cached profile for faster chat*

  Map<String, dynamic> cachedProfile = {};

  bool profileLoaded = false;

  // ============================================================*

  // INIT*

  // ============================================================*

  @override

  void initState() {

    super.initState();

    _loadProfile();

  }

  // ============================================================*

  // LOAD PROFILE ONCE*

  // ============================================================*

  Future<void> _loadProfile() async {

    try {

      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {

        return;

      }

      final doc = await FirebaseFirestore.instance

          .collection('users')

          .doc(user.uid)

          .get();

      final rawProfile = doc.data() ?? {};

      if (!mounted) {

        return;

      }

      setState(() {

        cachedProfile = {

          "name": rawProfile["name"]?.toString() ?? "",

          "email": rawProfile["email"]?.toString() ?? "",

          "education":

              rawProfile["education"]?.toString() ?? "",

          "degree": rawProfile["degree"]?.toString() ?? "",

          "graduationYear":

              rawProfile["graduationYear"]?.toString() ?? "",

          "status": rawProfile["status"]?.toString() ?? "",

          "skills": rawProfile["skills"] is List

              ? (rawProfile["skills"] as List)

                  .map((skill) => skill.toString())

                  .toList()

              : <String>[],

          "targetRole":

              rawProfile["targetRole"]?.toString() ?? "",

          "experienceLevel":

              rawProfile["experienceLevel"]?.toString() ?? "",

          "preferredLocation":

              rawProfile["preferredLocation"]?.toString() ?? "",

          "workMode":

              rawProfile["workMode"]?.toString() ?? "",

          "expectedSalary":

              rawProfile["expectedSalary"]?.toString() ?? "",

          "jobType":

              rawProfile["jobType"]?.toString() ?? "",

          "companyType":

              rawProfile["companyType"]?.toString() ?? "",

          "relocation":

              rawProfile["relocation"]?.toString() ?? "",

        };

        profileLoaded = true;

      });

      debugPrint("Profile loaded successfully");

    } catch (e) {

      debugPrint("Profile load error: $e");

    }

  }

  // ============================================================*

  // DISPOSE*

  // ============================================================*

  @override

  void dispose() {

    messageController.dispose();

    scrollController.dispose();

    super.dispose();

  }

  // ============================================================*

  // SEND MESSAGE*

  // ============================================================*

  Future<void> sendMessage() async {

    final message = messageController.text.trim();

    // Nothing to send*

    if ((message.isEmpty && selectedImage == null) ||

        isTyping) {

      return;

    }

    final imageToSend = selectedImage;

    String? imageBase64;

    String? imageMimeType;

    // ==========================================================*

    // IMAGE*

    // ==========================================================*

    if (imageToSend != null) {

      try {

        final bytes = await imageToSend.readAsBytes();

        if (bytes.isEmpty) {

          throw Exception("Image is empty");

        }

        imageBase64 = base64Encode(bytes);

        final extension =

            imageToSend.path.split('.').last.toLowerCase();

        if (extension == "png") {
          imageMimeType = "image/png";
        } else if (extension == "webp") {
          imageMimeType = "image/webp";
        } else if (extension == "jpg" || extension == "jpeg") {
          imageMimeType = "image/jpeg";
        } else {
          throw Exception(
            "Unsupported image format. Please select JPG, JPEG, PNG or WEBP.",
          );
        }

        debugPrint(

          "Image size: "

          "${(bytes.length / 1024).toStringAsFixed(1)} KB",

        );

      } catch (e) {

        debugPrint("Image read error: $e");

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text(

              "Unable to read selected image.",

            ),

          ),

        );

        return;

      }

    }

    // ==========================================================*

    // ADD USER MESSAGE IMMEDIATELY*

    // ==========================================================*

    setState(() {

      messages.add({

        "isUser": true,

        "message": message,

        "imagePath": imageToSend?.path,

      });

      messageController.clear();

      selectedImage = null;

      isTyping = true;

    });

    scrollToBottom();

    // ==========================================================*

    // SEND TO BACKEND*

    // ==========================================================*

    try {

      // --------------------------------------------------------*

      // USE CACHED PROFILE*

      // --------------------------------------------------------*

      Map<String, dynamic> profile = cachedProfile;

      // If profile is not loaded yet*

      if (!profileLoaded) {

        await _loadProfile();

        profile = cachedProfile;

      }

      // --------------------------------------------------------*

      // REQUEST BODY*

      // --------------------------------------------------------*

      final Map<String, dynamic> requestBody = {

        "message": message,

        "profile": profile,

      };

      // --------------------------------------------------------*

      // ADD IMAGE*

      // --------------------------------------------------------*

      if (imageBase64 != null) {

        requestBody["image"] = {

          "mimeType":

              imageMimeType ?? "image/jpeg",

          "data": imageBase64,

        };

      }

      final requestJson = jsonEncode(requestBody);

      debugPrint(
        "Sending AI request... "
        "Payload size: ${(requestJson.length / 1024).toStringAsFixed(1)} KB",
      );

      // --------------------------------------------------------*

      // HTTP REQUEST*

      // --------------------------------------------------------*

      final response = await http

          .post(

            Uri.parse(apiUrl),

            headers: {

              "Content-Type": "application/json",

              "Accept": "application/json",

            },

            body: requestJson,

          )

          .timeout(

            const Duration(seconds: 90),

          );

      debugPrint(

        "AI response status: ${response.statusCode}",

      );

      // --------------------------------------------------------*

      // SERVER ERROR*

      // --------------------------------------------------------*

      if (response.statusCode != 200) {
        String serverMessage = "Server returned ${response.statusCode}";

        try {
          final errorData = jsonDecode(response.body);
          serverMessage =
              errorData["message"]?.toString() ?? serverMessage;
        } catch (_) {
          // Keep the status message if the response is not JSON.
        }

        throw Exception(serverMessage);
      }

      // --------------------------------------------------------*

      // DECODE*

      // --------------------------------------------------------*

      final data = jsonDecode(response.body);

      if (data["success"] != true) {

        throw Exception(

          data["message"]?.toString() ??

              "AI response failed",

        );

      }

      // --------------------------------------------------------*

      // AI REPLY*

      // --------------------------------------------------------*

      final reply = data["reply"]?.toString() ??

          "Sorry, I couldn't generate a response.";

      if (!mounted) {

        return;

      }

      setState(() {

        isTyping = false;

        messages.add({

          "isUser": false,

          "message": reply,

        });

      });

      scrollToBottom();

    } catch (e, stackTrace) {

      debugPrint("AI CHAT ERROR: $e");

      debugPrint("$stackTrace");

      if (!mounted) {

        return;

      }

      setState(() {

        isTyping = false;

        messages.add({

          "isUser": false,

          "message":

              "Sorry, I couldn't connect to the AI right now.\n\n"

              "Please try again.",

        });

      });

      scrollToBottom();

    }

  }

  // ============================================================*

  // PICK IMAGE*

  // ============================================================*

  Future<void> pickImage() async {

    if (isTyping) {

      return;

    }

    try {

      final image = await imagePicker.pickImage(

        source: ImageSource.gallery,

        // Strong compression*

        imageQuality: 30,

        // Reduce resolution*

        maxWidth: 800,

        maxHeight: 800,

      );

      if (image == null || !mounted) {

        return;

      }

      // --------------------------------------------------------*

      // CHECK IMAGE SIZE*

      // --------------------------------------------------------*

      final bytes = await image.readAsBytes();

      final sizeKB = bytes.length / 1024;

      debugPrint(

        "Selected image size: "

        "${sizeKB.toStringAsFixed(1)} KB",

      );

      // Maximum 2 MB safety check*

      if (bytes.length > 2 * 1024 * 1024) {

        ScaffoldMessenger.of(context).showSnackBar(

          const SnackBar(

            content: Text(

              "Image is too large. Please select a smaller image.",

            ),

          ),

        );

        return;

      }

      setState(() {

        selectedImage = image;

      });

    } catch (e) {

      debugPrint("Image picker error: $e");

      if (!mounted) {

        return;

      }

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text(

            "Unable to select image.",

          ),

        ),

      );

    }

  }

  // ============================================================*

  // REMOVE IMAGE*

  // ============================================================*

  void removeSelectedImage() {

    if (isTyping) {

      return;

    }

    setState(() {

      selectedImage = null;

    });

  }

  // ============================================================*

  // SCROLL*

  // ============================================================*

  void scrollToBottom() {

    Future.delayed(

      const Duration(milliseconds: 100),

      () {

        if (!scrollController.hasClients) {

          return;

        }

        scrollController.animateTo(

          scrollController.position.maxScrollExtent,

          duration:

              const Duration(milliseconds: 300),

          curve: Curves.easeOut,

        );

      },

    );

  }

  // ============================================================*

  // BUILD*

  // ============================================================*

  @override

  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:

          const Color(0xffF6F7FB),

      // ========================================================*

      // APP BAR*

      // ========================================================*

      appBar: AppBar(

        elevation: 0,

        backgroundColor: Colors.white,

        surfaceTintColor: Colors.white,

        leading: IconButton(

          icon: const Icon(

            Icons.arrow_back_ios_new,

            color: Color(0xff172033),

            size: 20,

          ),

          onPressed: () {

            Navigator.pop(context);

          },

        ),

        title: Row(

          children: [

            Container(

              width: 42,

              height: 42,

              decoration: BoxDecoration(

                gradient:

                    const LinearGradient(

                  colors: [

                    Color(0xff667EEA),

                    Color(0xff764BA2),

                  ],

                ),

                borderRadius:

                    BorderRadius.circular(14),

              ),

              child: const Icon(

                Icons.smart_toy_outlined,

                color: Colors.white,

                size: 23,

              ),

            ),

            const SizedBox(width: 12),

            const Column(

              crossAxisAlignment:

                  CrossAxisAlignment.start,

              children: [

                Text(

                  "AI Career Mentor",

                  style: TextStyle(

                    color: Color(0xff172033),

                    fontSize: 17,

                    fontWeight: FontWeight.bold,

                  ),

                ),

                SizedBox(height: 2),

                Row(

                  children: [

                    Icon(

                      Icons.circle,

                      size: 8,

                      color: Colors.green,

                    ),

                    SizedBox(width: 5),

                    Text(

                      "Online",

                      style: TextStyle(

                        color: Colors.green,

                        fontSize: 11,

                      ),

                    ),

                  ],

                ),

              ],

            ),

          ],

        ),

      ),

      // ========================================================*

      // BODY*

      // ========================================================*

      body: Column(

        children: [

          Expanded(

            child: ListView.builder(

              controller:

                  scrollController,

              padding:

                  const EdgeInsets.fromLTRB(

                16,

                20,

                16,

                15,

              ),

              itemCount:

                  messages.length +

                  (isTyping ? 1 : 0),

              itemBuilder:

                  (context, index) {

                // ------------------------------------------------*

                // TYPING INDICATOR*

                // ------------------------------------------------*

                if (isTyping &&

                    index == messages.length) {

                  return _typingIndicator();

                }

                // ------------------------------------------------*

                // MESSAGE*

                // ------------------------------------------------*

                final message =

                    messages[index];

                return _messageBubble(

                  message["message"]

                          ?.toString() ??

                      "",

                  message["isUser"]

                      as bool,

                  // IMPORTANT:*

                  // Send image path to bubble*

                  imagePath:

                      message["imagePath"]

                          ?.toString(),

                );

              },

            ),

          ),

          // ------------------------------------------------------*

          // SUGGESTIONS*

          // ------------------------------------------------------*

          if (messages.length == 1 &&

              !isTyping)

            _suggestions(),

          // ------------------------------------------------------*

          // INPUT*

          // ------------------------------------------------------*

          _inputArea(),

        ],

      ),

    );

  }

  // ============================================================*

  // MESSAGE BUBBLE*

  // ============================================================*

  Widget _messageBubble(

    String message,

    bool isUser, {

    String? imagePath,

  }) {

    return Align(

      alignment: isUser

          ? Alignment.centerRight

          : Alignment.centerLeft,

      child: Container(

        constraints:

            BoxConstraints(

          maxWidth:

              MediaQuery.of(context)

                      .size

                      .width *

                  0.82,

        ),

        margin:

            const EdgeInsets.only(

          bottom: 14,

        ),

        padding:

            const EdgeInsets.symmetric(

          horizontal: 16,

          vertical: 13,

        ),

        decoration: BoxDecoration(

          gradient: isUser

              ? const LinearGradient(

                  colors: [

                    Color(0xff667EEA),

                    Color(0xff764BA2),

                  ],

                )

              : null,

          color: isUser

              ? null

              : Colors.white,

          borderRadius:

              BorderRadius.only(

            topLeft:

                const Radius.circular(18),

            topRight:

                const Radius.circular(18),

            bottomLeft:

                Radius.circular(

              isUser ? 18 : 4,

            ),

            bottomRight:

                Radius.circular(

              isUser ? 4 : 18,

            ),

          ),

          boxShadow: [

            if (!isUser)

              BoxShadow(

                color:

                    Colors.black

                        .withOpacity(0.04),

                blurRadius: 8,

                offset:

                    const Offset(0, 3),

              ),

          ],

        ),

        child: Column(

          crossAxisAlignment:

              CrossAxisAlignment.start,

          children: [

            // ----------------------------------------------------*

            // IMAGE*

            // ----------------------------------------------------*

            if (imagePath != null &&

                imagePath.isNotEmpty)

              ClipRRect(

                borderRadius:

                    BorderRadius.circular(

                  12,

                ),

                child: Image.file(

                  File(imagePath),

                  width:

                      double.infinity,

                  height: 180,

                  fit: BoxFit.cover,

                  errorBuilder:

                      (

                    context,

                    error,

                    stackTrace,

                  ) {

                    return Container(

                      height: 180,

                      width:

                          double.infinity,

                      alignment:

                          Alignment.center,

                      color:

                          const Color(

                        0xffF0F1FF,

                      ),

                      child:

                          const Icon(

                        Icons

                            .broken_image_outlined,

                        color:

                            Color(

                          0xff667EEA,

                        ),

                        size: 40,

                      ),

                    );

                  },

                ),

              ),

            // ----------------------------------------------------*

            // SPACE*

            // ----------------------------------------------------*

            if (imagePath != null &&

                imagePath.isNotEmpty &&

                message.isNotEmpty)

              const SizedBox(

                height: 10,

              ),

            // ----------------------------------------------------*

            // TEXT*

            // ----------------------------------------------------*

            if (message.isNotEmpty)

              Text(

                message,

                style: TextStyle(

                  color: isUser

                      ? Colors.white

                      : const Color(

                          0xff303647,

                        ),

                  fontSize: 14,

                  height: 1.5,

                ),

              ),

          ],

        ),

      ),

    );

  }

  // ============================================================*

  // TYPING INDICATOR*

  // ============================================================*

  Widget _typingIndicator() {

    return Align(

      alignment: Alignment.centerLeft,

      child: Container(

        margin:

            const EdgeInsets.only(

          bottom: 14,

        ),

        padding:

            const EdgeInsets.symmetric(

          horizontal: 18,

          vertical: 15,

        ),

        decoration: BoxDecoration(

          color: Colors.white,

          borderRadius:

              BorderRadius.circular(

            18,

          ),

          boxShadow: [

            BoxShadow(

              color: Colors.black

                  .withOpacity(0.04),

              blurRadius: 8,

              offset:

                  const Offset(0, 3),

            ),

          ],

        ),

        child: const Row(

          mainAxisSize:

              MainAxisSize.min,

          children: [

            SizedBox(

              width: 7,

              height: 7,

              child: DecoratedBox(

                decoration:

                    BoxDecoration(

                  color:

                      Color(0xff667EEA),

                  shape:

                      BoxShape.circle,

                ),

              ),

            ),

            SizedBox(width: 5),

            SizedBox(

              width: 7,

              height: 7,

              child: DecoratedBox(

                decoration:

                    BoxDecoration(

                  color:

                      Color(0xff667EEA),

                  shape:

                      BoxShape.circle,

                ),

              ),

            ),

            SizedBox(width: 5),

            SizedBox(

              width: 7,

              height: 7,

              child: DecoratedBox(

                decoration:

                    BoxDecoration(

                  color:

                      Color(0xff667EEA),

                  shape:

                      BoxShape.circle,

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

  // ============================================================*

  // SUGGESTIONS*

  // ============================================================*

  Widget _suggestions() {

    final suggestions = [

      "How can I improve my career?",

      "What skills should I learn?",

      "Help me prepare for interview",

      "Give me a career roadmap",

    ];

    return Container(

      height: 45,

      margin:

          const EdgeInsets.only(

        bottom: 10,

      ),

      child: ListView.builder(

        scrollDirection:

            Axis.horizontal,

        padding:

            const EdgeInsets.symmetric(

          horizontal: 16,

        ),

        itemCount:

            suggestions.length,

        itemBuilder:

            (context, index) {

          return GestureDetector(

            onTap: () {

              if (isTyping) {

                return;

              }

              messageController.text =

                  suggestions[index];

              sendMessage();

            },

            child: Container(

              margin:

                  const EdgeInsets.only(

                right: 8,

              ),

              padding:

                  const EdgeInsets.symmetric(

                horizontal: 14,

                vertical: 10,

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

                      const Color(

                    0xffE2E4ED,

                  ),

                ),

              ),

              child: Text(

                suggestions[index],

                style: const TextStyle(

                  fontSize: 12,

                  color:

                      Color(0xff5961A6),

                  fontWeight:

                      FontWeight.w500,

                ),

              ),

            ),

          );

        },

      ),

    );

  }

  // ============================================================*

  // INPUT AREA*

  // ============================================================*

  Widget _inputArea() {

    return Container(

      padding:

          const EdgeInsets.fromLTRB(

        12,

        10,

        12,

        14,

      ),

      decoration:

          const BoxDecoration(

        color: Colors.white,

        boxShadow: [

          BoxShadow(

            color: Color(0x12000000),

            blurRadius: 12,

            offset:

                Offset(0, -3),

          ),

        ],

      ),

      child: Column(

        children: [

          // ------------------------------------------------------*

          // SELECTED IMAGE PREVIEW*

          // ------------------------------------------------------*

          if (selectedImage != null)

            Container(

              width: double.infinity,

              margin:

                  const EdgeInsets.only(

                bottom: 8,

              ),

              padding:

                  const EdgeInsets.all(

                8,

              ),

              decoration:

                  BoxDecoration(

                color:

                    const Color(

                  0xffF6F7FB,

                ),

                borderRadius:

                    BorderRadius.circular(

                  14,

                ),

                border: Border.all(

                  color:

                      const Color(

                    0xffE2E4ED,

                  ),

                ),

              ),

              child: Row(

                children: [

                  // ------------------------------------------------*

                  // IMAGE PREVIEW*

                  // ------------------------------------------------*

                  ClipRRect(

                    borderRadius:

                        BorderRadius.circular(

                      10,

                    ),

                    child: Image.file(

                      File(

                        selectedImage!

                            .path,

                      ),

                      width: 62,

                      height: 62,

                      fit: BoxFit.cover,

                      errorBuilder:

                          (

                        context,

                        error,

                        stackTrace,

                      ) {

                        return Container(

                          width: 62,

                          height: 62,

                          color:

                              const Color(

                            0xffEDEEFF,

                          ),

                          child:

                              const Icon(

                            Icons

                                .image_outlined,

                            color:

                                Color(

                              0xff667EEA,

                            ),

                          ),

                        );

                      },

                    ),

                  ),

                  const SizedBox(

                    width: 10,

                  ),

                  const Expanded(

                    child: Text(

                      'Image attached',

                      style:

                          TextStyle(

                        fontSize: 13,

                        fontWeight:

                            FontWeight.w600,

                        color:

                            Color(

                          0xff4B5065,

                        ),

                      ),

                    ),

                  ),

                  // ------------------------------------------------*

                  // REMOVE*

                  // ------------------------------------------------*

                  IconButton(

                    onPressed:

                        removeSelectedImage,

                    icon:

                        const Icon(

                      Icons.close_rounded,

                      color:

                          Color(

                        0xff667EEA,

                      ),

                    ),

                  ),

                ],

              ),

            ),

          // ------------------------------------------------------*

          // INPUT ROW*

          // ------------------------------------------------------*

          Row(

            crossAxisAlignment:

                CrossAxisAlignment.end,

            children: [

              // --------------------------------------------------*

              // IMAGE BUTTON*

              // --------------------------------------------------*

              Container(

                width: 46,

                height: 46,

                margin:

                    const EdgeInsets.only(

                  right: 7,

                  bottom: 2,

                ),

                decoration:

                    BoxDecoration(

                  color:

                      const Color(

                    0xffF0F1FF,

                  ),

                  borderRadius:

                      BorderRadius.circular(

                    15,

                  ),

                ),

                child: IconButton(

                  onPressed:

                      isTyping

                          ? null

                          : pickImage,

                  icon:

                      const Icon(

                    Icons.image_outlined,

                    color:

                        Color(

                      0xff667EEA,

                    ),

                    size: 22,

                  ),

                  tooltip:

                      'Add image',

                ),

              ),

              // --------------------------------------------------*

              // TEXT FIELD*

              // --------------------------------------------------*

              Expanded(

                child: TextField(

                  controller:

                      messageController,

                  enabled: !isTyping,

                  minLines: 1,

                  maxLines: 5,

                  keyboardType:

                      TextInputType

                          .multiline,

                  textInputAction:

                      TextInputAction

                          .newline,

                  decoration:

                      InputDecoration(

                    hintText:

                        "Ask your career question...",

                    hintStyle:

                        const TextStyle(

                      color: Colors.grey,

                      fontSize: 13,

                    ),

                    filled: true,

                    fillColor:

                        const Color(

                      0xffF6F7FB,

                    ),

                    border:

                        OutlineInputBorder(

                      borderRadius:

                          BorderRadius

                              .circular(

                        18,

                      ),

                      borderSide:

                          BorderSide.none,

                    ),

                    contentPadding:

                        const EdgeInsets

                            .symmetric(

                      horizontal: 17,

                      vertical: 13,

                    ),

                  ),

                ),

              ),

              const SizedBox(

                width: 8,

              ),

              // --------------------------------------------------*

              // SEND BUTTON*

              // --------------------------------------------------*

              GestureDetector(

                onTap: isTyping

                    ? null

                    : sendMessage,

                child: Opacity(

                  opacity:

                      isTyping

                          ? 0.5

                          : 1.0,

                  child: Container(

                    width: 50,

                    height: 50,

                    decoration:

                        BoxDecoration(

                      gradient:

                          const LinearGradient(

                        colors: [

                          Color(

                            0xff667EEA,

                          ),

                          Color(

                            0xff764BA2,

                          ),

                        ],

                      ),

                      borderRadius:

                          BorderRadius

                              .circular(

                        17,

                      ),

                    ),

                    child:

                        const Icon(

                      Icons.send_rounded,

                      color:

                          Colors.white,

                      size: 22,

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

} 