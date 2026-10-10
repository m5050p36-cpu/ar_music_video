import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/audio_track.dart';

enum CustomLoopMode { none, repeatOnce, repeatTwice, repeatThrice, repeatAll }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final List<AudioTrack> _playlist = [];
  int _currentIndex = -1;

  CustomLoopMode _loopMode = CustomLoopMode.repeatAll;
  int _currentTrackRepeatCounter = 0;
  bool _isShuffle = false;
  double _speed = 1.0;

  Duration? _pointA;
  Duration? _pointB;
  Timer? _abCheckTimer;
  Timer? _sleepTimer;
  Duration? _remainingSleepDuration;

  DateTime _lastPositionSave = DateTime.now();
  bool _disposed = false;
  String? _lastPlaybackError;

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;

  AudioPlayer get player => _player;
  List<AudioTrack> get playlist => List.unmodifiable(_playlist);
  int get currentIndex => _currentIndex;
  AudioTrack? get currentTrack =>
      (_currentIndex >= 0 && _currentIndex < _playlist.length)
          ? _playlist[_currentIndex]
          : null;
  CustomLoopMode get loopMode => _loopMode;
  bool get isShuffle => _isShuffle;
  double get speed => _speed;
  Duration? get pointA => _pointA;
  Duration? get pointB => _pointB;
  Duration? get remainingSleepDuration => _remainingSleepDuration;
  String? get lastPlaybackError => _lastPlaybackError;

  PlayerProvider() {
    _initListeners();
  }

  void _initListeners() {
    _stateSub = _player.playerStateStream.listen((state) {
      if (_disposed) return;
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompletion();
      }
      notifyListeners();
    });

    _positionSub = _player.positionStream.listen((position) {
      if (_disposed) return;
      final now = DateTime.now();
      if (now.difference(_lastPositionSave).inSeconds >= 30) {
        _lastPositionSave = now;
        _saveLastPosition(position);
      }
    });

    _abCheckTimer = Timer.periodic(
      const Duration(milliseconds: 300),
      (_) {
        if (_disposed || !_player.playing) return;
        if (_pointA != null && _pointB != null) {
          if (_player.position >= _pointB!) {
            _player.seek(_pointA!);
          }
        }
      },
    );
  }

  Future<void> setPlaylist(
    List<AudioTrack> tracks, {
    int startIndex = 0,
  }) async {
    _playlist
      ..clear()
      ..addAll(tracks);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    if (_playlist.isNotEmpty) {
      await playTrackAtIndex(_currentIndex);
    }
  }

  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    _currentTrackRepeatCounter = 0;
    _lastPlaybackError = null;

    final track = _playlist[index];

    // تحقق أن الملف موجود فعلًا
    try {
      final exists = await File(track.path).exists();
      if (!exists) {
        _lastPlaybackError = 'الملف غير موجود: ${track.path}';
        debugPrint('❌ File not found: ${track.path}');
        notifyListeners();
        return;
      }
    } catch (e) {
      debugPrint('File check error: $e');
    }

    try {
      debugPrint('▶️ Playing: ${track.title} | path=${track.path}');

      final mediaItem = MediaItem(
        id: track.id,
        album: track.album.isNotEmpty ? track.album : 'ألبوم عام',
        title: track.title.isNotEmpty ? track.title : 'مقطع صوتي',
        artist: track.artist.isNotEmpty ? track.artist : 'فنان غير معروف',
      );

      // File URI — لا نستخدم Uri.parse لأن المسار قد يحتوي على أحرف خاصة
      final audioSource = AudioSource.file(
        track.path,
        tag: mediaItem,
      );

      await _player.setAudioSource(audioSource);
      await _player.setSpeed(_speed);

      // استعادة آخر موضع
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastSecs = prefs.getInt('last_pos_${track.id}') ?? 0;
        if (lastSecs > 0) {
          await _player.seek(Duration(seconds: lastSecs));
        }
      } catch (_) {}

      await _player.play();
      notifyListeners();
      debugPrint('✅ Playing started');
    } catch (e, st) {
      _lastPlaybackError = 'خطأ في التشغيل: $e';
      debugPrint('❌ playTrackAtIndex error: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
      notifyListeners();
    }
  }

  void _handleTrackCompletion() {
    switch (_loopMode) {
      case CustomLoopMode.repeatOnce:
        if (_currentTrackRepeatCounter < 1) {
          _currentTrackRepeatCounter++;
          _player.seek(Duration.zero);
          _player.play();
        } else {
          _playNextTrack();
        }
        break;
      case CustomLoopMode.repeatTwice:
        if (_currentTrackRepeatCounter < 2) {
          _currentTrackRepeatCounter++;
          _player.seek(Duration.zero);
          _player.play();
        } else {
          _playNextTrack();
        }
        break;
      case CustomLoopMode.repeatThrice:
        if (_currentTrackRepeatCounter < 3) {
          _currentTrackRepeatCounter++;
          _player.seek(Duration.zero);
          _player.play();
        } else {
          _playNextTrack();
        }
        break;
      case CustomLoopMode.repeatAll:
        _playNextTrack();
        break;
      case CustomLoopMode.none:
        if (_currentIndex < _playlist.length - 1) {
          _playNextTrack();
        } else {
          _player.stop();
        }
        break;
    }
  }

  void _playNextTrack() {
    if (_playlist.isEmpty) return;
    var next = _currentIndex + 1;
    if (next >= _playlist.length) next = 0;
    playTrackAtIndex(next);
  }

  void playPrevious() {
    if (_playlist.isEmpty) return;
    var prev = _currentIndex - 1;
    if (prev < 0) prev = _playlist.length - 1;
    playTrackAtIndex(prev);
  }

  void playNext() => _playNextTrack();

  void togglePlayPause() {
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
    notifyListeners();
  }

  void setPlaybackSpeed(double spd) {
    _speed = spd.clamp(0.5, 3.0);
    _player.setSpeed(_speed);
    notifyListeners();
  }

  void toggleLoopMode() {
    final nextIndex = (_loopMode.index + 1) % CustomLoopMode.values.length;
    _loopMode = CustomLoopMode.values[nextIndex];
    _currentTrackRepeatCounter = 0;
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    notifyListeners();
  }

  void setPointA() {
    _pointA = _player.position;
    notifyListeners();
  }

  void setPointB() {
    if (_pointA != null && _player.position > _pointA!) {
      _pointB = _player.position;
      notifyListeners();
    }
  }

  void clearABRepeat() {
    _pointA = null;
    _pointB = null;
    notifyListeners();
  }

  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _remainingSleepDuration = Duration(minutes: minutes);
    notifyListeners();

    _sleepTimer = Timer(Duration(minutes: minutes), () {
      if (_disposed) return;
      _player.pause();
      _remainingSleepDuration = null;
      notifyListeners();
    });
  }

  void cancelSleepTimer() {
    _sleepTimer?.cancel();
    _remainingSleepDuration = null;
    notifyListeners();
  }

  Future<void> _saveLastPosition(Duration pos) async {
    final current = currentTrack;
    if (current == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('last_pos_${current.id}', pos.inSeconds);
    } catch (_) {}
  }

  @override
  void dispose() {
    _disposed = true;
    _stateSub?.cancel();
    _positionSub?.cancel();
    _abCheckTimer?.cancel();
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
