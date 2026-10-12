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
    // صلاحيات في الخلفية
    _requestPermissionsInBackground();

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // ═══ انتظر حتى 8 ثوان — AuthProvider نفسه ينتظر Supabase ═══
    var waited = 0;
    while (auth.status == AuthStatus.unknown && waited < 80) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
      if (!mounted) return;
    }

    if (!mounted) return;

    // إن بقي unknown بعد 8s — اذهب للدخول بحذر
    final s = auth.status == AuthStatus.unknown
        ? AuthStatus.unauthenticated
        : auth.status;
    _navigate(s);
  }

  void _requestPermissionsInBackground() {
    Future.delayed(const Duration(milliseconds: 500), () async {
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

    final destination =
        (status == AuthStatus.authenticated || status == AuthStatus.guest)
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
            const SizedBox(height: 8),
            Text(
              'مشغل الوسائط الاحترافي المتكامل',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
