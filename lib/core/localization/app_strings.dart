import 'package:flutter/widgets.dart';

/// نظام الترجمة المركزي — ar + en
/// الاستخدام:  context.tr('key')
class AppStrings {
  AppStrings._();

  static const Map<String, String> _ar = {
    'app_name': 'AR Music & Video',

    // Drawer
    'drawer_admin_panel': 'لوحة الإدارة المشرفة',
    'drawer_profile': 'الملف الشخصي',
    'drawer_privacy': 'سياسة الخصوصية',
    'drawer_about': 'حول التطبيق',
    'drawer_logout': 'تسجيل الخروج',
    'drawer_guest': 'وضع الزائر',
    'drawer_user': 'مستخدم',
    'drawer_offline': 'وضع عدم الاتصال (Offline)',

    // Tabs
    'tab_audio': 'الصوتيات',
    'tab_videos': 'الفيديوهات',

    // Login / SignUp
    'login_title': 'تسجيل الدخول',
    'signup_title': 'إنشاء حساب جديد',
    'email_label': 'البريد الإلكتروني',
    'password_label': 'كلمة المرور',
    'fullname_label': 'الاسم الكامل',
    'login_button': 'دخول',
    'signup_button': 'إنشاء الحساب',
    'guest_button': 'المتابعة كزائر (بدون تسجيل)',
    'forgot_password': 'نسيت كلمة المرور؟ (تواصل عبر Telegram)',
    'switch_to_signup': 'ليس لديك حساب؟ إنشاء حساب جديد',
    'switch_to_login': 'لديك حساب بالفعل؟ تسجيل الدخول',
    'fill_email_password': 'يرجى إدخال البريد وكلمة المرور',
    'fill_fullname': 'يرجى إدخال الاسم الكامل',

    // Audio
    'audio_library': 'مكتبة الصوتيات',
    'audio_all': 'جميع الصوتيات',
    'audio_folders': 'المجلدات',
    'audio_favorites': 'المفضلة',
    'audio_scanning': 'جاري فحص ملفات الجهاز...',
    'audio_empty': 'لا توجد ملفات صوتية في الجهاز.',
    'audio_refresh': 'إعادة الفحص',
    'audio_tracks': 'مقطع',
    'audio_unknown_artist': 'فنان غير معروف',
    'audio_unknown_album': 'ألبوم عام',

    // Video
    'video_library': 'مكتبة الفيديوهات',
    'video_all': 'جميع الفيديوهات',
    'video_albums': 'الألبومات',
    'video_scanning': 'جاري فحص فيديوهات الجهاز...',
    'video_empty': 'لا توجد فيديوهات في الجهاز.',
    'video_grid_view': 'عرض كشبكة',
    'video_list_view': 'عرض كقائمة',
    'video_videos': 'فيديو',
    'video_default_folder': 'فيديوهات',

    // Player
    'player_no_track': 'لا يوجد مقطع قيد التشغيل',
    'player_sleep_timer': 'مؤقت النوم',
    'player_speed': 'سرعة التشغيل',
    'player_loop_none': 'بدون تكرار',
    'player_loop_once': 'مرة',
    'player_loop_twice': 'مرتين',
    'player_loop_thrice': '3 مرات',
    'player_loop_all': 'الكل',
    'player_point_a': 'نقطة A',
    'player_point_b': 'نقطة B',

    // Profile
    'profile_title': 'الملف الشخصي',
    'profile_role_admin': 'مشرف',
    'profile_role_guest': 'زائر',
    'profile_role_user': 'مستخدم',
    'profile_save': 'حفظ التعديلات',
    'profile_change_photo': 'تغيير الصورة',
    'profile_photo_gallery': 'من المعرض',
    'profile_photo_camera': 'من الكاميرا',
    'profile_photo_remove': 'إزالة الصورة',
    'profile_email_label': 'البريد الإلكتروني',
    'profile_name_label': 'الاسم الكامل',
    'profile_updated': '✅ تم تحديث البيانات',
    'profile_avatar_updated': '✅ تم تحديث الصورة',
    'profile_avatar_failed': 'فشل تحديث الصورة',
    'profile_no_connection': 'لا يوجد اتصال',
    'profile_guest_cant_edit': 'لا يمكن التعديل في وضع الزائر',

    // Admin
    'admin_title': 'لوحة الإدارة المشرفة',
    'admin_tab_users': 'المستخدمين',
    'admin_tab_banners': 'البنرات',
    'admin_tab_versions': 'الإصدارات',

    // Banner editor
    'banner_new': 'إضافة بنر جديد',
    'banner_edit': 'تعديل البنر',
    'banner_save': 'حفظ',
    'banner_image': 'صورة البنر',
    'banner_no_image': 'لم تُختَر صورة بعد',
    'banner_from_gallery': 'من المعرض',
    'banner_from_camera': 'من الكاميرا',
    'banner_title_label': 'الاسم (اختياري)',
    'banner_title_hint': 'اتركه فارغًا إن لم ترغب بعرض نص',
    'banner_link_label': 'رابط التوجيه (اختياري)',
    'banner_order_label': 'ترتيب العرض (1 = أولًا)',
    'banner_height': 'ارتفاع البنر',
    'banner_active': 'مُفعّل',
    'banner_active_sub': 'سيظهر للمستخدمين عند التفعيل',
    'banner_add_button': 'إضافة البنر',
    'banner_save_button': 'حفظ التعديلات',
    'banner_deleted': '✅ تم الحذف',
    'banner_saved': '✅ تم الحفظ',
    'banner_delete_title': 'حذف البنر؟',
    'banner_delete_body': 'سيتم حذف البنر وصورته نهائيًا. لا يمكن التراجع.',
    'banner_add_fab': 'إضافة بنر',
    'banner_empty': 'لا توجد بنرات مضافة بعد',
    'banner_disabled': 'معطّل',
    'banner_select_image': 'الرجاء اختيار صورة للبنر',
    'banner_upload_failed': 'فشل رفع الصورة — تحقق من الإنترنت والصلاحيات',
    'banner_save_failed': 'فشل الحفظ — تحقق من الصلاحيات',

    // Common
    'common_cancel': 'إلغاء',
    'common_save': 'حفظ',
    'common_delete': 'حذف',
    'common_edit': 'تعديل',
    'common_retry': 'إعادة المحاولة',
    'common_refresh': 'تحديث',
    'common_loading': 'جاري التحميل...',
    'common_error': 'خطأ',
    'common_ok': 'موافق',
    'common_confirm': 'تأكيد',
    'common_close': 'إغلاق',
    'common_tap_to_open': 'اضغط للفتح',
    // Full Player (إضافات)
    'player_full_title': 'المشغل الصوتي',
    'player_cancel_timer': 'إلغاء المؤقت',
    'player_hour': 'ساعة',
    'player_minute': 'دقيقة',
    'player_pip': 'تشغيل في نافذة عائمة (PiP)',
    'player_loop_video': 'تكرار الفيديو',

    // Common إضافات
    'common_success': 'تم بنجاح',
    'common_failed': 'فشل',

    // About
    'about_version': 'الإصدار: 1.0.0 (ARM64)',
    'about_body':
        'مشغل وسائط عالي الأداء مبني بواسطة Flutter و Supabase و Kotlin '
            'لنظام Android مع دعم التشغيل في الخلفية وميزة PiP.',
    'about_title_short': 'AR Music & Video',

    // Privacy
    'privacy_body':
        'سياسة الخصوصية لتطبيق AR Music & Video:\n\n'
            '• التطبيق يحترم خصوصيتك بالكامل ويعمل بدون إنترنت (Offline).\n'
            '• لا يتم إرسال أو مشاركة ملفاتك الصوتية أو فيديوهاتك الخاصة مع أي خادم خارجي.\n'
            '• يتم تخزين الإعدادات المفضلة والمواضع الأخيرة على جهازك محليًا عبر SharedPreferences.\n'
            '• عند تسجيل حساب، تُحفظ بيانات بريدك واسمك بأمان على Supabase مع سياسات RLS مشفرة.',

    // Admin إضافات
    'admin_search_hint': 'بحث بالبريد أو الاسم...',
    'admin_role_user': 'مستخدم عادي (user)',
    'admin_role_admin': 'مشرف (admin)',
    'admin_role_superuser': 'مدير نظام (superuser)',
    'admin_change_password_for': 'تغيير كلمة مرور',
    'admin_new_password_label': 'كلمة المرور الجديدة',
    'admin_change_now': 'تغيير الآن',
    'admin_edit_role_title': 'تعديل صلاحية المستخدم',
    'admin_password_updated': 'تم تحديث كلمة المرور فوريًا',
    'admin_role_updated': 'تم تحديث الصلاحية',
    'admin_failed': 'فشل التحديث',
    'admin_no_connection': 'لا يوجد اتصال بـ Supabase',
    'admin_users_empty': 'لا يوجد مستخدمون',
    'admin_name_label': 'الاسم',
    'admin_role_label': 'الصلاحية',

    // Banner editor إضافات
    'banner_move_up': 'نقل لأعلى',
    'banner_move_down': 'نقل لأسفل',
    'banner_enable': 'تفعيل',
    'banner_disable': 'تعطيل',
    'banner_height_label': 'الارتفاع',
    'banner_refresh': 'تحديث',

    // Common
    'common_close_sheet': 'إغلاق',

  };

