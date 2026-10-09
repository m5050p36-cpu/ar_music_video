/// ⚠️ هذا الملف هو المصدر الوحيد لبيانات Supabase.
/// عند تغيير المشروع، عدّل هنا فقط.
class SupabaseConfig {
  SupabaseConfig._();

  /// رابط مشروع Supabase (بدون / في النهاية)
  static const String projectUrl = 'https://sutkfwtisqgjgxmyovup.supabase.co';

  /// المفتاح العام (publishable / anon)
  static const String publishableKey =
      'sb_publishable_PTXJ1ojVFoDNlr8t3UOh9Q_UMBj9AYS';

  /// رابط Edge Function لتغيير كلمة المرور
  static const String changePasswordFunctionUrl =
      '$projectUrl/functions/v1/admin-change-password';

  /// Timeout افتراضي لكل استدعاء شبكي
  static const Duration timeout = Duration(seconds: 15);

  /// قنوات الإشعارات (يجب أن تطابق AndroidManifest + MainActivity.kt)
  static const String notificationChannelId = 'com.m5050p36.armusic.channel.audio';
  static const String notificationChannelName = 'AR Music Playback';
}
