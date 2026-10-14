import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// خدمة PiP — تعرض أزرار تحكم داخل النافذة العائمة.
///
/// أزرار النظام التي تظهر داخل PiP:
///  - السابق (Prev)
///  - تشغيل/إيقاف مؤقت (Play/Pause)
///  - التالي (Next)
class PipService {
  PipService._();

  static const MethodChannel _channel =
      MethodChannel('com.m5050p36.armusic/pip');

  // ═══ Callbacks يضعها المشغل ═══
  static VoidCallback? onPlayPause;
  static VoidCallback? onNext;
  static VoidCallback? onPrevious;

  static bool _handlerSet = false;

  /// يُسجَّل مرة واحدة فقط
  static void _ensureHandler() {
    if (_handlerSet) return;
    _handlerSet = true;

    _channel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'onPiPPlayPause':
          onPlayPause?.call();
          break;
        case 'onPiPNext':
          onNext?.call();
          break;
        case 'onPiPPrev':
          onPrevious?.call();
          break;
      }
      return null;
    });
  }

  /// ادخل PiP — يستدعيها المشغل عند الزر
  static Future<bool> enterPiP({int width = 16, int height = 9}) async {
    _ensureHandler();
    try {
      final result = await _channel.invokeMethod<bool>('enterPiP', {
        'aspectRatioWidth': width,
        'aspectRatioHeight': height,
      });
      return result ?? false;
    } catch (e) {
      debugPrint('PipService.enterPiP error: $e');
      return false;
    }
  }

  /// يُحدّث حالة الأزرار المعروضة في PiP.
  /// استدعِها كل مرة تتغير حالة التشغيل أو وجود التالي/السابق.
  static Future<bool> updateControls({
    required bool isPlaying,
    required bool hasNext,
    required bool hasPrev,
  }) async {
    _ensureHandler();
    try {
      final ok = await _channel.invokeMethod<bool>('updatePiPControls', {
        'isPlaying': isPlaying,
        'hasNext': hasNext,
        'hasPrev': hasPrev,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('PipService.updateControls error: $e');
      return false;
    }
  }

  static Future<bool> isSupported() async {
    try {
      final supported = await _channel.invokeMethod<bool>('isPiPSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }

  /// نظّف الـ callbacks (عند dispose الشاشة)
  static void clearCallbacks() {
    onPlayPause = null;
    onNext = null;
    onPrevious = null;
  }
}
