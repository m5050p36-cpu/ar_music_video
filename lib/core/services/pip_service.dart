import 'package:flutter/services.dart';

class PipService {
  static const MethodChannel _channel = MethodChannel('com.yourapp.armusic/pip');

  static Future<bool> enterPiP({int width = 16, int height = 9}) async {
    try {
      final bool? result = await _channel.invokeMethod('enterPiP', {
        'aspectRatioWidth': width,
        'aspectRatioHeight': height,
      });
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isSupported() async {
    try {
      final bool? supported = await _channel.invokeMethod('isPiPSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }
}
