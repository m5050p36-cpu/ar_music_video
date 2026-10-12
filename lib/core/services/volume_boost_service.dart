import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// مضاعفة الصوت عبر Android LoudnessEnhancer
class VolumeBoostService {
  VolumeBoostService._();

  static const _channel =
      MethodChannel('com.m5050p36.armusic/volume_boost');

  /// مستوى المضاعفة بالأميال-ديسيبل:
  /// 0     = بدون مضاعفة
  /// 1000  = +10 dB
  /// 2000  = +20 dB
  /// 3000  = +30 dB
  static const Map<String, int> levels = {
    'off': 0,
    'x1_5': 500,   // +5 dB
    'x2': 1000,    // +10 dB
    'x2_5': 1500,  // +15 dB
    'x3': 2000,    // +20 dB
  };

  static Future<bool> enable({
    required int sessionId,
    required int millibels,
  }) async {
    try {
      if (millibels <= 0) return await disable();
      final ok = await _channel.invokeMethod<bool>('enableBoost', {
        'sessionId': sessionId,
        'millibels': millibels,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('VolumeBoost.enable error: $e');
      return false;
    }
  }

  static Future<bool> disable() async {
    try {
      final ok = await _channel.invokeMethod<bool>('disableBoost');
      return ok ?? false;
    } catch (e) {
      debugPrint('VolumeBoost.disable error: $e');
      return false;
    }
  }
}
