import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/permission_service.dart';
import '../../providers/auth_provider.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startup());
  }

  Future<void> _startup() async {
    // ─── 1. ابدأ طلب الصلاحيات في الخلفية — لا يوقف التنقل ───
    _requestPermissionsInBackground();

    // ─── 2. انتظر AuthStatus يخرج من unknown — بحد أقصى 1.2 ثانية ───
    final auth = Provider.of<AuthProvider>(context, listen: false);
    var waited = 0;
    while (auth.status == AuthStatus.unknown && waited < 12) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
      if (!mounted) return;
    }

    if (!mounted) return;
    _navigate(auth.status);
  }

  void _requestPermissionsInBackground() {
    // نستخدم delay بسيط لتفادي منع UI
    Future.delayed(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final asked = prefs.getBool('permissions_asked_v1') ?? false;
        if (asked) return;
        if (!mounted) return;
        await PermissionService.requestAll(context);
        await prefs.setBool('permissions_asked_v1', true);
      } catch (_) {}
    });
  }

  void _navigate(AuthStatus status) {
    if (_navigated || !mounted) return;
    _navigated = true;

    final destination = (status == AuthStatus.authenticated ||
            status == AuthStatus.guest)
        ? const HomeScreen()
        : const LoginScreen();

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.music_video_rounded,
                size: 72,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AR Music & Video',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 36),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          ],
        ),
      ),
    );
  }
}
