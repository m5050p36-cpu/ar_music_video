import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
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
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  List<AudioTrack> _tracks = [];
  bool _isScanning = false;
  bool _hasScanned = false;
  List<String> _favoritePaths = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFavorites();
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoScan());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.getFavorites();
    if (mounted) setState(() => _favoritePaths = favs);
  }

  Future<void> _autoScan() async {
    if (_hasScanned || _isScanning) return;
    setState(() => _isScanning = true);
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
    super.build(context);
    final player = Provider.of<PlayerProvider>(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(context.tr('audio_library')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('audio_refresh'),
            onPressed: () {
              _hasScanned = false;
              _autoScan();
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: context.tr('audio_all')),
            Tab(text: context.tr('audio_folders')),
            Tab(text: context.tr('audio_favorites')),
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
                  Text(context.tr('audio_scanning')),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            context.tr('audio_empty'),
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
          title: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
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
    final Map<String, List<AudioTrack>> folders = {};
    for (final t in _tracks) {
      final parts = t.path.split('/');
      final folder = parts.length >= 2 ? parts[parts.length - 2] : '-';
      folders.putIfAbsent(folder, () => []).add(t);
    }

    if (folders.isEmpty) {
      return Center(child: Text(context.tr('audio_folders')));
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
          subtitle: Text('${e.value.length} ${context.tr('audio_tracks')}'),
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
