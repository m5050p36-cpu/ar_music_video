import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../models/video_item.dart';
import '../../core/services/video_thumbnail_service.dart';
import 'video_player_screen.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<VideoItem> _videos = [];
  bool _isLoading = false;
  bool _isGridView = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _pickVideos() async {
    setState(() => _isLoading = true);
    try {
      await [Permission.videos, Permission.storage].request();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        final paths = result.paths.whereType<String>().toList();
        final parsed = await VideoThumbnailService.generateThumbnailsInBatches(paths);
        setState(() {
          _videos = parsed;
        });
      }
    } catch (e) {
      debugPrint('Error picking videos: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة الفيديوهات'),
        actions: [
          IconButton(
            icon: Icon(_isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded),
            tooltip: _isGridView ? 'عرض كقائمة' : 'عرض كشبكة',
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          IconButton(
            icon: const Icon(Icons.video_call_outlined),
            tooltip: 'إضافة فيديوهات من الجهاز',
            onPressed: _pickVideos,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllVideosTab(),
                _buildAlbumsTab(),
              ],
            ),
    );
  }

  Widget _buildAllVideosTab() {
    if (_videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Opacity(
              opacity: 0.5,
              child: Icon(Icons.video_library_outlined, size: 64),
            ),
            const SizedBox(height: 12),
            const Text('لا توجد فيديوهات مضافة بعد'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickVideos,
              icon: const Icon(Icons.folder_open),
              label: const Text('تصفح واختيار فيديوهات الجهاز'),
            ),
          ],
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
                  v.thumbnailPath != null
                      ? Image.file(File(v.thumbnailPath!), fit: BoxFit.cover)
                      : Container(color: Colors.black45, child: const Icon(Icons.play_circle_outline, size: 40)),
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
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 56,
              height: 40,
              child: v.thumbnailPath != null
                  ? Image.file(File(v.thumbnailPath!), fit: BoxFit.cover)
                  : const ColoredBox(color: Colors.black26, child: Icon(Icons.play_arrow)),
            ),
          ),
          title: Text(v.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(v.folderName, maxLines: 1),
          trailing: const Icon(Icons.play_circle_fill_rounded),
          onTap: () => _openPlayer(v),
        );
      },
    );
  }

  Widget _buildAlbumsTab() {
    return const Center(child: Text('تصنيف الفيديوهات حسب مجلدات الذاكرة'));
  }
}
