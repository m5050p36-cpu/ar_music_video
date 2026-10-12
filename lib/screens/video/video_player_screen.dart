import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../core/services/pip_service.dart';
import '../../core/services/volume_boost_service.dart';
import '../../models/video_item.dart';

enum _AspectMode { fit, fill, stretch }

class VideoPlayerScreen extends StatefulWidget {
  final String videoPath;
  final String title;
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

  // حالة الواجهة
  bool _showControls = true;
  bool _isLocked = false;
  bool _isLooping = false;
  bool _isShuffle = false;
  bool _isLongPressActive = false;
  double _speed = 1.0;
  double _volume = 1.0;
  double _brightness = 0.5;
  int _currentIndex = 0;
  _AspectMode _aspectMode = _AspectMode.fit;
  String _boostKey = 'off';

  // المؤقتات
  Timer? _controlsTimer;
  Timer? _positionSaveTimer;
  Timer? _sleepTimer;
  Duration? _remainingSleep;

  // حماية
  bool _disposed = false;
  bool _isVideoTransitioning = false;
  DateTime _lastTick = DateTime.now();
  final Random _rand = Random();

  bool get _hasPlaylist =>
      widget.playlist != null && widget.playlist!.length > 1;

  // ═══════════════ الحياة ═══════════════

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _initController();
    _initBrightness();
    _startPositionAutoSave();
  }

  @override
  void dispose() {
    _disposed = true;
    _controlsTimer?.cancel();
    _positionSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _savePositionNow();
    _controller.removeListener(_videoListener);
    _controller.dispose();
    WakelockPlus.disable();
    ScreenBrightness().resetApplicationScreenBrightness();
    super.dispose();
  }

  // ═══════════════ Initialization ═══════════════

  Future<void> _initController() async {
    _controller = VideoPlayerController.file(File(widget.videoPath));
    await _controller.initialize();
    _controller.addListener(_videoListener);
    _controller.setLooping(_isLooping);
    _controller.setVolume(_volume);
    await _restorePosition();
    await _controller.play();
    WakelockPlus.enable();
    if (mounted) setState(() {});
    _startControlsTimer();
  }

  Future<void> _initBrightness() async {
    try {
      _brightness = await ScreenBrightness().application;
    } catch (_) {}
  }

  // ═══════════════ حفظ واستعادة الموضع ═══════════════

  String get _posKey => 'vpos_${widget.videoPath}';

  Future<void> _restorePosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_posKey) ?? 0;
      if (saved > 5 &&
          _controller.value.duration.inSeconds > 0 &&
          saved < _controller.value.duration.inSeconds - 10) {
        await _controller.seekTo(Duration(seconds: saved));
      }
    } catch (_) {}
  }

  Future<void> _savePositionNow() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sec = _controller.value.position.inSeconds;
      final total = _controller.value.duration.inSeconds;
      // لا تحفظ إن كان في البداية أو في النهاية
      if (sec > 5 && total > 0 && sec < total - 10) {
        await prefs.setInt(_posKey, sec);
      } else if (sec >= total - 5) {
        // شوهد كاملًا — امسح الموضع
        await prefs.remove(_posKey);
      }
    } catch (_) {}
  }

  void _startPositionAutoSave() {
    _positionSaveTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        if (!_disposed) _savePositionNow();
      },
    );
  }

  // ═══════════════ Listener ═══════════════

  void _videoListener() {
    if (_disposed) return;

    final value = _controller.value;

    // النهاية → التالي
    if (value.position >= value.duration &&
        value.duration > Duration.zero &&
        !_isLooping) {
      _playNext();
      return;
    }

    // throttle الواجهة
    final now = DateTime.now();
    if (now.difference(_lastTick).inMilliseconds >= 500) {
      _lastTick = now;
      if (mounted) setState(() {});
    }
  }

  // ═══════════════ إخفاء تلقائي لأزرار التحكم ═══════════════

  void _startControlsTimer() {
    _controlsTimer?.cancel();
    if (!_controller.value.isPlaying) return; // لا تخفِ عند الإيقاف
    _controlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller.value.isPlaying) {
        setState(() => _showControls = false);
      }
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startControlsTimer();
  }

  void _bumpControls() {
    if (!_showControls) setState(() => _showControls = true);
    _startControlsTimer();
  }

  // ═══════════════ التنقل ═══════════════

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
      await _savePositionNow();
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
      await _restorePosition();
      await _controller.play();
      WakelockPlus.enable();
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('loadVideoAt error: $e');
    }
  }

  // ═══════════════ السرعة الطويلة ═══════════════

  void _startLongPress() {
    _isLongPressActive = true;
    _controller.setPlaybackSpeed(2.0);
    _bumpControls();
  }

  void _endLongPress() {
    _isLongPressActive = false;
    _controller.setPlaybackSpeed(_speed);
  }

  // ═══════════════ الإيماءات ═══════════════

  void _handleVerticalDrag(DragUpdateDetails details, bool isLeft) {
    final delta = -details.primaryDelta! / 200.0;
    if (isLeft) {
      _brightness = (_brightness + delta).clamp(0.0, 1.0);
      ScreenBrightness()
          .setApplicationScreenBrightness(_brightness)
          .catchError((_) {});
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
    _bumpControls();
  }

  // ═══════════════ قفل الشاشة ═══════════════

  void _toggleLock() {
    setState(() {
      _isLocked = !_isLocked;
      if (_isLocked) _showControls = false;
    });
  }

  // ═══════════════ مشاركة ═══════════════

  Future<void> _shareVideo() async {
    try {
      final path = _hasPlaylist
          ? widget.playlist![_currentIndex].path
          : widget.videoPath;
      final title = _hasPlaylist
          ? widget.playlist![_currentIndex].title
          : widget.title;
      await Share.shareXFiles(
        [XFile(path)],
        subject: title,
      );
    } catch (e) {
      debugPrint('share error: $e');
    }
  }

  // ═══════════════ مؤقت النوم ═══════════════

  void _showSleepTimerDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const Text(
              'مؤقت النوم',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [15, 30, 45, 60, 90, 120].map((m) {
                return ChoiceChip(
                  label: Text(
                    m >= 60 ? '${m ~/ 60} ساعة' : '$m دقيقة',
                    style: const TextStyle(color: Colors.white),
                  ),
                  selected: false,
                  selectedColor: Colors.indigoAccent,
                  backgroundColor: Colors.white24,
                  onSelected: (_) {
                    _setSleepTimer(m);
                    Navigator.pop(ctx);
                  },
                );
              }).toList(),
            ),
            if (_remainingSleep != null)
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.redAccent),
                title: const Text(
                  'إلغاء المؤقت',
                  style: TextStyle(color: Colors.redAccent),
                ),
                subtitle: Text(
                  'المتبقي: ${_remainingSleep!.inMinutes} دقيقة',
                  style: const TextStyle(color: Colors.white54),
                ),
                onTap: () {
                  _cancelSleepTimer();
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _remainingSleep = Duration(minutes: minutes);
    setState(() {});
    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (_disposed) return;
      _controller.pause();
      WakelockPlus.disable();
      _remainingSleep = null;
      if (mounted) setState(() {});
    });
  }

  void _cancelSleepTimer() {
    _sleepTimer?.cancel();
    _remainingSleep = null;
    if (mounted) setState(() {});
  }

  // ═══════════════ Aspect Ratio ═══════════════

  void _cycleAspect() {
    setState(() {
      _aspectMode = _AspectMode.values[
          (_aspectMode.index + 1) % _AspectMode.values.length];
    });
    _bumpControls();
  }

  String _aspectLabel() {
    switch (_aspectMode) {
      case _AspectMode.fit:
        return 'ملء تلقائي';
      case _AspectMode.fill:
        return 'قص للحواف';
      case _AspectMode.stretch:
        return 'تمديد';
    }
  }

  // ═══════════════ البناء ═══════════════

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
              behavior: HitTestBehavior.translucent,
              onTap: _isLocked ? null : _toggleControls,
              onDoubleTapDown: _isLocked
                  ? null
                  : (d) {
                      if (d.localPosition.dx > constraints.maxWidth / 2) {
                        _seekRelative(10);
                      } else {
                        _seekRelative(-10);
                      }
                    },
              onLongPressStart: _isLocked ? null : (_) => _startLongPress(),
              onLongPressEnd: _isLocked ? null : (_) => _endLongPress(),
              child: Stack(
                children: [
                  _buildVideo(),
                  if (!_isLocked) ...[
                    // يمين: الصوت
                    Positioned(
                      right: 0,
                      top: 60,
                      bottom: 80,
                      width: constraints.maxWidth * 0.4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: (d) =>
                            _handleVerticalDrag(d, false),
                      ),
                    ),
                    // يسار: السطوع
                    Positioned(
                      left: 0,
                      top: 60,
                      bottom: 80,
                      width: constraints.maxWidth * 0.4,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onVerticalDragUpdate: (d) =>
                            _handleVerticalDrag(d, true),
                      ),
                    ),
                  ],
                  if (_isLocked)
                    _buildLockOverlay()
                  else if (_showControls)
                    _buildControlsOverlay(currentTitle, constraints),
                  // مؤشر تغيير السطوع/الصوت
                  if (!_isLocked && !_isLongPressActive && _showControls)
                    _buildVolumeBrightnessIndicator(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildVideo() {
    final v = _controller.value;
    switch (_aspectMode) {
      case _AspectMode.fit:
        return Center(
          child: AspectRatio(
            aspectRatio: v.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        );
      case _AspectMode.fill:
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: v.size.width,
              height: v.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        );
      case _AspectMode.stretch:
        return SizedBox.expand(
          child: VideoPlayer(_controller),
        );
    }
  }

  // ═══════════════ مؤشر السطوع/الصوت ═══════════════

  Widget _buildVolumeBrightnessIndicator() {
    // يظهر فقط أثناء السحب الفعلي — نضيف حالة إن أردت
    return const SizedBox.shrink();
  }

  // ═══════════════ شاشة القفل ═══════════════

  Widget _buildLockOverlay() {
    return Positioned(
      left: 16,
      top: 0,
      bottom: 0,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(40),
            onTap: _toggleLock,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.lock_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════ أزرار التحكم ═══════════════

  Widget _buildControlsOverlay(String title, BoxConstraints c) {
    return Container(
      color: Colors.black.withValues(alpha: 0.45),
      child: Column(
        children: [
          // ═══ الشريط العلوي ═══
          AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              if (_isLongPressActive)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Chip(
                    label: Text('2x', style: TextStyle(color: Colors.white)),
                    backgroundColor: Colors.indigoAccent,
                  ),
                ),
              if (_remainingSleep != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Chip(
                    avatar: const Icon(Icons.bedtime,
                        size: 14, color: Colors.white),
                    label: Text(
                      '${_remainingSleep!.inMinutes}د',
                      style: const TextStyle(color: Colors.white),
                    ),
                    backgroundColor: Colors.deepPurple,
                  ),
                ),
              if (_hasPlaylist)
                IconButton(
                  icon: Icon(
                    Icons.shuffle,
                    color: _isShuffle ? Colors.indigoAccent : Colors.white,
                  ),
                  tooltip: 'تقليب عشوائي',
                  onPressed: () {
                    setState(() => _isShuffle = !_isShuffle);
                    _bumpControls();
                  },
                ),
              IconButton(
                icon: Icon(
                  _isLooping ? Icons.repeat_one : Icons.repeat,
                  color: _isLooping ? Colors.indigoAccent : Colors.white,
                ),
                tooltip: 'تكرار الفيديو',
                onPressed: () {
                  setState(() => _isLooping = !_isLooping);
                  _controller.setLooping(_isLooping);
                  _bumpControls();
                },
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (val) {
                  switch (val) {
                    case 'aspect':
                      _cycleAspect();
                      break;
                    case 'speed':
                      _showSpeedDialog();
                      break;
                    case 'share':
                      _shareVideo();
                      break;
                    case 'sleep':
                      _showSleepTimerDialog();
                      break;
                    case 'pip':
                      final ar = _controller.value.aspectRatio;
                      PipService.enterPiP(
                        width: (ar * 100).toInt(),
                        height: 100,
                      );
                      break;
                    case 'lock':
                      _toggleLock();
                      break;
                    case 'boost:off':
                    case 'boost:x1_5':
                    case 'boost:x2':
                    case 'boost:x2_5':
                    case 'boost:x3':
                      _setBoost(val.substring(6));
                      break;
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'aspect',
                    child: Row(
                      children: [
                        const Icon(Icons.aspect_ratio, size: 20),
                        const SizedBox(width: 10),
                        Text('العرض: ${_aspectLabel()}'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'speed',
                    child: Row(
                      children: [
                        const Icon(Icons.speed, size: 20),
                        const SizedBox(width: 10),
                        Text('السرعة: ${_speed}x'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'share',
                    child: Row(
                      children: [
                        Icon(Icons.share, size: 20),
                        SizedBox(width: 10),
                        Text('مشاركة'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'sleep',
                    child: Row(
                      children: [
                        Icon(Icons.bedtime_outlined, size: 20),
                        SizedBox(width: 10),
                        Text('مؤقت النوم'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'pip',
                    child: Row(
                      children: [
                        Icon(Icons.picture_in_picture_alt_rounded, size: 20),
                        SizedBox(width: 10),
                        Text('نافذة عائمة'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'lock',
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline, size: 20),
                        SizedBox(width: 10),
                        Text('قفل الشاشة'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: 'noop2',
                    enabled: false,
                    child: Row(
                      children: [
                        Icon(Icons.volume_up_rounded, size: 18),
                        SizedBox(width: 8),
                        Text('مضاعفة الصوت',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  ..._videoBoostItems(),
                ],
              ),
            ],
          ),

          const Spacer(),

          // ═══ أزرار التنقل ═══
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.replay_10_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () => _seekRelative(-10),
              ),
              const SizedBox(width: 8),
              if (_hasPlaylist)
                IconButton(
                  icon: const Icon(
                    Icons.skip_previous_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                  onPressed: _playPrevious,
                ),
              const SizedBox(width: 16),
              // التشغيل
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_filled_rounded,
                  color: Colors.white,
                  size: 72,
                ),
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                      WakelockPlus.disable();
                      _controlsTimer?.cancel();
                    } else {
                      _controller.play();
                      WakelockPlus.enable();
                      _startControlsTimer();
                    }
                  });
                },
              ),
              const SizedBox(width: 16),
              if (_hasPlaylist)
                IconButton(
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                  onPressed: _playNext,
                ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(
                  Icons.forward_10_rounded,
                  color: Colors.white,
                  size: 36,
                ),
                onPressed: () => _seekRelative(10),
              ),
            ],
          ),

          const Spacer(),

          // ═══ شريط التقدم ═══
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

  void _showSpeedDialog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سرعة التشغيل',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
                    .map((s) {
                  final selected = (_speed - s).abs() < 0.01;
                  return ChoiceChip(
                    label: Text(
                      '${s}x',
                      style: TextStyle(
                        color:
                            selected ? Colors.white : Colors.white70,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    selected: selected,
                    selectedColor: Colors.indigoAccent,
                    backgroundColor: Colors.white24,
                    onSelected: (_) {
                      setState(() => _speed = s);
                      _controller.setPlaybackSpeed(s);
                      Navigator.pop(ctx);
                      _bumpControls();
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  List<PopupMenuEntry<String>> _videoBoostItems() {
    final options = [
      ('off', 'بدون'),
      ('x1_5', '1.5x'),
      ('x2', '2x'),
      ('x2_5', '2.5x'),
      ('x3', '3x'),
    ];
    return options.map((o) {
      final selected = _boostKey == o.$1;
      return PopupMenuItem<String>(
        value: 'boost:${o.$1}',
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              size: 18,
              color: selected ? Colors.green : null,
            ),
            const SizedBox(width: 8),
            Text(o.$2),
          ],
        ),
      );
    }).toList();
  }

  Future<void> _setBoost(String key) async {
    _boostKey = key;
    if (mounted) setState(() {});
    try {
      final mB = VolumeBoostService.levels[key] ?? 0;
      if (mB <= 0) {
        await VolumeBoostService.disable();
      } else {
        // video_player لا يكشف audioSessionId — session 0 (global mix)
        await VolumeBoostService.enable(
          sessionId: 0,
          millibels: mB,
        );
      }
    } catch (e) {
      debugPrint('_setBoost error: $e');
    }
    _bumpControls();
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s < 10 ? '0' : ''}$s';
  }
}
