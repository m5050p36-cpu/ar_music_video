import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/favorites_service.dart';
import '../../core/services/media_scanner.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<AudioTrack> _tracks = [];
  bool _isScanning = false;
  bool _hasScanned = false;
  List<String> _favoritePaths = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFavorites();
    // فحص تلقائي بعد أول frame
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScan());
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.getFavorites();
    if (mounted) setState(() => _favoritePaths = favs);
  }

  Future<void> _autoScan() async {
    if (_hasScanned || _isScanning) return;
    setState(() => _isScanning = true);

    // استخدم مؤشر ترابط منفصل داخل الحزمة نفسها
    final tracks = await MediaScanner.scanAudio();

    if (!mounted) return;
    setState(() {
      _tracks = tracks;
      _isScanning = false;
      _hasScanned = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مكتبة الصوتيات'),
        actions: [
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
            Tab(text: 'جميع الصوتيات'),
            Tab(text: 'المجلدات'),
            Tab(text: 'المفضلة'),
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
                  Text('جاري فحص ملفات الجهاز...'),
                ],
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildTrackList(_tracks, player),
                _buildFoldersTab(player),
                _buildFavoritesTab(player),
              ],
            ),
    );
  }

  Widget _buildTrackList(List<AudioTrack> list, PlayerProvider player) {
    if (list.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد ملفات صوتية في الجهاز.\nاسحب للتحديث أو اضغط أيقونة إعادة الفحص.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: list.length,
      itemExtent: 68,
      itemBuilder: (context, i) {
        final t = list[i];
        final isPlaying = player.currentTrack?.id == t.id;
        final isFav = _favoritePaths.contains(t.path);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(
              isPlaying ? Icons.equalizer_rounded : Icons.music_note,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${t.artist} • ${t.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.favorite : Icons.favorite_border,
              color: isFav ? Colors.redAccent : null,
            ),
            onPressed: () async {
              await FavoritesService.toggleFavorite(t.path);
              _loadFavorites();
            },
          ),
          onTap: () => player.setPlaylist(list, startIndex: i),
        );
      },
    );
  }

  Widget _buildFoldersTab(PlayerProvider player) {
    // تجميع حسب المجلد
    final Map<String, List<AudioTrack>> folders = {};
    for (final t in _tracks) {
      final parts = t.path.split('/');
      final folder = parts.length >= 2 ? parts[parts.length - 2] : 'أخرى';
      folders.putIfAbsent(folder, () => []).add(t);
    }
    if (folders.isEmpty) {
      return const Center(child: Text('لا توجد مجلدات'));
    }
    final entries = folders.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return ListView.builder(
      itemCount: entries.length,
      itemExtent: 64,
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: const Icon(Icons.folder),
          title: Text(e.key),
          subtitle: Text('${e.value.length} مقطع'),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => _FolderTracksScreen(
                folderName: e.key,
                tracks: e.value,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab(PlayerProvider player) {
    final favTracks =
        _tracks.where((t) => _favoritePaths.contains(t.path)).toList();
    return _buildTrackList(favTracks, player);
  }
}

class _FolderTracksScreen extends StatelessWidget {
  final String folderName;
  final List<AudioTrack> tracks;

  const _FolderTracksScreen({
    required this.folderName,
    required this.tracks,
  });

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: ListView.builder(
        itemCount: tracks.length,
        itemExtent: 68,
        itemBuilder: (context, i) {
          final t = tracks[i];
          return ListTile(
            leading: const Icon(Icons.music_note),
            title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(t.artist, maxLines: 1),
            onTap: () => player.setPlaylist(tracks, startIndex: i),
          );
        },
      ),
    );
  }
}
