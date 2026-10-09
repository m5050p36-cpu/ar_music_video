import 'package:flutter/services.dart';

class PipService {
  PipService._();

  static const MethodChannel _channel =
      MethodChannel('com.m5050p36.armusic/pip');

  static Future<bool> enterPiP({int width = 16, int height = 9}) async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPiP', {
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
      final supported = await _channel.invokeMethod<bool>('isPiPSupported');
      return supported ?? false;
    } catch (_) {
      return false;
    }
  }
}
