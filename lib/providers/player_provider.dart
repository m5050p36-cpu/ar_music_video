import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audio_track.dart';

enum CustomLoopMode {
  none,         // بدون تكرار
  repeatOnce,   // تكرار مرة واحدة
  repeatTwice,  // تكرار مرتين
  repeatThrice, // تكرار 3 مرات
  repeatAll,    // تكرار الكل
}

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  List<AudioTrack> _playlist = [];
  int _currentIndex = -1;

  CustomLoopMode _loopMode = CustomLoopMode.repeatAll;
  int _currentTrackRepeatCounter = 0;
  bool _isShuffle = false;
  double _speed = 1.0;

  // A-B Repeat
  Duration? _pointA;
  Duration? _pointB;
  Timer? _abCheckTimer;

  // Sleep Timer
  Timer? _sleepTimer;
  Duration? _remainingSleepDuration;

  // Throttling
  DateTime _lastPositionSave = DateTime.now();
  bool _disposed = false;

  AudioPlayer get player => _player;
  List<AudioTrack> get playlist => _playlist;
  int get currentIndex => _currentIndex;
  AudioTrack? get currentTrack => (_currentIndex >= 0 && _currentIndex < _playlist.length) ? _playlist[_currentIndex] : null;
  CustomLoopMode get loopMode => _loopMode;
  bool get isShuffle => _isShuffle;
  double get speed => _speed;
  Duration? get pointA => _pointA;
  Duration? get pointB => _pointB;
  Duration? get remainingSleepDuration => _remainingSleepDuration;

  PlayerProvider() {
    _initListeners();
  }

  void _initListeners() {
    // مراقبة انتهاء المقطع لتطبيق أوضاع التكرار الخمسة
    _player.playerStateStream.listen((state) {
      if (_disposed) return;
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompletion();
      }
      notifyListeners();
    });

    // Throttling: حفظ آخر موضع تشغيل كل 30 ثانية فقط
    _player.positionStream.listen((position) {
      if (_disposed) return;
      final now = DateTime.now();
      if (now.difference(_lastPositionSave).inSeconds >= 30) {
        _lastPositionSave = now;
        _saveLastPosition(position);
      }
    });

    // فحص A-B Repeat كل 300ms
    _abCheckTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (_disposed || !_player.playing) return;
      if (_pointA != null && _pointB != null) {
        if (_player.position >= _pointB!) {
          _player.seek(_pointA!);
        }
      }
    });
  }

  Future<void> setPlaylist(List<AudioTrack> tracks, {int startIndex = 0}) async {
    _playlist = tracks;
    _currentIndex = startIndex;
    if (_playlist.isNotEmpty) {
      await playTrackAtIndex(_currentIndex);
    }
  }

  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    _currentIndex = index;
    _currentTrackRepeatCounter = 0;
    final track = _playlist[index];

    try {
      final mediaItem = MediaItem(
        id: track.id,
        album: track.album,
        title: track.title,
        artist: track.artist,
        artUri: track.albumArtUri != null ? Uri.parse(track.albumArtUri!) : null,
      );

      final audioSource = AudioSource.uri(
        Uri.file(track.path),
        tag: mediaItem,
      );

      await _player.setAudioSource(audioSource);
      await _player.setSpeed(_speed);

      // استعادة آخر موضع تم تشغيله إذا وجد
      final prefs = await SharedPreferences.getInstance();
      final lastSecs = prefs.getInt('last_pos_${track.id}') ?? 0;
      if (lastSecs > 0) {
        await _player.seek(Duration(seconds: lastSecs));
      }

      await _player.play();
      notifyListeners();
    } catch (e) {
      debugPrint('Error playing track: $e');
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
    int next = _currentIndex + 1;
    if (next >= _playlist.length) next = 0;
    playTrackAtIndex(next);
  }

  void playPrevious() {
    if (_playlist.isEmpty) return;
    int prev = _currentIndex - 1;
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

  // أوامر A-B Repeat
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

  // مؤقت النوم
  void setSleepTimer(int minutes) {
    _sleepTimer?.cancel();
    _remainingSleepDuration = Duration(minutes: minutes);
    notifyListeners();

    _sleepTimer = Timer(Duration(minutes: minutes), () {
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_pos_${current.id}', pos.inSeconds);
  }

  @override
  void dispose() {
    _disposed = true;
    _abCheckTimer?.cancel();
    _sleepTimer?.cancel();
    _player.dispose();
    super.dispose();
  }
}
