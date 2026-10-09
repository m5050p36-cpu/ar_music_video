import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:just_audio_background/just_audio_background.dart';

import 'core/services/supabase_service.dart';
import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/player_provider.dart';
import 'screens/common/splash_screen.dart';

/// نقطة الدخول: runApp فوري، التهيئة في الخلفية
void main() {
  // 1. اربط الـ binding فورًا (مطلوب لـ plugins قبل runApp)
  WidgetsFlutterBinding.ensureInitialized();

  // 2. ثبّت اتجاهات الشاشة بشكل غير معطّل
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).catchError((e) {
    debugPrint('Orientation error: $e');
    return <DeviceOrientation>[];
  });

  // 3. runApp فورًا — لا انتظار للشبكة أو Supabase
  runApp(const ARMusicApp());

  // 4. التهيئة في الخلفية (لا تحجب UI)
  _bootstrap();
}

/// تهيئة ثقيلة في الخلفية — أي فشل هنا لا يوقف التطبيق
Future<void> _bootstrap() async {
  // JustAudioBackground
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.m5050p36.armusic.channel.audio',
      androidNotificationChannelName: 'AR Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );
  } catch (e) {
    debugPrint('JustAudioBackground init error: $e');
  }

  // Supabase (مع timeout داخلي في SupabaseService)
  try {
    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }
}

class ARMusicApp extends StatelessWidget {
  const ARMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..load()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()..load()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: Consumer2<ThemeProvider, LanguageProvider>(
        builder: (context, themeProvider, langProvider, _) {
          return MaterialApp(
            title: 'AR Music & Video',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.currentTheme,
            darkTheme: themeProvider.currentTheme,
            themeMode: ThemeMode.dark,
            locale: langProvider.currentLocale,
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: langProvider.localizationsDelegates,
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
