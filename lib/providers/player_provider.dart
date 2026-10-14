import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/volume_boost_service.dart';
import '../core/services/widget_service.dart';
import '../models/audio_track.dart';

enum CustomLoopMode { none, repeatOnce, repeatTwice, repeatThrice, repeatAll }

class PlayerProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  final List<AudioTrack> _playlist = [];
  final List<int> _shuffleHistory = [];
  int _currentIndex = -1;

  CustomLoopMode _loopMode = CustomLoopMode.repeatAll;
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
  String _boostKey = 'off';

  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<int?>? _indexSub;

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
  String get boostKey => _boostKey;

  PlayerProvider() {
    _initListeners();
    _loadBoost();
  }

  void _initListeners() {
    _stateSub = _player.playerStateStream.listen((state) {
      if (_disposed) return;
      notifyListeners();
    });

    // ═══ متابعة الفهرس — يعمل مع الإشعار ═══
    _indexSub = _player.currentIndexStream.listen((idx) {
      if (_disposed || idx == null) return;
      if (idx != _currentIndex) {
        _currentIndex = idx;
        _lastPositionSave = DateTime.now();

        final track = currentTrack;
        if (track != null) {
          WidgetService.updateNowPlaying(
            title: track.title,
            subtitle: track.artist,
          );
        }
        notifyListeners();
      }
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

  Future<void> _loadBoost() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _boostKey = prefs.getString('boost_key') ?? 'off';
      notifyListeners();
      await _applyBoost();
    } catch (_) {}
  }

  Future<void> setBoost(String key) async {
    if (!VolumeBoostService.levels.containsKey(key)) return;
    _boostKey = key;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('boost_key', key);
    } catch (_) {}
    await _applyBoost();
  }

  Future<void> _applyBoost() async {
    try {
      final millibels = VolumeBoostService.levels[_boostKey] ?? 0;
      if (millibels <= 0) {
        await VolumeBoostService.disable();
      } else {
        await VolumeBoostService.enable(
          sessionId: 0,
          millibels: millibels,
        );
      }
    } catch (e) {
      debugPrint('_applyBoost error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // setPlaylist — يستخدم ConcatenatingAudioSource
  // ═══════════════════════════════════════════════════════════════
  Future<void> setPlaylist(
    List<AudioTrack> tracks, {
    int startIndex = 0,
  }) async {
    if (tracks.isEmpty) return;

    _playlist
      ..clear()
      ..addAll(tracks);
    _currentIndex = startIndex.clamp(0, _playlist.length - 1);
    _shuffleHistory.clear();
    _lastPlaybackError = null;

    try {
      // ═══ ابنِ قائمة المصادر — كل الأغاني ═══
      final sources = _playlist.map((track) {
        final mediaItem = MediaItem(
          id: track.id,
          album: track.album.isNotEmpty ? track.album : 'ألبوم عام',
          title: track.title.isNotEmpty ? track.title : 'مقطع صوتي',
          artist: track.artist.isNotEmpty ? track.artist : 'فنان غير معروف',
        );

        return AudioSource.file(
          track.path,
          tag: mediaItem,
        );
      }).toList();

      // ═══ ConcatenatingAudioSource ═══
      final playlistSource = ConcatenatingAudioSource(
        children: sources,
        useLazyPreparation: true,
      );

      // ═══ حمّل الأغنية الأولى فقط (lazy) ═══
      await _player.setAudioSource(
        playlistSource,
        initialIndex: _currentIndex,
        initialPosition: Duration.zero,
      );

      await _player.setSpeed(_speed);

      // ═══ استعادة آخر موضع للأغنية الأولى ═══
      try {
        final prefs = await SharedPreferences.getInstance();
        final lastSecs =
            prefs.getInt('last_pos_${_playlist[_currentIndex].id}') ?? 0;
        if (lastSecs > 0) {
          await _player.seek(Duration(seconds: lastSecs));
        }
      } catch (_) {}

      // ═══ التكرار ═══
      _applyLoopMode();

      await _player.play();
      await _applyBoost();

      final track = currentTrack;
      if (track != null) {
        WidgetService.updateNowPlaying(
          title: track.title,
          subtitle: track.artist,
        );
      }

      notifyListeners();
    } catch (e, st) {
      _lastPlaybackError = 'خطأ في التشغيل: $e';
      debugPrint('❌ setPlaylist error: $e');
      if (kDebugMode) debugPrintStack(stackTrace: st);
      notifyListeners();
    }
  }

  Future<void> playTrackAtIndex(int index) async {
    if (index < 0 || index >= _playlist.length) return;
    if (index == _currentIndex && _player.playing) return;

    try {
      // إذا كانت القائمة محمّلة، انتقل فقط
      if (_player.audioSource is ConcatenatingAudioSource) {
        await _player.seek(Duration.zero, index: index);
        if (!_player.playing) await _player.play();
      } else {
        // أعد بناء القائمة
        await setPlaylist(_playlist, startIndex: index);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('playTrackAtIndex error: $e');
    }
  }

  void _applyLoopMode() {
    switch (_loopMode) {
      case CustomLoopMode.none:
        _player.setLoopMode(LoopMode.off);
        break;
      case CustomLoopMode.repeatOnce:
      case CustomLoopMode.repeatTwice:
      case CustomLoopMode.repeatThrice:
        _player.setLoopMode(LoopMode.one);
        break;
      case CustomLoopMode.repeatAll:
        _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  void playPrevious() {
    if (_player.hasPrevious) {
      _player.seekToPrevious();
    } else if (_playlist.isNotEmpty) {
      _player.seek(Duration.zero, index: _playlist.length - 1);
    }
  }

  void playNext() {
    if (_player.hasNext) {
      _player.seekToNext();
    } else if (_playlist.isNotEmpty) {
      _player.seek(Duration.zero, index: 0);
    }
  }

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
    _applyLoopMode();
    notifyListeners();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    if (!_isShuffle) _shuffleHistory.clear();
    _player.setShuffleModeEnabled(_isShuffle);
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
    _indexSub?.cancel();
    _abCheckTimer?.cancel();
    _sleepTimer?.cancel();
    VolumeBoostService.disable();
    _player.dispose();
    super.dispose();
  }
}
