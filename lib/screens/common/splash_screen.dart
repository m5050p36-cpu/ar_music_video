import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenAndNavigate());
  }

  void _listenAndNavigate() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    // نستمع حتى تخرج الحالة من unknown
    auth.addListener(_checkAndNavigate);
    _checkAndNavigate();
  }

  void _checkAndNavigate() {
    if (_navigated || !mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (auth.status == AuthStatus.unknown) return; // انتظر

    _navigated = true;
    auth.removeListener(_checkAndNavigate);

    final destination = (auth.status == AuthStatus.authenticated ||
            auth.status == AuthStatus.guest)
        ? const HomeScreen()
        : const LoginScreen();

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => destination),
      );
    });
  }

  @override
  void dispose() {
    try {
      Provider.of<AuthProvider>(context, listen: false)
          .removeListener(_checkAndNavigate);
    } catch (_) {}
    super.dispose();
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
