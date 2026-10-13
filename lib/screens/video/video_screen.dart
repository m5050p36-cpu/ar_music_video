import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/media_cache.dart';
import '../../core/services/media_scanner.dart';
import '../../core/services/video_favorites_service.dart';
import '../../core/services/video_thumbnail_cache.dart';
import '../../models/video_item.dart';
import '../../widgets/media_item_menu.dart';
import 'video_player_screen.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  List<VideoItem> _videos = [];
  List<String> _favoritePaths = [];
  bool _isScanning = false;
  bool _isGridView = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favs = await VideoFavoritesService.getFavorites();
    if (mounted) setState(() => _favoritePaths = favs);
  }

  Future<void> _bootstrap() async {
    // 1. كاش فوري — الواجهة تظهر خلال ميلي ثانية
    final cached = await MediaCache.loadVideos();
    if (!mounted) return;
    if (cached.isNotEmpty) {
      setState(() {
        _videos = cached;
      });
    }

    // 2. فحص في الخلفية فقط إن كان الكاش قديمًا
    final stale = await MediaCache.isVideoStale();
    if (!stale && cached.isNotEmpty) return;

    await _backgroundScan();
  }

  Future<void> _backgroundScan() async {
    if (_isScanning) return;
    if (mounted) setState(() => _isScanning = true);

    final fresh = await MediaScanner.scanVideos();

    if (!mounted) return;
    if (fresh.isNotEmpty) {
      setState(() {
        _videos = fresh;
        _isScanning = false;
      });
      await MediaCache.saveVideos(fresh);
    } else {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _forceRescan() async {
    await MediaCache.clear();
    if (mounted) {
      setState(() {
        _videos = [];
      });
    }
    await _backgroundScan();
  }

  void _openPlayer(VideoItem v) {
    final list = _videos.isEmpty ? <VideoItem>[v] : _videos;
    final idx = list.indexWhere((x) => x.id == v.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(
          videoPath: v.path,
          title: v.title,
          playlist: list,
          initialIndex: idx >= 0 ? idx : 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final tLibrary = context.tr('video_library');
    final tAll = context.tr('video_all');
    final tAlbums = context.tr('video_albums');
    final tFav = context.tr('video_favorites');
    final tEmpty = context.tr('video_empty');
    final tRefresh = context.tr('audio_refresh');
    final tGridView = context.tr('video_grid_view');
    final tListView = context.tr('video_list_view');

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(tLibrary),
        actions: [
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _isGridView ? tListView : tGridView,
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: tRefresh,
            onPressed: _forceRescan,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tAll),
            Tab(text: tAlbums),
            Tab(text: tFav),
          ],
        ),
      ),
      body: _videos.isEmpty && _isScanning
          ? const Center(child: CircularProgressIndicator())
          : _videos.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.video_library_outlined,
                          size: 72,
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          tEmpty,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              await PhotoManager.requestPermissionExtend(
                                requestOption: const PermissionRequestOption(
                                  androidPermission: AndroidPermission(
                                    type: RequestType.common,
                                    mediaLocation: false,
                                  ),
                                ),
                              );
                            } catch (_) {}
                            await MediaCache.clear();
                            if (mounted) setState(() => _videos = []);
                            await _backgroundScan();
                          },
                          icon: const Icon(Icons.lock_open_rounded),
                          label: const Text('منح الصلاحيات وإعادة الفحص'),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => openAppSettings(),
                          icon: const Icon(Icons.settings, size: 18),
                          label: const Text('فتح إعدادات التطبيق'),
                        ),
                        const SizedBox(height: 12),

                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildAllVideosTab(),
                    _buildAlbumsTab(tAlbums),
                    _buildFavoritesTab(),
                  ],
                ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Grid
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAllVideosTab() {
    if (_isGridView) {
      return GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 16 / 11,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: _videos.length,
        // ⚡ performance: لا نبقي العناصر خارج الشاشة حية
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (context, i) {
          final v = _videos[i];
          final isFav = _favoritePaths.contains(v.path);
          return _VideoGridTile(
            video: v,
            isFav: isFav,
            onTap: () => _openPlayer(v),
            onToggleFav: () async {
              await VideoFavoritesService.toggleFavorite(v.path);
              _loadFavorites();
            },
            onChanged: _forceRescan,
          );
        },
      );
    }

    return ListView.builder(
      itemCount: _videos.length,
      itemExtent: 72,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, i) {
        final v = _videos[i];
        final isFav = _favoritePaths.contains(v.path);
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 54,
              child: _LazyThumb(video: v),
            ),
          ),
          title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${v.folderName} • ${_formatDuration(v.duration)}',
            maxLines: 1,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? Colors.redAccent : null,
                ),
                onPressed: () async {
                  await VideoFavoritesService.toggleFavorite(v.path);
                  _loadFavorites();
                },
              ),
              MediaItemMenu(
                path: v.path,
                isVideo: true,
                assetId: v.id,
                onChanged: _forceRescan,
              ),
            ],
          ),
          onTap: () => _openPlayer(v),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Favorites
  // ═══════════════════════════════════════════════════════════════
  Widget _buildFavoritesTab() {
    final favs =
        _videos.where((v) => _favoritePaths.contains(v.path)).toList();

    if (favs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 64),
              const SizedBox(height: 12),
              Text(context.tr('video_empty'), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: favs.length,
      itemExtent: 72,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, i) {
        final v = favs[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 54,
              child: _LazyThumb(video: v),
            ),
          ),
          title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${v.folderName} • ${_formatDuration(v.duration)}',
            maxLines: 1,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite, color: Colors.redAccent),
                onPressed: () async {
                  await VideoFavoritesService.toggleFavorite(v.path);
                  _loadFavorites();
                },
              ),
              MediaItemMenu(
                path: v.path,
                isVideo: true,
                assetId: v.id,
                onChanged: _forceRescan,
              ),
            ],
          ),
          onTap: () => _openPlayer(v),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // Albums
  // ═══════════════════════════════════════════════════════════════
  Widget _buildAlbumsTab(String emptyText) {
    final Map<String, List<VideoItem>> albums = {};
    for (final v in _videos) {
      albums.putIfAbsent(v.folderName, () => []).add(v);
    }
    if (albums.isEmpty) {
      return Center(child: Text(emptyText));
    }
    final entries = albums.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final tVideos = context.tr('video_videos');

    return ListView.builder(
      itemCount: entries.length,
      itemExtent: 72,
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(e.key),
          subtitle: Text('${e.value.length} $tVideos'),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _AlbumVideosScreen(
                albumName: e.key,
                videos: e.value,
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s < 10 ? '0' : ''}$s';
  }
}

