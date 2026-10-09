import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
import 'unified_search_screen.dart';
import 'profile_screen.dart';
import 'file_manager_screen.dart';
import 'privacy_policy_screen.dart';
import 'about_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _banners = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadBanners();
  }

  Future<void> _loadBanners() async {
    try {
      final res = await SupabaseService.client
          .from('banners')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true)
          .timeout(const Duration(seconds: 5));

      if (mounted && res.isNotEmpty) {
        setState(() {
          _banners = List<Map<String, dynamic>>.from(res);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _banners = [
            {
              'title': 'مرحباً بك في AR Music & Video',
              'image_url': 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=1200&q=80',
            },
            {
              'title': 'أقوى مشغل صوتي وفيديو مع PiP',
              'image_url': 'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=1200&q=80',
            },
          ];
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final langProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AR Music & Video'),
        actions: [
          if (auth.isAdmin)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
              tooltip: 'لوحة الإدارة (مشرف)',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'بحث موحد',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UnifiedSearchScreen()),
              );
            },
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
            itemBuilder: (_) => AppThemeMode.values.map((mode) {
              return PopupMenuItem(
                value: mode,
                child: Text(mode.name.toUpperCase()),
              );
            }).toList(),
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
          if (_banners.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: CarouselSlider(
                options: CarouselOptions(
                  height: 135,
                  autoPlay: true,
                  autoPlayInterval: const Duration(seconds: 4),
                  enlargeCenterPage: true,
                  viewportFraction: 0.92,
                  aspectRatio: 16 / 9,
                ),
                items: _banners.map((b) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CachedNetworkImage(
                          imageUrl: b['image_url'] ?? '',
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: Colors.black26),
                          errorWidget: (_, __, ___) => Container(
                            color: Theme.of(context).colorScheme.primary.withAlpha(40),
                            child: const Icon(Icons.image, size: 40),
                          ),
                        ),
                        if (b['title'] != null && b['title'].toString().isNotEmpty)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.transparent, Colors.black87],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                              child: Text(
                                b['title'],
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                AudioScreen(),
                VideoScreen(),
              ],
            ),
          ),

          const MiniPlayer(),
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
              auth.profile?['full_name'] ?? (auth.isGuest ? 'وضع الزائر' : 'مستخدم'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(auth.currentUser?.email ?? 'وضع عدم الاتصال (Offline)'),
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
              leading: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber),
              title: const Text('لوحة الإدارة المشرفة', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
              },
            ),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('الملف الشخصي'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('مدير الملفات'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FileManagerScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('البحث الموحد'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const UnifiedSearchScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('سياسة الخصوصية'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('حول التطبيق'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('تسجيل الخروج', style: TextStyle(color: Colors.redAccent)),
            onTap: () async {
              Navigator.pop(context);
              final navigator = Navigator.of(context);
              await auth.signOut();
              if (mounted) {
                navigator.pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}
