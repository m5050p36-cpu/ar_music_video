import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/language_provider.dart';
import '../../core/theme/app_themes.dart';
import '../../core/services/supabase_service.dart';
import '../../widgets/mini_player.dart';
import '../audio/audio_screen.dart';
import '../video/video_screen.dart';
import '../admin/admin_panel_screen.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'privacy_policy_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with
        SingleTickerProviderStateMixin,
        AutomaticKeepAliveClientMixin,
        WidgetsBindingObserver {
  static const _bannersCacheKey = 'cached_banners_json';

  late TabController _tabController;
  List<Map<String, dynamic>> _banners = [];
  final PageController _bannerController = PageController();
  int _bannerIndex = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _loadCachedBannersFirst(); // تحميل فوري من الكاش
    _loadBanners(); // ثم تحديث من الشبكة
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      try {
        Provider.of<AuthProvider>(context, listen: false).refreshProfile();
      } catch (_) {}
    }
  }

  /// يحمّل البنرات المخزنة فورًا — يمنع "اختفاء" البنر عند إعادة البناء
  Future<void> _loadCachedBannersFirst() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_bannersCacheKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      if (mounted && list.isNotEmpty) {
        setState(() => _banners = list);
      }
    } catch (_) {}
  }

  Future<void> _loadBanners() async {
    // 1. إذا Supabase غير مهيأ — استخدم الاحتياطي الثابت
    if (!SupabaseService.isInitialized) {
      if (_banners.isEmpty) _setOfflineBanners();
      return;
    }

    // 2. حاول من الشبكة
    try {
      final res = await SupabaseService.client
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .timeout(const Duration(seconds: 6));

      if (res.isNotEmpty) {
        final list = List<Map<String, dynamic>>.from(res);
        if (mounted) {
          setState(() => _banners = list);
        }
        // خزّن دائمًا لتفادي "الاختفاء" في التشغيل القادم
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_bannersCacheKey, jsonEncode(list));
        } catch (_) {}
        return;
      }
    } catch (_) {}

    // 3. إن فشل كل شيء — احتفظ بالبنرات الحالية، أو استخدم الاحتياطي
    if (_banners.isEmpty) _setOfflineBanners();
  }

  void _setOfflineBanners() {
    if (!mounted) return;
    setState(() {
      _banners = [
        {
          'title': 'مرحباً بك في AR Music & Video',
          'image_url':
              'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=1200&q=80',
        },
        {
          'title': 'أقوى مشغل صوتي وفيديو مع PiP',
          'image_url':
              'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=1200&q=80',
        },
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Music & Video'),
        actions: [
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.amber,
              ),
              tooltip: 'لوحة الإدارة (مشرف)',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdminPanelScreen(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.translate),
            tooltip: 'تبديل اللغة',
            onPressed: () => langProvider.toggleLanguage(),
          ),
          PopupMenuButton<AppThemeMode>(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'تبديل الثيم',
            onSelected: (mode) => themeProvider.setTheme(mode),
            itemBuilder: (_) => AppThemeMode.values
                .map(
                  (mode) => PopupMenuItem(
                    value: mode,
                    child: Row(
                      children: [
                        Icon(mode.icon, size: 18),
                        const SizedBox(width: 8),
                        Text(mode.labelAr),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.audiotrack), text: 'الصوتيات'),
            Tab(icon: Icon(Icons.video_library), text: 'الفيديوهات'),
          ],
        ),
      ),
      drawer: _buildDrawer(context, auth),
      body: Column(
        children: [
          // ─── البنر ثابت أعلى الصفحة — لا يختفي عند التمرير ───
          if (_banners.isNotEmpty) _buildBanner(),
          // ─── المحتوى القابل للتمرير ───
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [AudioScreen(), VideoScreen()],
            ),
          ),
          // ─── مشغل مصغّر ───
          const MiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    return SizedBox(
      height: 145,
      child: Stack(
        children: [
          PageView.builder(
            controller: _bannerController,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _bannerIndex = i),
            itemBuilder: (context, i) {
              final b = _banners[i];
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: b['image_url'] ?? '',
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 200),
                        placeholder: (_, __) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.15),
                        ),
                        errorWidget: (_, __, ___) => Container(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                          child: const Center(
                            child: Icon(Icons.image, size: 42),
                          ),
                        ),
                      ),
                      if ((b['title'] ?? '').toString().isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.black87,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Text(
                              b['title'] ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          // ─── مؤشرات النقاط ───
          if (_banners.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _banners.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _bannerIndex ? 16 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _bannerIndex
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, AuthProvider auth) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              auth.profile?['full_name'] ??
                  (auth.isGuest ? 'وضع الزائر' : 'مستخدم'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(
              auth.currentUser?.email ?? 'وضع عدم الاتصال (Offline)',
            ),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white24,
              child: Icon(Icons.person, size: 42, color: Colors.white),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          if (auth.isAdmin)
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings_rounded,
                color: Colors.amber,
              ),
              title: const Text(
                'لوحة الإدارة المشرفة',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminPanelScreen(),
                  ),
                );
              },
            ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('الملف الشخصي'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('سياسة الخصوصية'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PrivacyPolicyScreen(),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('حول التطبيق'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              'تسجيل الخروج',
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              Navigator.pop(context);
              final navigator = Navigator.of(context);
              await auth.signOut();
              if (!mounted) return;
              navigator.pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
    );
  }
}