// ═══════════════════════════════════════════════════════════════
// بطاقة شبكة مع lazy thumbnail + زر قائمة
// ═══════════════════════════════════════════════════════════════
class _VideoGridTile extends StatelessWidget {
  final VideoItem video;
  final bool isFav;
  final VoidCallback onTap;
  final VoidCallback onToggleFav;
  final VoidCallback onChanged;

  const _VideoGridTile({
    required this.video,
    required this.isFav,
    required this.onTap,
    required this.onToggleFav,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _LazyThumb(video: video),
              if (video.duration.inSeconds > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _fmt(video.duration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 4,
                left: 4,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onToggleFav,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.redAccent : Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: MediaItemMenu(
                      path: video.path,
                      isVideo: true,
                      assetId: video.id,
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.transparent, Colors.black87],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Text(
                    video.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s < 10 ? '0' : ''}$s';
  }
}

// ═══════════════════════════════════════════════════════════════
// ويدجت الصورة المصغرة — lazy + cached
// ═══════════════════════════════════════════════════════════════
class _LazyThumb extends StatefulWidget {
  final VideoItem video;
  const _LazyThumb({required this.video});

  @override
  State<_LazyThumb> createState() => _LazyThumbState();
}

class _LazyThumbState extends State<_LazyThumb> {
  Uint8List? _bytes;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await VideoThumbnailCache.get(
      assetId: widget.video.id,
      asset: widget.video.asset,
    );
    if (!mounted) return;
    setState(() {
      _bytes = bytes;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // 1. من الذاكرة/القرص — الأسرع
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        gaplessPlayback: true,
        cacheWidth: 400,
      );
    }

    // 2. fallback فوري عبر AssetEntityImage إذا كان asset متوفرًا (في نفس الجلسة)
    final asset = widget.video.asset;
    if (asset != null) {
      return AssetEntityImage(
        asset,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize(400, 400),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => _fallbackIcon(),
      );
    }

    // 3. قيد التحميل
    if (!_loaded) {
      return Container(
        color: Colors.black12,
        alignment: Alignment.center,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // 4. بدون asset وبدون كاش (فيديو من cache JSON)
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    return Container(
      color: Colors.black26,
      alignment: Alignment.center,
      child: const Icon(
        Icons.play_circle_outline,
        size: 36,
        color: Colors.white70,
      ),
    );
  }
}

// ═
// شاشة ألبوم
// ═══════════════════════════════════════════════════════════════
class _AlbumVideosScreen extends StatelessWidget {
  final String albumName;
  final List<VideoItem> videos;

  const _AlbumVideosScreen({
    required this.albumName,
    required this.videos,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(albumName)),
      body: ListView.builder(
        itemCount: videos.length,
        itemExtent: 72,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (context, i) {
          final v = videos[i];
          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 72,
                height: 54,
                child: _LazyThumb(video: v),
              ),
            ),
            title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(
                  videoPath: v.path,
                  title: v.title,
                  playlist: videos,
                  initialIndex: i,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
