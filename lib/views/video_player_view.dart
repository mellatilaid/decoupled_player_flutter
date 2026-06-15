import 'package:flutter/material.dart';

import '../services/video_player_serivce.dart';

class VideoPlayerView extends StatefulWidget {
  // You would ideally inject this via GetIt or your state management framework
  final CustomVideoPlayerService playerService;
  final String videoUrl;

  const VideoPlayerView({
    super.key,
    required this.playerService,
    required this.videoUrl,
  });

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  @override
  void initState() {
    super.initState();
    widget.playerService.initialize(widget.videoUrl);
  }

  @override
  void dispose() {
    widget.playerService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Decoupled Video Player')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. The Video Render Area
          ValueListenableBuilder<bool>(
            valueListenable: widget.playerService.isInitialized,
            builder: (context, isInitialized, _) {
              return isInitialized
                  ? widget.playerService.buildVideoWidget()
                  : const AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Center(child: CircularProgressIndicator()),
                    );
            },
          ),

          // 2. Custom Controls built purely from our Service contract
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ValueListenableBuilder<bool>(
                valueListenable: widget.playerService.isPlaying,
                builder: (context, isPlaying, _) {
                  return IconButton(
                    icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                    onPressed: () {
                      isPlaying
                          ? widget.playerService.pause()
                          : widget.playerService.play();
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
