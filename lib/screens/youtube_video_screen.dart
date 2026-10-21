import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YouTubeVideoScreen extends StatefulWidget {
  final String videoId;
  final String? playlistId;
  final String title;
  final String channelTitle;

  const YouTubeVideoScreen({
    super.key,
    required this.videoId,
    this.playlistId,
    required this.title,
    required this.channelTitle,
  });

  @override
  State<YouTubeVideoScreen> createState() =>
      _YouTubeVideoScreenState();
}

class _YouTubeVideoScreenState
    extends State<YouTubeVideoScreen> {
  YoutubePlayerController? controller;

  bool isLoading = true;
  bool hasError = false;

  @override
  void initState() {
    super.initState();

    debugPrint(
      '========================================',
    );

    debugPrint(
      'YouTube Video Screen',
    );

    debugPrint(
      'Video ID: ${widget.videoId}',
    );

    debugPrint(
      'Playlist ID: ${widget.playlistId}',
    );

    debugPrint(
      '========================================',
    );

    _initializePlayer();
  }

  void _initializePlayer() {
    final videoId = widget.videoId.trim();

    if (videoId.isEmpty) {
      debugPrint(
        'ERROR: YouTube Video ID is empty',
      );

      setState(() {
        isLoading = false;
        hasError = true;
      });

      return;
    }

    try {
      controller = YoutubePlayerController.fromVideoId(
        videoId: videoId,
        autoPlay: true,
        params: const YoutubePlayerParams(
          showControls: true,
          showFullscreenButton: true,
          mute: false,
          loop: false,
          strictRelatedVideos: false,
          enableJavaScript: true,
          playsInline: true,
          showVideoAnnotations: false,
        ),
      );

      setState(() {
        isLoading = false;
        hasError = false;
      });

      debugPrint(
        'YouTube Player initialized successfully.',
      );
    } catch (error) {
      debugPrint(
        'YouTube Player Error: $error',
      );

      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  void _retryPlayer() {
    controller?.close();

    setState(() {
      controller = null;
      isLoading = true;
      hasError = false;
    });

    _initializePlayer();
  }

  @override
  void dispose() {
    controller?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F8FC),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        iconTheme: const IconThemeData(
          color: Color(0xff172033),
        ),

        title: const Text(
          'Now Learning',
          style: TextStyle(
            color: Color(0xff172033),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SafeArea(
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [

            // =====================================================
            // YOUTUBE PLAYER
            // =====================================================

            Container(
              width: double.infinity,
              color: Colors.black,

              child: AspectRatio(
                aspectRatio: 16 / 9,

                child: _buildPlayer(),
              ),
            ),

            // =====================================================
            // CONTENT
            // =====================================================

            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.all(18),

                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [

                    // =================================================
                    // TITLE
                    // =================================================

                    Text(
                      widget.title,
                      style:
                          const TextStyle(
                        fontSize: 20,
                        fontWeight:
                            FontWeight.bold,
                        color:
                            Color(0xff172033),
                        height: 1.3,
                      ),
                    ),

                    const SizedBox(
                      height: 10,
                    ),

                    // =================================================
                    // CHANNEL
                    // =================================================

                    Row(
                      children: [

                        Container(
                          width: 38,
                          height: 38,

                          decoration:
                              const BoxDecoration(
                            gradient:
                                LinearGradient(
                              colors: [
                                Color(
                                  0xff667EEA,
                                ),
                                Color(
                                  0xff764BA2,
                                ),
                              ],
                            ),
                            shape:
                                BoxShape.circle,
                          ),

                          child: const Icon(
                            Icons
                                .play_arrow_rounded,
                            color:
                                Colors.white,
                            size: 22,
                          ),
                        ),

                        const SizedBox(
                          width: 10,
                        ),

                        Expanded(
                          child: Text(
                            widget.channelTitle,
                            style:
                                const TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w600,
                              color:
                                  Color(
                                0xff687086,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 24,
                    ),

                    // =================================================
                    // LEARNING TIP
                    // =================================================

                    Container(
                      width:
                          double.infinity,

                      padding:
                          const EdgeInsets.all(
                        17,
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
                          18,
                        ),
                      ),

                      child: const Row(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                        children: [

                          Icon(
                            Icons
                                .lightbulb_outline_rounded,
                            color:
                                Color(
                              0xff667EEA,
                            ),
                          ),

                          SizedBox(
                            width: 11,
                          ),

                          Expanded(
                            child: Text(
                              'Watch the course and learn at your own pace. Use the fullscreen button for a better learning experience.',

                              style:
                                  TextStyle(
                                fontSize: 12,
                                height: 1.5,
                                color:
                                    Color(
                                  0xff4B5270,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===============================================================
  // PLAYER
  // ===============================================================

  Widget _buildPlayer() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Colors.white,
        ),
      );
    }

    if (hasError ||
        controller == null) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            const Icon(
              Icons
                  .error_outline_rounded,
              color: Colors.white70,
              size: 48,
            ),

            const SizedBox(
              height: 12,
            ),

            const Text(
              'Unable to load video',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight:
                    FontWeight.w600,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            ElevatedButton.icon(
              onPressed: _retryPlayer,

              icon: const Icon(
                Icons.refresh_rounded,
              ),

              label: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      );
    }

    return YoutubePlayer(
      controller: controller!,
      aspectRatio: 16 / 9,
    );
  }
}