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

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PlayerProvider()),
      ],
      child: const ARMusicApp(),
    ),
  );

  _initServicesInBackground();
}

Future<void> _initServicesInBackground() async {
  try {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.yourapp.armusic.channel.audio',
      androidNotificationChannelName: 'AR Music Playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
    );

    await SupabaseService.initialize();
  } catch (e) {
    debugPrint('Background init warning: $e');
  }
}

class ARMusicApp extends StatelessWidget {
  const ARMusicApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return MaterialApp(
      title: 'AR Music & Video',
      debugShowCheckedModeBanner: false,
      theme: themeProvider.themeData,
      locale: langProvider.locale,
      home: const SplashScreen(),
    );
  }
}
