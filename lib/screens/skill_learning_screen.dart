import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'youtube_video_screen.dart';

class SkillLearningScreen extends StatefulWidget {
  final String skill;

  const SkillLearningScreen({
    super.key,
    required this.skill,
  });

  @override
  State<SkillLearningScreen> createState() =>
      _SkillLearningScreenState();
}

class _SkillLearningScreenState
    extends State<SkillLearningScreen> {
 static const String apiUrl =
    'https://career-ai-backend-fk2i.onrender.com/api/learning-playlist';

  bool isLoading = true;
  String? errorMessage;
  List<LearningPlaylist> playlists = [];

  @override
  void initState() {
    super.initState();
    loadPlaylists();
  }

  Future<void> loadPlaylists() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final uri = Uri.parse(apiUrl).replace(
        queryParameters: {
          'skill': widget.skill,
        },
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 45));

      if (response.statusCode != 200) {
        throw Exception(
          'Server returned ${response.statusCode}',
        );
      }

      final decoded = jsonDecode(response.body);

      if (decoded['success'] != true) {
        throw Exception(
          decoded['message']?.toString() ??
              'Unable to load learning playlists.',
        );
      }

      final rawPlaylists = decoded['playlists'];

      if (rawPlaylists is! List || rawPlaylists.isEmpty) {
        throw Exception(
          'No playlists found for ${widget.skill}.',
        );
      }

      final loaded = rawPlaylists
          .whereType<Map>()
          .map(
            (item) => LearningPlaylist.fromJson(
              Map<String, dynamic>.from(item),
            ),
          )
          .where(
            (playlist) =>
                playlist.playlistId.isNotEmpty,
          )
          .toList();

      if (loaded.isEmpty) {
        throw Exception('No valid playlists found.');
      }

      if (!mounted) return;

      setState(() {
        playlists = loaded;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Playlist loading error: $e');

      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            'Unable to find learning playlists for ${widget.skill}.';
      });
    }
  }

  Future<void> openPlaylist(
    LearningPlaylist playlist,
  ) async {
    await saveSelectedPlaylist(playlist);

    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => YouTubeVideoScreen(
          videoId: playlist.firstVideoId,
          playlistId: playlist.playlistId,
          title: playlist.title,
          channelTitle: playlist.channelTitle,
        ),
      ),
    );
  }

  Future<void> saveSelectedPlaylist(
    LearningPlaylist playlist,
  ) async {
    try {
      final user =
          FirebaseAuth.instance.currentUser;

      if (user == null) return;

      final skillKey = widget.skill
          .toLowerCase()
          .replaceAll(
            RegExp(r'[^a-z0-9]+'),
            '_',
          );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'learningPreferences': {
            skillKey: {
              'skill': widget.skill,
              'playlistId': playlist.playlistId,
              'firstVideoId':
                  playlist.firstVideoId,
              'playlistTitle':
                  playlist.title,
              'channelTitle':
                  playlist.channelTitle,
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          },
        },
        SetOptions(merge: true),
      );
    } catch (e) {
      debugPrint(
        'Save playlist error: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xffF7F8FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme:
            const IconThemeData(
          color: Color(0xff172033),
        ),
        title: Text(
          '${widget.skill} Learning',
          style: const TextStyle(
            color: Color(0xff172033),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh courses',
            onPressed:
                isLoading ? null : loadPlaylists,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: isLoading
          ? _buildLoading()
          : errorMessage != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: loadPlaylists,
                  child: ListView(
                    padding:
                        const EdgeInsets.fromLTRB(
                      16,
                      18,
                      16,
                      30,
                    ),
                    children: [
                      _buildHeader(),
                      const SizedBox(
                        height: 20,
                      ),
                      _buildInfoCard(),
                      const SizedBox(
                        height: 24,
                      ),
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Available Courses',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight:
                                    FontWeight.bold,
                                color:
                                    Color(0xff172033),
                              ),
                            ),
                          ),
                          Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  const Color(
                                0xffEEF1FF,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                10,
                              ),
                            ),
                            child: Text(
                              '${playlists.length}',
                              style:
                                  const TextStyle(
                                color:
                                    Color(
                                  0xff667EEA,
                                ),
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 12,
                      ),
                      ...playlists.asMap().entries.map(
                        (entry) =>
                            _buildPlaylistCard(
                          entry.value,
                          entry.key,
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 38,
            height: 38,
            child:
                CircularProgressIndicator(
              strokeWidth: 3,
              color: Color(0xff667EEA),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Finding courses for you...',
            style: TextStyle(
              fontSize: 15,
              color: Color(0xff687086),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.video_library_outlined,
              size: 55,
              color: Color(0xff667EEA),
            ),
            const SizedBox(height: 14),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xff596176),
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: loadPlaylists,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text('Try Again'),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xff667EEA),
                foregroundColor:
                    Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient:
            const LinearGradient(
          colors: [
            Color(0xff667EEA),
            Color(0xff764BA2),
          ],
        ),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white
                  .withValues(
                alpha: 0.16,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Learn ${widget.skill}',
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                const SizedBox(
                  height: 5,
                ),
                const Text(
                  'Choose a course and start learning.',
                  style:
                      TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xffEEF1FF),
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.play_circle_outline_rounded,
            color: Color(0xff667EEA),
          ),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'Courses are discovered from YouTube. Tap a course to open the dedicated video screen.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xff4B5270),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylistCard(
    LearningPlaylist playlist,
    int index,
  ) {
    return InkWell(
      onTap: () =>
          openPlaylist(playlist),
      borderRadius:
          BorderRadius.circular(19),
      child: Container(
        margin:
            const EdgeInsets.only(
          bottom: 14,
        ),
        padding:
            const EdgeInsets.all(12),
        decoration:
            BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(19),
          border: Border.all(
            color: const Color(
              0xffE5E7EF,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              blurRadius: 9,
              offset: Offset(0, 4),
              color: Color(0x0D000000),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              child: SizedBox(
                width: 125,
                height: 78,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.network(
                      playlist.thumbnail,
                      fit: BoxFit.cover,
                      errorBuilder:
                          (_, __, ___) {
                        return Container(
                          color:
                              const Color(
                            0xffE8EAF2,
                          ),
                          child:
                              const Icon(
                            Icons
                                .image_not_supported_outlined,
                            color:
                                Color(
                              0xff8C93A5,
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      color: Colors.black
                          .withValues(
                        alpha: 0.16,
                      ),
                      child:
                          const Center(
                        child: Icon(
                          Icons
                              .play_circle_fill_rounded,
                          color:
                              Colors.white,
                          size: 38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(
              width: 13,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xffEEF1FF,
                          ),
                          borderRadius:
                              BorderRadius
                                  .circular(
                            7,
                          ),
                        ),
                        child: Text(
                          '#${index + 1}',
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xff667EEA,
                            ),
                            fontSize: 10,
                            fontWeight:
                                FontWeight
                                    .bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Icon(
                        Icons
                            .chevron_right_rounded,
                        color:
                            Color(
                          0xff8A91A3,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(
                    height: 7,
                  ),
                  Text(
                    playlist.title,
                    maxLines: 2,
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        const TextStyle(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.bold,
                      color:
                          Color(
                        0xff172033,
                      ),
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(
                    height: 7,
                  ),
                  Row(
                    children: [
                      const Icon(
                        Icons
                            .person_outline_rounded,
                        size: 14,
                        color:
                            Color(
                          0xff8A91A3,
                        ),
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Expanded(
                        child: Text(
                          playlist
                              .channelTitle,
                          maxLines: 1,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          style:
                              const TextStyle(
                            fontSize: 11,
                            color:
                                Color(
                              0xff687086,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LearningPlaylist {
  final String playlistId;
  final String firstVideoId;
  final String title;
  final String description;
  final String channelTitle;
  final String thumbnail;
  final String publishedAt;

  const LearningPlaylist({
    required this.playlistId,
    required this.firstVideoId,
    required this.title,
    required this.description,
    required this.channelTitle,
    required this.thumbnail,
    required this.publishedAt,
  });

  factory LearningPlaylist.fromJson(
    Map<String, dynamic> json,
  ) {
    return LearningPlaylist(
      playlistId:
          json['playlistId']?.toString() ??
              '',
      firstVideoId:
          json['firstVideoId']?.toString() ??
              '',
      title:
          json['title']?.toString() ??
              'Untitled Course',
      description:
          json['description']?.toString() ??
              '',
      channelTitle:
          json['channelTitle']?.toString() ??
              'Unknown Channel',
      thumbnail:
          json['thumbnail']?.toString() ??
              '',
      publishedAt:
          json['publishedAt']?.toString() ??
              '',
    );
  }
}
