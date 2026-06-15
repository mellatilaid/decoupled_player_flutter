import 'package:flutter/widgets.dart';

abstract class CustomVideoPlayerService {
  ValueNotifier<bool> get isPlaying;
  ValueNotifier<Duration> get position;
  ValueNotifier<Duration> get duration;
  ValueNotifier<bool> get isInitialized;

  Future<void> initialize(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seekTo(Duration position);
  Widget buildVideoWidget(); // Returns the actual player UI widget
  Future<void> dispose();
}
