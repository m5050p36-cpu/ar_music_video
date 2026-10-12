import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:video_player/video_player.dart';

import '../../core/services/pip_service.dart';
import '../../models/video_item.dart';

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String title;

  /// قائمة التشغيل (اختياري)
  final List<VideoItem>? playlist;
  final int initialIndex;

  const VideoPlayerScreen({
    super.key,
    required this.videoPath,
    required this.title,
    this.playlist,
    this.initialIndex = 0,
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
  bool _isShuffle = false;
  double _speed = 1.0;
  int _currentIndex = 0;

  bool _disposed = false;
  bool _isVideoTransitioning = false;

  DateTime _lastTick = DateTime.now();
  final Random _rand = Random();

  bool get _hasPlaylist =>
      widget.playlist != null && widget.playlist!.length > 1;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initController();
    _initBrightness();
  }

  Future<void> _initController() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    _controller.addListener(_videoListener);
    _controller.setLooping(_isLooping);
    await _controller.play();
    if (mounted) setState(() {});
  }

  void _videoListener() {
    if (_disposed) return;

    // عند انتهاء الفيديو → التالي
    final value = _controller.value;
    if (value.position >= value.duration &&
        value.duration > Duration.zero &&
        !_isLooping) {
      _playNext();
      return;
    }

    // throttle الـ setState
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

  // ═══ التنقل بين الفيديوهات ═══

  Future<void> _playNext() async {
    if (!_hasPlaylist || _isVideoTransitioning) return;

    _isVideoTransitioning = true;

    int next;
    if (_isShuffle) {
      if (widget.playlist!.length == 1) {
        next = 0;
      } else {
        var attempts = 0;
        do {
          next = _rand.nextInt(widget.playlist!.length);
          attempts++;
        } while (next == _currentIndex && attempts < 10);
      }
    } else {
      next = _currentIndex + 1;
      if (next >= widget.playlist!.length) next = 0;
    }

    await _loadVideoAt(next);
    _isVideoTransitioning = false;
  }

  Future<void> _playPrevious() async {
    if (!_hasPlaylist || _isVideoTransitioning) return;

    _isVideoTransitioning = true;
    var prev = _currentIndex - 1;
    if (prev < 0) prev = widget.playlist!.length - 1;

    await _loadVideoAt(prev);
    _isVideoTransitioning = false;
  }

  Future<void> _loadVideoAt(int index) async {
    try {
      _controller.removeListener(_videoListener);
      await _controller.dispose();

      _currentIndex = index;
      final path = widget.playlist![index].path;

      _controller = VideoPlayerController.file(File(path));
      await _controller.initialize();
      _controller.addListener(_videoListener);
      _controller.setLooping(_isLooping);
      _controller.setVolume(_volume);
      _controller.setPlaybackSpeed(_speed);
      await _controller.play();

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('loadVideoAt error: $e');
    }
  }

  void _handleVerticalDrag(DragUpdateDetails details, bool isLeft) async {
    final delta = -details.primaryDelta! / 200.0;
    if (isLeft) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      try {
        await ScreenBrightness()
            .setApplicationScreenBrightness(_brightness);
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
    }).catchError((_) {
      _isVideoTransitioning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final currentTitle = _hasPlaylist
        ? widget.playlist![_currentIndex].title
        : widget.title;

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
                  // منطقة السحب العمودي الأيسر (سطوع)
                  Positioned(
                    left: 0,
                    top: 60,
                    bottom: 80,
                    width: constraints.maxWidth * 0.45,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (d) =>
                          _handleVerticalDrag(d, true),
                    ),
                  ),
                  // منطقة السحب العمودي الأيمن (صوت)
                  Positioned(
                    right: 0,
                    top: 60,
                    bottom: 80,
                    width: constraints.maxWidth * 0.45,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onVerticalDragUpdate: (d) =>
                          _handleVerticalDrag(d, false),
                    ),
                  ),
                  if (_showControls) _buildControlsOverlay(currentTitle),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildControlsOverlay(String currentTitle) {
    return Container(
      color: Colors.black45,
      child: Column(
        children: [
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              currentTitle,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              // ═══ زر التقليب العشوائي ═══
              if (_hasPlaylist)
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: _isShuffle ? Colors.indigoAccent : Colors.white,
                  ),
                  tooltip: 'تقليب عشوائي',
                  onPressed: () =>
                      setState(() => _isShuffle = !_isShuffle),
                ),
              // PiP
              IconButton(
                icon: const Icon(
                  Icons.picture_in_picture_alt_rounded,
                  color: Colors.white,
                ),
                tooltip: 'PiP',
                onPressed: () {
                  final ar = _controller.value.aspectRatio;
                  PipService.enterPiP(
                    width: (ar * 100).toInt(),
                    height: 100,
                  );
                },
              ),
              // سرعة
              PopupMenuButton<double>(
                initialValue: _speed,
                icon: const Icon(Icons.speed, color: Colors.white),
                onSelected: (s) {
                  setState(() => _speed = s);
                  _controller.setPlaybackSpeed(s);
                },
                itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
                    .map((s) => PopupMenuItem(
                          value: s,
                          child: Text('${s}x'),
                        ))
                    .toList(),
              ),
              // تكرار
              IconButton(
                icon: Icon(
                  _isLooping ? Icons.repeat_one : Icons.repeat,
                  color: _isLooping ? Colors.indigoAccent : Colors.white,
                ),
                tooltip: 'تكرار الفيديو',
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
              // السابق (إن كان playlist)
              if (_hasPlaylist)
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _playPrevious,
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.replay_10_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: () => _seekRelative(-10),
                ),
              const SizedBox(width: 24),
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 64,
                ),
                onPressed: () {
                  setState(() {
                    _controller.value.isPlaying
                        ? _controller.pause()
                        : _controller.play();
                  });
                },
              ),
              const SizedBox(width: 24),
              // التالي (إن كان playlist)
              if (_hasPlaylist)
                IconButton(
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: _playNext,
                )
              else
                IconButton(
                  icon: const Icon(
                    Icons.forward_10_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                  onPressed: () => _seekRelative(10),
                ),
            ],
          ),
          const Spacer(),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
