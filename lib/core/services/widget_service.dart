import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class WidgetService {
  WidgetService._();

  static const _androidProvider =
      'com.m5050p36.armusic.ArMusicWidgetProvider';

  /// يُحدّث محتوى الودجت — يُستدعى عند تغيير الأغنية
  static Future<void> updateNowPlaying({
    required String title,
    required String subtitle,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('current_title', title);
      await HomeWidget.saveWidgetData<String>('current_subtitle', subtitle);
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
      );
    } catch (e) {
      debugPrint('WidgetService.updateNowPlaying error: $e');
    }
  }

  static Future<void> clear() async {
    try {
      await HomeWidget.saveWidgetData<String>(
        'current_title',
        'AR Music & Video',
      );
      await HomeWidget.saveWidgetData<String>(
        'current_subtitle',
        'مشغل الوسائط',
      );
      await HomeWidget.updateWidget(
        androidName: _androidProvider,
      );
    } catch (_) {}
  }
}