  static const Map<String, String> _en = {
    'app_name': 'AR Music & Video',

    'drawer_admin_panel': 'Admin Panel',
    'drawer_profile': 'My Profile',
    'drawer_privacy': 'Privacy Policy',
    'drawer_about': 'About',
    'drawer_logout': 'Sign Out',
    'drawer_guest': 'Guest Mode',
    'drawer_user': 'User',
    'drawer_offline': 'Offline',

    'tab_audio': 'Audio',
    'tab_videos': 'Videos',

    'login_title': 'Sign In',
    'signup_title': 'Create Account',
    'email_label': 'Email',
    'password_label': 'Password',
    'fullname_label': 'Full Name',
    'login_button': 'Sign In',
    'signup_button': 'Create Account',
    'guest_button': 'Continue as Guest',
    'forgot_password': 'Forgot password? (Contact via Telegram)',
    'switch_to_signup': "Don't have an account? Sign Up",
    'switch_to_login': 'Already have an account? Sign In',
    'fill_email_password': 'Please enter email and password',
    'fill_fullname': 'Please enter full name',

    'audio_library': 'Audio Library',
    'audio_all': 'All Audio',
    'audio_folders': 'Folders',
    'audio_favorites': 'Favorites',
    'audio_scanning': 'Scanning device...',
    'audio_empty': 'No audio files found on your device.',
    'audio_refresh': 'Rescan',
    'audio_tracks': 'tracks',
    'audio_unknown_artist': 'Unknown artist',
    'audio_unknown_album': 'Unknown album',

    'video_library': 'Video Library',
    'video_all': 'All Videos',
    'video_albums': 'Albums',
    'video_scanning': 'Scanning videos...',
    'video_empty': 'No videos found on your device.',
    'video_grid_view': 'Grid view',
    'video_list_view': 'List view',
    'video_videos': 'videos',
    'video_default_folder': 'Videos',

    'player_no_track': 'No track is playing',
    'player_sleep_timer': 'Sleep Timer',
    'player_speed': 'Playback speed',
    'player_loop_none': 'No repeat',
    'player_loop_once': 'Once',
    'player_loop_twice': 'Twice',
    'player_loop_thrice': '3 times',
    'player_loop_all': 'All',
    'player_point_a': 'Point A',
    'player_point_b': 'Point B',

    'profile_title': 'My Profile',
    'profile_role_admin': 'Admin',
    'profile_role_guest': 'Guest',
    'profile_role_user': 'User',
    'profile_save': 'Save Changes',
    'profile_change_photo': 'Change Photo',
    'profile_photo_gallery': 'From Gallery',
    'profile_photo_camera': 'From Camera',
    'profile_photo_remove': 'Remove Photo',
    'profile_email_label': 'Email',
    'profile_name_label': 'Full Name',
    'profile_updated': '✅ Profile updated',
    'profile_avatar_updated': '✅ Photo updated',
    'profile_avatar_failed': 'Failed to update photo',
    'profile_no_connection': 'No connection',
    'profile_guest_cant_edit': 'Cannot edit in Guest mode',

    'admin_title': 'Admin Panel',
    'admin_tab_users': 'Users',
    'admin_tab_banners': 'Banners',
    'admin_tab_versions': 'Versions',

    'banner_new': 'New Banner',
    'banner_edit': 'Edit Banner',
    'banner_save': 'Save',
    'banner_image': 'Banner Image',
    'banner_no_image': 'No image selected',
    'banner_from_gallery': 'From Gallery',
    'banner_from_camera': 'From Camera',
    'banner_title_label': 'Title (optional)',
    'banner_title_hint': 'Leave empty to hide the title',
    'banner_link_label': 'Target Link (optional)',
    'banner_order_label': 'Display Order (1 = first)',
    'banner_height': 'Banner Height',
    'banner_active': 'Active',
    'banner_active_sub': 'Will be visible when enabled',
    'banner_add_button': 'Add Banner',
    'banner_save_button': 'Save Changes',
    'banner_deleted': '✅ Deleted',
    'banner_saved': '✅ Saved',
    'banner_delete_title': 'Delete banner?',
    'banner_delete_body':
        'The banner and its image will be permanently deleted.',
    'banner_add_fab': 'Add Banner',
    'banner_empty': 'No banners yet',
    'banner_disabled': 'Disabled',
    'banner_select_image': 'Please select a banner image',
    'banner_upload_failed': 'Upload failed — check internet and permissions',
    'banner_save_failed': 'Save failed — check permissions',

    'common_cancel': 'Cancel',
    'common_save': 'Save',
    'common_delete': 'Delete',
    'common_edit': 'Edit',
    'common_retry': 'Retry',
    'common_refresh': 'Refresh',
    'common_loading': 'Loading...',
    'common_error': 'Error',
    'common_ok': 'OK',
    'common_confirm': 'Confirm',
    'common_close': 'Close',
    'common_tap_to_open': 'Tap to open',
    // Full Player
    'player_full_title': 'Audio Player',
    'player_cancel_timer': 'Cancel Timer',
    'player_hour': 'hour',
    'player_minute': 'minute',
    'player_pip': 'Picture-in-Picture (PiP)',
    'player_loop_video': 'Loop video',

    'common_success': 'Success',
    'common_failed': 'Failed',

    'about_version': 'Version: 1.0.0 (ARM64)',
    'about_body':
        'High-performance media player built with Flutter, Supabase and Kotlin '
            'for Android with background playback and PiP support.',
    'about_title_short': 'AR Music & Video',

    'privacy_body':
        'Privacy Policy for AR Music & Video:\n\n'
            '• The app respects your privacy and works fully offline.\n'
            '• Your audio and video files are never uploaded to any external server.\n'
            '• Preferences and recent positions are stored locally via SharedPreferences.\n'
            '• When creating an account, your email and name are securely stored '
            'on Supabase with encrypted RLS policies.',

    'admin_search_hint': 'Search by email or name...',
    'admin_role_user': 'Regular User (user)',
    'admin_role_admin': 'Admin (admin)',
    'admin_role_superuser': 'Superuser (superuser)',
    'admin_change_password_for': 'Change password for',
    'admin_new_password_label': 'New password',
    'admin_change_now': 'Change now',
    'admin_edit_role_title': 'Edit user role',
    'admin_password_updated': 'Password updated successfully',
    'admin_role_updated': 'Role updated',
    'admin_failed': 'Update failed',
    'admin_no_connection': 'No Supabase connection',
    'admin_users_empty': 'No users',
    'admin_name_label': 'Name',
    'admin_role_label': 'Role',

    'banner_move_up': 'Move up',
    'banner_move_down': 'Move down',
    'banner_enable': 'Enable',
    'banner_disable': 'Disable',
    'banner_height_label': 'Height',
    'banner_refresh': 'Refresh',

    'common_close_sheet': 'Close',

  };

  /// تُستخدم مباشرة من LanguageProvider
  static String t(String key, String langCode) {
    final map = langCode == 'ar' ? _ar : _en;
    return map[key] ?? _ar[key] ?? key;
  }
}

/// امتداد راحة:  context.tr('key')
extension AppStringsContextExt on BuildContext {
  String tr(String key) {
    final code = Localizations.localeOf(this).languageCode;
    return AppStrings.t(key, code);
  }
}
