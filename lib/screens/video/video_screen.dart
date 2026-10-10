import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/media_scanner.dart';
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
  bool _isScanning = false;
  bool _hasScanned = false;
  bool _isGridView = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScan());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _autoScan() async {
    if (_hasScanned || _isScanning) return;
    setState(() => _isScanning = true);

    final videos = await MediaScanner.scanVideos();

    if (!mounted) return;
    setState(() {
      _videos = videos;
      _isScanning = false;
      _hasScanned = true;
    });
  }

  void _openPlayer(VideoItem v) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoPlayerScreen(videoPath: v.path, title: v.title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // استخراج النصوص
    final tLibrary = context.tr('video_library');
    final tAll = context.tr('video_all');
    final tAlbums = context.tr('video_albums');
    final tScanning = context.tr('video_scanning');
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
            onPressed: () {
              _hasScanned = false;
              _autoScan();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: tAll),
            Tab(text: tAlbums),
          ],
        ),
      ),
      body: _isScanning
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(tScanning),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllVideosTab(tEmpty),
                _buildAlbumsTab(tAlbums),
              ],
            ),
    );
  }

  Widget _buildThumbnail(VideoItem v) {
    if (v.asset != null) {
      return AssetEntityImage(
        v.asset!,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize(400, 400),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => _thumbnailFallback(),
      );
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
          return GestureDetector(
            onTap: () => _openPlayer(v),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildThumbnail(v),
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
      itemBuilder: (context, i) {
        final v = _videos[i];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
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
          trailing: const Icon(Icons.play_circle_fill_rounded),
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
