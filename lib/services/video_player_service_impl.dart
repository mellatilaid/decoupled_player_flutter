import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart'
    as pkg; // Aliased to keep it separated

import 'video_player_serivce.dart';

class VideoPlayerServiceImpl implements CustomVideoPlayerService {
  pkg.VideoPlayerController? _controller;

  @override
  final ValueNotifier<bool> isPlaying = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<Duration> position = ValueNotifier<Duration>(
    Duration.zero,
  );
  @override
  final ValueNotifier<Duration> duration = ValueNotifier<Duration>(
    Duration.zero,
  );
  @override
  final ValueNotifier<bool> isInitialized = ValueNotifier<bool>(false);

  @override
  Future<void> initialize(String url) async {
    _controller = pkg.VideoPlayerController.networkUrl(Uri.parse(url));

    await _controller!.initialize();
    isInitialized.value = true;
    duration.value = _controller!.value.duration;

    await play();

    // Listen to changes from the package and update our clean ValueNotifiers
    _controller!.addListener(() {
      isPlaying.value = _controller!.value.isPlaying;
      position.value = _controller!.value.position;
    });
  }

  @override
  Future<void> play() async => await _controller?.play();

  @override
  Future<void> pause() async => await _controller?.pause();

  @override
  Future<void> seekTo(Duration pos) async => await _controller?.seekTo(pos);

  @override
  Widget buildVideoWidget() {
    if (_controller != null && _controller!.value.isInitialized) {
      return AspectRatio(
        aspectRatio: _controller!.value.aspectRatio,
        child: pkg.VideoPlayer(_controller!),
      );
    }
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Future<void> dispose() async {
    isPlaying.dispose();
    position.dispose();
    duration.dispose();
    isInitialized.dispose();
    await _controller?.dispose();
  }
}
