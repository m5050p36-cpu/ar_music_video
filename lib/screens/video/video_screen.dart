import 'package:flutter/material.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

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
  bool get wantKeepAlive => true; // لا نُعيد البناء عند تبديل التبويبات

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
    super.build(context); // ضروري لـ AutomaticKeepAliveClientMixin

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('مكتبة الفيديوهات'),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _isGridView ? 'عرض كقائمة' : 'عرض كشبكة',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'إعادة الفحص',
            onPressed: () {
              _hasScanned = false;
              _autoScan();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'جميع الفيديوهات'),
            Tab(text: 'الألبومات'),
          ],
        ),
      ),
      body: _isScanning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 12),
                  Text('جاري فحص فيديوهات الجهاز...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllVideosTab(),
                _buildAlbumsTab(),
              ],
            ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // عرض الصورة المصغرة — يستخدم AssetEntityImageWidget
  // يعتمد على MediaStore (سريع، بدون قراءة الملف)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildThumbnail(VideoItem v) {
    if (v.asset != null) {
      return AssetEntityImage(
        v.asset!,
        isOriginal: false,
        thumbnailSize: const ThumbnailSize.square(400),
        thumbnailFormat: ThumbnailFormat.jpeg,
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

  Widget _buildAllVideosTab() {
    if (_videos.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد فيديوهات في الجهاز.',
            textAlign: TextAlign.center,
          ),
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
                  // شارة المدة (إن وُجدت)
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
                  // طبقة العنوان السفلية
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

    // عرض كقائمة
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
          title: Text(
            v.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
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

  Widget _buildAlbumsTab() {
    final Map<String, List<VideoItem>> albums = {};
    for (final v in _videos) {
      albums.putIfAbsent(v.folderName, () => []).add(v);
    }
    if (albums.isEmpty) {
      return const Center(child: Text('لا توجد ألبومات'));
    }
    final entries = albums.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      itemCount: entries.length,
      itemExtent: 72,
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(e.key),
          subtitle: Text('${e.value.length} فيديو'),
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
