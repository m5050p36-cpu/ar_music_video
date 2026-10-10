import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:screen_brightness/screen_brightness.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/pip_service.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String title;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    required this.title,
  });

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _showControls = true;
  double _volume = 1.0;
  double _brightness = 0.5;
  bool _isLooping = false;
  double _speed = 1.0;

  bool _disposed = false;
  bool _isVideoTransitioning = false;

  // Throttling: 500ms
  DateTime _lastTick = DateTime.now();

  @override
  void initState() {
    super.initState();
    _initController();
    _initBrightness();
  }

  Future<void> _initController() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    _controller.addListener(_videoListener);
    await _controller.play();
    if (mounted) setState(() {});
  }

  void _videoListener() {
    if (_disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastTick).inMilliseconds >= 500) {
      _lastTick = now;
      if (mounted) setState(() {});
    }
  }

  Future<void> _initBrightness() async {
    try {
      _brightness = await ScreenBrightness().application;
    } catch (_) {}
  }

  void _handleVerticalDrag(DragUpdateDetails details, bool isLeft) async {
    final delta = -details.primaryDelta! / 200.0;
    if (isLeft) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      try {
        await ScreenBrightness().setApplicationScreenBrightness(_brightness);
      } catch (_) {}
    } else {
      _volume = (_volume + delta).clamp(0.0, 1.0);
      _controller.setVolume(_volume);
    }
    if (mounted) setState(() {});
  }

  void _seekRelative(int seconds) {
    if (_isVideoTransitioning) return;
    _isVideoTransitioning = true;
    final current = _controller.value.position;
    final target = current + Duration(seconds: seconds);
    _controller.seekTo(target).then((_) {
      _isVideoTransitioning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              onDoubleTapDown: (details) {
                if (details.localPosition.dx > constraints.maxWidth / 2) {
                  _seekRelative(10);
                } else {
                  _seekRelative(-10);
                }
              },
              child: Stack(
                children: [
                  Center(
                    child: RepaintBoundary(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),

                  Positioned(
                    left: 0,
                    top: 60,
                    bottom: 80,
                    width: constraints.maxWidth * 0.45,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (d) => _handleVerticalDrag(d, true),
                    ),
                  ),

                  Positioned(
                    right: 0,
                    top: 60,
                    bottom: 80,
                    width: constraints.maxWidth * 0.45,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (d) => _handleVerticalDrag(d, false),
                    ),
                  ),

                  if (_showControls) _buildControlsOverlay(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlsOverlay() {
    return Container(
      color: Colors.black45,
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 16)),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_in_picture_alt_rounded, color: Colors.white),
                tooltip: context.tr('player_pip'),
                onPressed: () {
                  final ar = _controller.value.aspectRatio;
                  PipService.enterPiP(
                    width: (ar * 100).toInt(),
                    height: 100,
                  );
                },
              ),
              PopupMenuButton<double>(
                initialValue: _speed,
                tooltip: context.tr('player_speed'),
                icon: const Icon(Icons.speed, color: Colors.white),
                onSelected: (s) {
                  setState(() => _speed = s);
                  _controller.setPlaybackSpeed(s);
                },
                itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((s) => PopupMenuItem(
                  value: s,
                  child: Text('${s}x'),
                )).toList(),
              ),
              IconButton(
                icon: Icon(_isLooping ? Icons.repeat_one : Icons.repeat, color: _isLooping ? Colors.indigoAccent : Colors.white),
                tooltip: context.tr('player_loop_video'),
                onPressed: () {
                  setState(() => _isLooping = !_isLooping);
                  _controller.setLooping(_isLooping);
                },
              ),
            ],
          ),

          const Spacer(),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay_10_rounded, color: Colors.white, size: 40),
                onPressed: () => _seekRelative(-10),
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 64,
                ),
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying ? _controller.pause() : _controller.play();
                  });
                },
              ),
              const SizedBox(width: 32),
              IconButton(
                icon: const Icon(Icons.forward_10_rounded, color: Colors.white, size: 40),
                onPressed: () => _seekRelative(10),
              ),
            ],
          ),

          const Spacer(),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text(
                  _formatDuration(_controller.value.position),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VideoProgressIndicator(
                    _controller,
                    allowScrubbing: true,
                    colors: const VideoProgressColors(
                      playedColor: Colors.indigoAccent,
                      bufferedColor: Colors.white24,
                      backgroundColor: Colors.white10,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDuration(_controller.value.duration),
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s < 10 ? '0' : ''}$s';
  }

  @override
  void dispose() {
    _disposed = true;
    _controller.removeListener(_videoListener);
    _controller.dispose();
    ScreenBrightness().resetApplicationScreenBrightness();
    super.dispose();
  }
}
