import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class AIChatScreen extends StatefulWidget {
  const AIChatScreen({super.key});

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen> {
  // ============================================================
  // API
  // ============================================================

  static const String apiUrl =
      'https://career-ai-backend-fk2i.onrender.com/api/chat';

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController messageController =
      TextEditingController();

  final ScrollController scrollController =
      ScrollController();

  final ImagePicker imagePicker = ImagePicker();

  // ============================================================
  // MESSAGES
  // ============================================================

  final List<Map<String, dynamic>> messages = [];

  // ============================================================
  // STATE
  // ============================================================

  bool isTyping = false;
  bool isLoadingChat = true;
  bool isSavingMessage = false;

  XFile? selectedImage;

  Map<String, dynamic> cachedProfile = {};
  bool profileLoaded = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeChat();
  }

  // ============================================================
  // INITIALIZE CHAT
  // ============================================================

  Future<void> _initializeChat() async {
    await _loadProfile();
    await _loadChatHistory();

    if (mounted) {
      setState(() {
        isLoadingChat = false;
      });
    }

    scrollToBottom();
  }

  // ============================================================
  // CHAT COLLECTION
  // ============================================================

  CollectionReference<Map<String, dynamic>> _chatCollection(
    String uid,
  ) {
    return firestore
        .collection('users')
        .doc(uid)
        .collection('chatHistory');
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final user = auth.currentUser;

      if (user == null) {
        debugPrint("Profile load skipped: user not logged in.");
        return;
      }

      final doc = await firestore
          .collection('users')
          .doc(user.uid)
          .get();

      final rawProfile = doc.data() ?? {};

      cachedProfile = {
        "name": rawProfile["name"]?.toString() ?? "",
        "email": rawProfile["email"]?.toString() ?? "",
        "education": rawProfile["education"]?.toString() ?? "",
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

      debugPrint("Profile loaded successfully.");
    } catch (e) {
      debugPrint("Profile load error: $e");
    }
  }

  // ============================================================
  // LOAD CHAT HISTORY
  // ============================================================

  Future<void> _loadChatHistory() async {
    try {
      final user = auth.currentUser;

      if (user == null) {
        debugPrint("Chat history load skipped: user not logged in.");
        _addWelcomeMessage();
        return;
      }

      debugPrint(
        "Loading chat history for UID: ${user.uid}",
      );

      final snapshot = await _chatCollection(user.uid)
          .orderBy('createdAt', descending: false)
          .get();

      final loadedMessages = <Map<String, dynamic>>[];

      for (final document in snapshot.docs) {
        final data = document.data();

        final String message =
            data["message"]?.toString() ?? "";

        final bool isUser =
            data["isUser"] == true;

        if (message.isEmpty && data["hasImage"] != true) {
          continue;
        }

        loadedMessages.add({
          "id": document.id,
          "isUser": isUser,
          "message": message,
          "imagePath": null,
          "hasImage": data["hasImage"] == true,
        });
      }

      if (!mounted) {
        return;
      }

      setState(() {
        messages.clear();
        messages.addAll(loadedMessages);
      });

      if (loadedMessages.isEmpty) {
        _addWelcomeMessage();
      }

      debugPrint(
        "Chat history loaded: ${loadedMessages.length} messages",
      );
    } catch (e) {
      debugPrint("Chat history load error: $e");

      if (!mounted) {
        return;
      }

      setState(() {
        messages.clear();
      });

      _addWelcomeMessage();

      _showSnackBar(
        "Unable to load previous chat.",
      );
    }
  }

  // ============================================================
  // WELCOME MESSAGE
  // ============================================================

  void _addWelcomeMessage() {
    if (messages.isNotEmpty) {
      return;
    }

    setState(() {
      messages.add({
        "id": "welcome",
        "isUser": false,
        "message":
            "Hi! I'm your AI Career Mentor 🤖\n\n"
            "I can help you with career planning, skills, jobs, "
            "interviews, projects and learning.\n\n"
            "What would you like to know?",
        "imagePath": null,
        "hasImage": false,
      });
    });
  }

  // ============================================================
  // SAVE MESSAGE
  // ============================================================

  Future<String?> _saveMessage({
    required String message,
    required bool isUser,
    bool hasImage = false,
  }) async {
    try {
      final user = auth.currentUser;

      if (user == null) {
        debugPrint(
          "Message save failed: user not logged in.",
        );
        return null;
      }

      final document =
          await _chatCollection(user.uid).add({
        "isUser": isUser,
        "message": message,
        "hasImage": hasImage,
        "createdAt": FieldValue.serverTimestamp(),
      });

      debugPrint(
        "Chat message saved: ${document.id}",
      );

      return document.id;
    } catch (e) {
      debugPrint(
        "Chat message save error: $e",
      );

      return null;
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> sendMessage() async {
    final message =
        messageController.text.trim();

    if ((message.isEmpty &&
            selectedImage == null) ||
        isTyping) {
      return;
    }

    final user = auth.currentUser;

    if (user == null) {
      _showSnackBar(
        "Please login first.",
      );
      return;
    }

    // ----------------------------------------------------------
    // IMAGE
    // ----------------------------------------------------------

    final imageToSend = selectedImage;

    String? imageBase64;
    String? imageMimeType;

    if (imageToSend != null) {
      try {
        final bytes =
            await imageToSend.readAsBytes();

        if (bytes.isEmpty) {
          throw Exception(
            "Image is empty.",
          );
        }

        imageBase64 =
            base64Encode(bytes);

        final extension = imageToSend.path
            .split('.')
            .last
            .toLowerCase();

        if (extension == "png") {
          imageMimeType = "image/png";
        } else if (extension == "webp") {
          imageMimeType = "image/webp";
        } else if (extension == "jpg" ||
            extension == "jpeg") {
          imageMimeType = "image/jpeg";
        } else {
          throw Exception(
            "Unsupported image format.",
          );
        }
      } catch (e) {
        debugPrint(
          "Image read error: $e",
        );

        _showSnackBar(
          "Unable to read selected image.",
        );

        return;
      }
    }

    // ----------------------------------------------------------
    // ADD USER MESSAGE TO UI
    // ----------------------------------------------------------

    final temporaryUserMessage = {
      "id": "",
      "isUser": true,
      "message": message,
      "imagePath": imageToSend?.path,
      "hasImage": imageToSend != null,
    };

    setState(() {
      messages.add(
        temporaryUserMessage,
      );

      messageController.clear();
      selectedImage = null;
      isTyping = true;
    });

    scrollToBottom();

    // ----------------------------------------------------------
    // SAVE USER MESSAGE TO FIRESTORE
    // ----------------------------------------------------------

    final savedUserMessageId =
        await _saveMessage(
      message: message,
      isUser: true,
      hasImage: imageToSend != null,
    );

    if (savedUserMessageId != null &&
        mounted) {
      temporaryUserMessage["id"] =
          savedUserMessageId;
    }

    // ----------------------------------------------------------
    // LOAD PROFILE IF NEEDED
    // ----------------------------------------------------------

    try {
      if (!profileLoaded) {
        await _loadProfile();
      }

      final profile =
          Map<String, dynamic>.from(
        cachedProfile,
      );

      // --------------------------------------------------------
      // BUILD CHAT HISTORY FOR AI
      // --------------------------------------------------------

      final history =
          _buildAIHistory();

      // --------------------------------------------------------
      // REQUEST BODY
      // --------------------------------------------------------

      final Map<String, dynamic> requestBody = {
        "message": message,
        "profile": profile,
        "history": history,
      };

      if (imageBase64 != null) {
        requestBody["image"] = {
          "mimeType":
              imageMimeType ?? "image/jpeg",
          "data": imageBase64,
        };
      }

      final requestJson =
          jsonEncode(requestBody);

      debugPrint(
        "Sending AI request...",
      );

      // --------------------------------------------------------
      // API REQUEST
      // --------------------------------------------------------

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {
              "Content-Type":
                  "application/json",
              "Accept":
                  "application/json",
            },
            body: requestJson,
          )
          .timeout(
            const Duration(
              seconds: 90,
            ),
          );

      debugPrint(
        "AI response status: ${response.statusCode}",
      );

      if (response.statusCode != 200) {
        String serverMessage =
            "Server returned ${response.statusCode}";

        try {
          final errorData =
              jsonDecode(response.body);

          serverMessage =
              errorData["message"]
                      ?.toString() ??
                  serverMessage;
        } catch (_) {}

        throw Exception(
          serverMessage,
        );
      }

      // --------------------------------------------------------
      // RESPONSE
      // --------------------------------------------------------

      final data =
          jsonDecode(response.body);

      if (data["success"] != true) {
        throw Exception(
          data["message"]
                  ?.toString() ??
              "AI response failed.",
        );
      }

      final reply =
          data["reply"]?.toString() ??
              "Sorry, I couldn't generate a response.";

      if (!mounted) {
        return;
      }

      // --------------------------------------------------------
      // ADD AI MESSAGE TO UI
      // --------------------------------------------------------

      final temporaryAIMessage = {
        "id": "",
        "isUser": false,
        "message": reply,
        "imagePath": null,
        "hasImage": false,
      };

      setState(() {
        isTyping = false;

        messages.add(
          temporaryAIMessage,
        );
      });

      scrollToBottom();

      // --------------------------------------------------------
      // SAVE AI RESPONSE TO FIRESTORE
      // --------------------------------------------------------

      final savedAIMessageId =
          await _saveMessage(
        message: reply,
        isUser: false,
        hasImage: false,
      );

      if (savedAIMessageId != null &&
          mounted) {
        temporaryAIMessage["id"] =
            savedAIMessageId;
      }
    } catch (e, stackTrace) {
      debugPrint(
        "AI CHAT ERROR: $e",
      );

      debugPrint(
        "$stackTrace",
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isTyping = false;

        messages.add({
          "id": "",
          "isUser": false,
          "message":
              "Sorry, I couldn't connect to the AI right now.\n\n"
              "Please try again.",
          "imagePath": null,
          "hasImage": false,
        });
      });

      scrollToBottom();
    }
  }

  // ============================================================
  // BUILD AI HISTORY
  // ============================================================

  List<Map<String, dynamic>>
      _buildAIHistory() {
    final history =
        <Map<String, dynamic>>[];

    for (final item in messages) {
      final text =
          item["message"]?.toString() ??
              "";

      if (text.isEmpty) {
        continue;
      }

      final isUser =
          item["isUser"] == true;

      history.add({
        "role": isUser
            ? "user"
            : "assistant",
        "text": text,
      });
    }

    // Last 20 messages only.
    // This prevents a very large API request.
    if (history.length > 20) {
      return history.sublist(
        history.length - 20,
      );
    }

    return history;
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> pickImage() async {
    if (isTyping) {
      return;
    }

    try {
      final image =
          await imagePicker.pickImage(
        source:
            ImageSource.gallery,
        imageQuality: 30,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (image == null ||
          !mounted) {
        return;
      }

      final bytes =
          await image.readAsBytes();

      final sizeKB =
          bytes.length / 1024;

      debugPrint(
        "Selected image size: "
        "${sizeKB.toStringAsFixed(1)} KB",
      );

      if (bytes.length >
          2 * 1024 * 1024) {
        _showSnackBar(
          "Image is too large. Please select a smaller image.",
        );

        return;
      }

      setState(() {
        selectedImage = image;
      });
    } catch (e) {
      debugPrint(
        "Image picker error: $e",
      );

      _showSnackBar(
        "Unable to select image.",
      );
    }
  }

  // ============================================================
  // REMOVE SELECTED IMAGE
  // ============================================================

  void removeSelectedImage() {
    if (isTyping) {
      return;
    }

    setState(() {
      selectedImage = null;
    });
  }

  // ============================================================
  // CLEAR CHAT
  // ============================================================

  Future<void> clearChat() async {
    final user = auth.currentUser;

    if (user == null) {
      return;
    }

    final shouldClear =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title:
              const Text("Clear Chat"),
          content: const Text(
            "Are you sure you want to delete your complete AI chat history?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child:
                  const Text("Cancel"),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child:
                  const Text("Clear"),
            ),
          ],
        );
      },
    );

    if (shouldClear != true) {
      return;
    }

    try {
      final snapshot =
          await _chatCollection(
        user.uid,
      ).get();

      final batch =
          firestore.batch();

      for (final document
          in snapshot.docs) {
        batch.delete(
          document.reference,
        );
      }

      await batch.commit();

      if (!mounted) {
        return;
      }

      setState(() {
        messages.clear();
      });

      _addWelcomeMessage();

      _showSnackBar(
        "Chat history cleared.",
      );
    } catch (e) {
      debugPrint(
        "Clear chat error: $e",
      );

      _showSnackBar(
        "Unable to clear chat.",
      );
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void scrollToBottom() {
    Future.delayed(
      const Duration(
        milliseconds: 100,
      ),
      () {
        if (!scrollController
            .hasClients) {
          return;
        }

        scrollController.animateTo(
          scrollController
              .position
              .maxScrollExtent,
          duration:
              const Duration(
            milliseconds: 300,
          ),
          curve:
              Curves.easeOut,
        );
      },
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content:
            Text(message),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF6F7FB),

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        elevation: 0,
        backgroundColor:
            Colors.white,
        surfaceTintColor:
            Colors.white,

        leading: IconButton(
          icon: const Icon(
            Icons
                .arrow_back_ios_new,
            color:
                Color(0xff172033),
            size: 20,
          ),
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
        ),

        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                gradient:
                    const LinearGradient(
                  colors: [
                    Color(0xff667EEA),
                    Color(0xff764BA2),
                  ],
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  14,
                ),
              ),
              child:
                  const Icon(
                Icons
                    .smart_toy_outlined,
                color:
                    Colors.white,
                size: 23,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            const Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  "AI Career Mentor",
                  style:
                      TextStyle(
                    color:
                        Color(
                      0xff172033,
                    ),
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                SizedBox(
                  height: 2,
                ),

                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color:
                          Colors.green,
                    ),
                    SizedBox(
                      width: 5,
                    ),
                    Text(
                      "Online",
                      style:
                          TextStyle(
                        color:
                            Colors.green,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),

        actions: [
          IconButton(
            tooltip:
                "Clear Chat",
            icon: const Icon(
              Icons
                  .delete_outline,
              color:
                  Color(0xff172033),
            ),
            onPressed:
                isLoadingChat ||
                        isTyping
                    ? null
                    : clearChat,
          ),
        ],
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Column(
        children: [
          Expanded(
            child:
                isLoadingChat
                    ? const Center(
                        child:
                            CircularProgressIndicator(),
                      )
                    : ListView.builder(
                        controller:
                            scrollController,
                        padding:
                            const EdgeInsets
                                .fromLTRB(
                          16,
                          20,
                          16,
                          15,
                        ),
                        itemCount:
                            messages.length +
                                (isTyping
                                    ? 1
                                    : 0),
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          // ------------------------------------------------
                          // TYPING
                          // ------------------------------------------------

                          if (isTyping &&
                              index ==
                                  messages
                                      .length) {
                            return _typingIndicator();
                          }

                          // ------------------------------------------------
                          // MESSAGE
                          // ------------------------------------------------

                          final item =
                              messages[
                                  index];

                          final text =
                              item["message"]
                                      ?.toString() ??
                                  "";

                          final isUser =
                              item["isUser"] ==
                                  true;

                          final imagePath =
                              item["imagePath"]
                                  ?.toString();

                          final hasImage =
                              item["hasImage"] ==
                                  true;

                          return _messageBubble(
                            text,
                            isUser,
                            imagePath:
                                imagePath,
                            hasImage:
                                hasImage,
                          );
                        },
                      ),
          ),

          // ======================================================
          // SELECTED IMAGE PREVIEW
          // ======================================================

          if (selectedImage != null)
            Container(
              margin:
                  const EdgeInsets
                      .fromLTRB(
                16,
                0,
                16,
                8,
              ),
              padding:
                  const EdgeInsets.all(
                10,
              ),
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius
                        .circular(
                  16,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xffE2E5EC,
                  ),
                ),
              ),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius:
                        BorderRadius
                            .circular(
                      10,
                    ),
                    child:
                        Image.file(
                      File(
                        selectedImage!
                            .path,
                      ),
                      width: 55,
                      height: 55,
                      fit: BoxFit.cover,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  const Expanded(
                    child: Text(
                      "Image selected",
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed:
                        removeSelectedImage,
                    icon:
                        const Icon(
                      Icons.close,
                    ),
                  ),
                ],
              ),
            ),

          // ======================================================
          // INPUT
          // ======================================================

          _inputArea(),
        ],
      ),
    );
  }

  // ============================================================
  // INPUT AREA
  // ============================================================

  Widget _inputArea() {
    return SafeArea(
      top: false,
      child: Container(
        padding:
            const EdgeInsets
                .fromLTRB(
          12,
          10,
          12,
          10,
        ),
        decoration:
            const BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              blurRadius: 10,
              offset:
                  Offset(0, -3),
              color:
                  Color(0x10000000),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment
                  .end,
          children: [
            // ----------------------------------------------------
            // IMAGE
            // ----------------------------------------------------

            IconButton(
              onPressed:
                  isTyping
                      ? null
                      : pickImage,
              icon:
                  const Icon(
                Icons
                    .image_outlined,
                color:
                    Color(0xff667EEA),
              ),
            ),

            // ----------------------------------------------------
            // TEXT FIELD
            // ----------------------------------------------------

            Expanded(
              child:
                  Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 16,
                ),
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xffF5F6FA,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    25,
                  ),
                ),
                child:
                    TextField(
                  controller:
                      messageController,
                  enabled:
                      !isTyping,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction:
                      TextInputAction
                          .newline,
                  decoration:
                      const InputDecoration(
                    hintText:
                        "Ask anything about your career...",
                    border:
                        InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(
              width: 8,
            ),

            // ----------------------------------------------------
            // SEND
            // ----------------------------------------------------

            GestureDetector(
              onTap:
                  isTyping
                      ? null
                      : sendMessage,
              child:
                  Container(
                width: 48,
                height: 48,
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
                    16,
                  ),
                ),
                child:
                    Icon(
                  isTyping
                      ? Icons
                          .hourglass_top
                      : Icons
                          .send_rounded,
                  color:
                      Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _messageBubble(
    String text,
    bool isUser, {
    String? imagePath,
    bool hasImage = false,
  }) {
    return Align(
      alignment: isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        constraints:
            const BoxConstraints(
          maxWidth: 330,
        ),
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(
          14,
        ),
        decoration:
            BoxDecoration(
          gradient: isUser
              ? const LinearGradient(
                  colors: [
                    Color(
                      0xff667EEA,
                    ),
                    Color(
                      0xff764BA2,
                    ),
                  ],
                )
              : null,
          color: isUser
              ? null
              : Colors.white,
          borderRadius:
              BorderRadius.only(
            topLeft:
                const Radius
                    .circular(
              18,
            ),
            topRight:
                const Radius
                    .circular(
              18,
            ),
            bottomLeft:
                Radius.circular(
              isUser ? 18 : 4,
            ),
            bottomRight:
                Radius.circular(
              isUser ? 4 : 18,
            ),
          ),
          boxShadow:
              const [
            BoxShadow(
              blurRadius: 6,
              offset:
                  Offset(0, 2),
              color:
                  Color(0x0C000000),
            ),
          ],
        ),
        child:
            Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .start,
          children: [
            // ----------------------------------------------------
            // LOCAL IMAGE
            // ----------------------------------------------------

            if (imagePath != null &&
                imagePath.isNotEmpty)
              Padding(
                padding:
                    const EdgeInsets
                        .only(
                  bottom: 10,
                ),
                child:
                    ClipRRect(
                  borderRadius:
                      BorderRadius
                          .circular(
                    12,
                  ),
                  child:
                      Image.file(
                    File(
                      imagePath,
                    ),
                    width: 240,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (
                      context,
                      error,
                      stackTrace,
                    ) {
                      return Container(
                        width: 240,
                        height: 100,
                        alignment:
                            Alignment
                                .center,
                        decoration:
                            BoxDecoration(
                          color: isUser
                              ? Colors
                                  .white
                                  .withOpacity(
                                  0.15,
                                )
                              : const Color(
                                  0xffF3F4F8,
                                ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),
                        child:
                            Text(
                          "Image was sent",
                          style:
                              TextStyle(
                            color: isUser
                                ? Colors
                                    .white
                                : const Color(
                                    0xff666666,
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

            // ----------------------------------------------------
            // SAVED IMAGE INDICATOR
            // ----------------------------------------------------

            if (imagePath == null &&
                hasImage)
              Padding(
                padding:
                    const EdgeInsets
                        .only(
                  bottom: 8,
                ),
                child:
                    Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      Icons
                          .image_outlined,
                      size: 17,
                      color: isUser
                          ? Colors.white
                          : const Color(
                              0xff667EEA,
                            ),
                    ),
                    const SizedBox(
                      width: 6,
                    ),
                    Text(
                      "Image message",
                      style:
                          TextStyle(
                        color: isUser
                            ? Colors.white
                            : const Color(
                                0xff667EEA,
                              ),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

            // ----------------------------------------------------
            // TEXT
            // ----------------------------------------------------

            if (text.isNotEmpty)
              Text(
                text,
                style:
                    TextStyle(
                  color: isUser
                      ? Colors.white
                      : const Color(
                          0xff172033,
                        ),
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TYPING INDICATOR
  // ============================================================

  Widget _typingIndicator() {
    return Align(
      alignment:
          Alignment.centerLeft,
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets
                .symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          boxShadow:
              const [
            BoxShadow(
              blurRadius: 6,
              offset:
                  Offset(0, 2),
              color:
                  Color(0x0C000000),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            SizedBox(
              width: 8,
              height: 8,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(
              width: 10,
            ),
            Text(
              "AI is typing...",
              style:
                  TextStyle(
                color:
                    Color(0xff666666),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}