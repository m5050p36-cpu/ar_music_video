import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/supabase_service.dart';
import '../../core/theme/app_themes.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/mini_player.dart';
import '../admin/admin_panel_screen.dart';
import '../audio/audio_screen.dart';
import '../video/video_screen.dart';
import 'about_screen.dart';
import 'coming_soon_screen.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'profile_screen.dart';

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
  static const _bannersCacheKey = 'cached_banners_json_v2';

  late TabController _tabController;
  List<Map<String, dynamic>> _banners = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadCachedBannersFirst();
    _loadBanners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    // أعِد البناء لتحديث الشريط السفلي (يُستدعى عند بدء الحركة)
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      try {
        Provider.of<AuthProvider>(context, listen: false).refreshProfile();
      } catch (_) {}
      _loadBanners();
    }
  }

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
    if (!SupabaseService.isInitialized) {
      if (_banners.isEmpty) _setOfflineBanners();
      return;
    }

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
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_bannersCacheKey, jsonEncode(list));
        } catch (_) {}
        return;
      }
    } catch (_) {}

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
          'height': 145,
        },
      ];
    });
  }

  Future<void> _openBannerLink(String? url) async {
    if (url == null || url.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final errorText = context.tr('common_error');
    try {
      final uri = Uri.parse(url.trim());
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        messenger.showSnackBar(SnackBar(content: Text(errorText)));
      }
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(errorText)));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    final tAudio = context.tr('tab_audio');
    final tVideos = context.tr('tab_videos');
    final tAdminPanel = context.tr('drawer_admin_panel');
    final tProfile = context.tr('drawer_profile');
    final tPrivacy = context.tr('drawer_privacy');
    final tAbout = context.tr('drawer_about');
    final tLogout = context.tr('drawer_logout');
    final tGuest = context.tr('drawer_guest');
    final tUser = context.tr('drawer_user');
    final tOffline = context.tr('drawer_offline');
    final tAppName = context.tr('app_name');

    // 📐 البنر بنسبة 16:9
    final screenWidth = MediaQuery.sizeOf(context).width;
    final bannerHeight = (screenWidth * 9.0 / 16.0).round();
    final expandedHeight = bannerHeight + kToolbarHeight;

    return Scaffold(
      drawer: _buildDrawer(
        context,
        auth,
        tAdminPanel: tAdminPanel,
        tProfile: tProfile,
        tPrivacy: tPrivacy,
        tAbout: tAbout,
        tLogout: tLogout,
        tGuest: tGuest,
        tUser: tUser,
        tOffline: tOffline,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              expandedHeight: expandedHeight,
              floating: false,
              pinned: true,
              snap: false,
              elevation: 0,
              backgroundColor: Theme.of(context).colorScheme.surface,
              title: Text(tAppName),
              actions: [
                if (auth.isAdmin)
                  IconButton(
                    icon: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.amber,
                    ),
                    tooltip: tAdminPanel,
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminPanelScreen(),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.translate),
                  tooltip: 'Language / اللغة',
                  onPressed: () => langProvider.toggleLanguage(),
                ),
                PopupMenuButton<AppThemeMode>(
                  icon: const Icon(Icons.palette_outlined),
                  tooltip: 'Theme',
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
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _banners.isEmpty
                    ? Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final widthPercent = (_banners.first['width_percent']
                                      as num?)
                                  ?.toInt() ??
                              100;
                          final safePercent =
                              widthPercent.clamp(50, 100) / 100.0;
                          final hPad =
                              (constraints.maxWidth * (1 - safePercent)) / 2;
                          return Padding(
                            padding: EdgeInsets.symmetric(horizontal: hPad),
                            child: _BannerPager(
                              banners: _banners,
                              baseHeight: bannerHeight,
                              onTap: (url) => _openBannerLink(url),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ];
        },
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [AudioScreen(), VideoScreen()],
              ),
            ),
            const MiniPlayer(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomBar(tAudio, tVideos),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // الشريط السفلي:  [🎵 الموسيقى]   [AR]   [🎬 الفيديوهات]
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBottomBar(String tAudio, String tVideos) {
    final theme = Theme.of(context);
    final currentIndex = _tabController.index;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: [
              // ─── زر الموسيقى ───
              Expanded(
                child: _BottomBarItem(
                  icon: Icons.music_note_rounded,
                  label: tAudio,
                  isActive: currentIndex == 0,
                  onTap: () {
                    _tabController.animateTo(0);
                    setState(() {});
                  },
                ),
              ),

              // ─── شعار AR في الوسط ───
              _buildCenterBrand(theme),

              // ─── زر الفيديوهات ───
              Expanded(
                child: _BottomBarItem(
                  icon: Icons.video_library_rounded,
                  label: tVideos,
                  isActive: currentIndex == 1,
                  onTap: () {
                    _tabController.animateTo(1);
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCenterBrand(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const ComingSoonScreen(),
          ),
        );
      },
      child: Container(
        width: 52,
        height: 52,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withValues(alpha: 0.45),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'AR',
            style: TextStyle(
              color: theme.colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 16,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(
    BuildContext context,
    AuthProvider auth, {
    required String tAdminPanel,
    required String tProfile,
    required String tPrivacy,
    required String tAbout,
    required String tLogout,
    required String tGuest,
    required String tUser,
    required String tOffline,
  }) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(
              auth.profile?['full_name'] ?? (auth.isGuest ? tGuest : tUser),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(auth.currentUser?.email ?? tOffline),
            currentAccountPicture: _buildAvatar(auth),
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
              title: Text(
                tAdminPanel,
                style: const TextStyle(
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
            title: Text(tProfile),
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
            title: Text(tPrivacy),
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
            title: Text(tAbout),
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
            title: Text(
              tLogout,
              style: const TextStyle(color: Colors.redAccent),
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

  Widget _buildAvatar(AuthProvider auth) {
    final avatarUrl = auth.profile?['avatar_url'] as String?;
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: Colors.white24,
        backgroundImage: CachedNetworkImageProvider(avatarUrl),
      );
    }
    return const CircleAvatar(
      backgroundColor: Colors.white24,
      child: Icon(Icons.person, size: 42, color: Colors.white),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// زر الشريط السفلي
// ═══════════════════════════════════════════════════════════════
class _BottomBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _BottomBarItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isActive
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// _BannerPager (كما هو)
// ═══════════════════════════════════════════════════════════════
class _BannerPager extends StatefulWidget {
  final List<Map<String, dynamic>> banners;
  final int baseHeight;
  final void Function(String? url) onTap;

  const _BannerPager({
    required this.banners,
    required this.baseHeight,
    required this.onTap,
  });

  @override
  State<_BannerPager> createState() => _BannerPagerState();
}

class _BannerPagerState extends State<_BannerPager> {
  late PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    Future.delayed(const Duration(seconds: 5), _tick);
  }

  void _tick() {
    if (!mounted) return;
    if (widget.banners.length > 1) {
      final next = (_index + 1) % widget.banners.length;
      if (_pageController.hasClients) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    }
    _startAutoPlay();
  }

  void _goTo(int delta) {
    if (widget.banners.isEmpty) return;
    final next = (_index + delta + widget.banners.length) %
        widget.banners.length;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final showArrows = widget.banners.length > 1;

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (i) => setState(() => _index = i),
          itemCount: widget.banners.length,
          itemBuilder: (context, i) {
            final b = widget.banners[i];
            final url = b['target_url'] as String?;
            final hasLink = url != null && url.trim().isNotEmpty;
            final titleText = (b['title'] ?? '').toString();

            return GestureDetector(
              onTap: hasLink ? () => widget.onTap(url) : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: b['image_url'] ?? '',
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 250),
                    placeholder: (_, __) => Container(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.15),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color:
                          theme.colorScheme.primary.withValues(alpha: 0.3),
                      child: const Center(
                        child: Icon(Icons.image, size: 42),
                      ),
                    ),
                  ),
                  if (titleText.isNotEmpty)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black87],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Text(
                          titleText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),

        // ═══ سهم يسار ═══
        if (showArrows)
          Positioned(
            left: 8,
            top: 0,
            bottom: 20,
            child: Center(
              child: _NavArrow(
                icon: isRtl
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                onTap: () => _goTo(-1),
              ),
            ),
          ),

        // ═══ سهم يمين ═══
        if (showArrows)
          Positioned(
            right: 8,
            top: 0,
            bottom: 20,
            child: Center(
              child: _NavArrow(
                icon: isRtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                onTap: () => _goTo(1),
              ),
            ),
          ),

        // ═══ مؤشرات النقاط ═══
        if (widget.banners.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                widget.banners.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _index ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _index
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}


// ═══════════════════════════════════════════════════════════════
// سهم تنقل دائري
// ═══════════════════════════════════════════════════════════════
class _NavArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _NavArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
