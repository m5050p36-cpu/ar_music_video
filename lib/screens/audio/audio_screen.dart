import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../providers/player_provider.dart';
import '../../core/services/metadata_service.dart';
import '../../core/services/favorites_service.dart';
import '../../models/audio_track.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AudioTrack> _tracks = [];
  bool _isLoading = false;
  List<String> _favoritePaths = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.getFavorites();
    if (mounted) setState(() => _favoritePaths = favs);
  }

  Future<void> _pickAudioFiles() async {
    setState(() => _isLoading = true);
    try {
      await [Permission.audio, Permission.storage].request();
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'm4a', 'flac', 'wav', 'aac'],
        allowMultiple: true,
      );

      if (result != null && result.paths.isNotEmpty) {
        final paths = result.paths.whereType<String>().toList();
        final parsed = await MetadataService.scanAndParseFiles(paths);
        setState(() {
          _tracks = parsed;
        });
        if (mounted && _tracks.isNotEmpty) {
          Provider.of<PlayerProvider>(context, listen: false).setPlaylist(_tracks);
        }
      }
    } catch (e) {
      debugPrint('Error picking files: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة الصوتيات'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'إضافة صوتيات من الذاكرة',
            onPressed: _pickAudioFiles,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'جميع الصوتيات'),
            Tab(text: 'المجلدات'),
            Tab(text: 'المفضلة'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrackList(_tracks, player),
                _buildFoldersTab(),
                _buildFavoritesTab(player),
              ],
            ),
    );
  }

  Widget _buildTrackList(List<AudioTrack> list, PlayerProvider player) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Opacity(
              opacity: 0.5,
              child: Icon(Icons.music_off_outlined, size: 64),
            ),
            const SizedBox(height: 12),
            const Text('لا توجد ملفات صوتية بعد'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _pickAudioFiles,
              icon: const Icon(Icons.folder_open),
              label: const Text('تصفح واختيار ملفات الجهاز'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (context, i) {
        final t = list[i];
        final isPlaying = player.currentTrack?.id == t.id;
        final isFav = _favoritePaths.contains(t.path);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: Theme.of(context).colorScheme.primary.withAlpha(40),
            child: Icon(
              isPlaying ? Icons.equalizer_rounded : Icons.music_note,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${t.artist} • ${t.album}', maxLines: 1),
          trailing: IconButton(
            icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.redAccent : null),
            onPressed: () async {
              await FavoritesService.toggleFavorite(t.path);
              _loadFavorites();
            },
          ),
          onTap: () {
            player.setPlaylist(list, startIndex: i);
          },
        );
      },
    );
  }

  Widget _buildFoldersTab() {
    return const Center(child: Text('عرض المجلدات التلقائي'));
  }

  Widget _buildFavoritesTab(PlayerProvider player) {
    final favTracks = _tracks.where((t) => _favoritePaths.contains(t.path)).toList();
    return _buildTrackList(favTracks, player);
  }
}
