import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/media_cache.dart';
import '../../core/services/media_scanner.dart';
import '../../core/services/video_favorites_service.dart';
import '../../models/video_item.dart';
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
    final cached = await MediaCache.loadVideos();
    if (mounted && cached.isNotEmpty) {
      setState(() => _videos = cached);
    }

    final stale = await MediaCache.isVideoStale();
    if (!stale && cached.isNotEmpty) return;

    await _backgroundScan();
  }

  Future<void> _backgroundScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

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
    setState(() => _videos = []);
    await _backgroundScan();
  }

  void _openPlayer(VideoItem v) {
    // مرّر كل القائمة + الفهرس الحالي لدعم التقليب والتالي/السابق
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
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllVideosTab(tEmpty),
                _buildAlbumsTab(tAlbums),
                _buildFavoritesTab(tEmpty),
              ],
            ),
    );
  }

  Widget _buildThumbnail(VideoItem v) {
    if (v.thumbnailPath != null) {
      final f = File(v.thumbnailPath!);
      if (f.existsSync()) {
        return Image.file(
          f,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, __, ___) => _thumbnailFallback(),
        );
      }
    }
    return _thumbnailFallback();
  }

  Widget _thumbnailFallback() {
    return Container(
      color: Colors.black26,
      child: const Center(
        child: Icon(
          Icons.play_circle_outline,
          size: 44,
          color: Colors.white70,
        ),
      ),
    );
  }

  Widget _buildAllVideosTab(String emptyText) {
    if (_videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyText, textAlign: TextAlign.center),
        ),
      );
    }

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
        itemBuilder: (context, i) {
          final v = _videos[i];
          final isFav = _favoritePaths.contains(v.path);
          return GestureDetector(
            onTap: () => _openPlayer(v),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(v),
                  // شارة المدة
                  if (v.duration.inSeconds > 0)
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
                          _formatDuration(v.duration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  // زر المفضلة
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () async {
                          await VideoFavoritesService.toggleFavorite(v.path);
                          _loadFavorites();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isFav ? Icons.favorite : Icons.favorite_border,
                            color:
                                isFav ? Colors.redAccent : Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // اسم الفيديو
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
                        v.title,
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
          );
        },
      );
    }

    return ListView.builder(
      itemCount: _videos.length,
      itemExtent: 72,
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
              child: _buildThumbnail(v),
            ),
          ),
          title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${v.folderName} • ${_formatDuration(v.duration)}',
            maxLines: 1,
          ),
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : null,
            ),
            onPressed: () async {
              await VideoFavoritesService.toggleFavorite(v.path);
              _loadFavorites();
            },
          ),
          onTap: () => _openPlayer(v),
        );
      },
    );
  }

  Widget _buildFavoritesTab(String emptyText) {
    final favs = _videos
        .where((v) => _favoritePaths.contains(v.path))
        .toList();

    if (favs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_border, size: 64),
              const SizedBox(height: 12),
              Text(emptyText, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: favs.length,
      itemExtent: 72,
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
              child: _buildThumbnail(v),
            ),
          ),
          title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${v.folderName} • ${_formatDuration(v.duration)}',
            maxLines: 1,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.favorite, color: Colors.redAccent),
            onPressed: () async {
              await VideoFavoritesService.toggleFavorite(v.path);
              _loadFavorites();
            },
          ),
          onTap: () => _openPlayer(v),
        );
      },
    );
  }

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
        itemBuilder: (context, i) {
          final v = videos[i];
          return ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => VideoPlayerScreen(
                  videoPath: v.path,
                  title: v.title,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
