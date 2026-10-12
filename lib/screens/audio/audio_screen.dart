import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/media_cache.dart';
import '../../core/services/media_scanner.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';
import '../../widgets/playing_indicator.dart';
import '../../widgets/media_item_menu.dart';
import '../../widgets/track_artwork.dart';

class AudioScreen extends StatefulWidget {
  const AudioScreen({super.key});

  @override
  State<AudioScreen> createState() => _AudioScreenState();
}

class _AudioScreenState extends State<AudioScreen>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  List<AudioTrack> _tracks = [];
  bool _isScanning = false;
  List<String> _favoritePaths = [];

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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    final favs = await FavoritesService.getFavorites();
    if (mounted) setState(() => _favoritePaths = favs);
  }

  Future<void> _bootstrap() async {
    final cached = await MediaCache.loadAudio();
    if (mounted && cached.isNotEmpty) {
      setState(() => _tracks = cached);
    }

    final stale = await MediaCache.isAudioStale();
    if (!stale && cached.isNotEmpty) return;

    await _backgroundScan();
  }

  Future<void> _backgroundScan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    final fresh = await MediaScanner.scanAudio();

    if (!mounted) return;
    if (fresh.isNotEmpty) {
      setState(() {
        _tracks = fresh;
        _isScanning = false;
      });
      await MediaCache.saveAudio(fresh);
    } else {
      setState(() => _isScanning = false);
    }
  }

  Future<void> _forceRescan() async {
    await MediaCache.clear();
    setState(() => _tracks = []);
    await _backgroundScan();
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
          if (player.currentTrack != null)
            IconButton(
              icon: const Icon(Icons.my_location_rounded),
              tooltip: 'الانتقال للأغنية الحالية',
              onPressed: () {
                final idx = _tracks
                    .indexWhere((t) => t.id == player.currentTrack!.id);
                if (idx < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('الأغنية الحالية ليست في هذه القائمة')),
                  );
                  return;
                }
                _tabController.animateTo(0);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    const rowH = 68.0;
                    _scrollController.animateTo(
                      idx * rowH,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.tr('audio_refresh'),
            onPressed: _forceRescan,
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
      body: _tracks.isEmpty && _isScanning
          ? const Center(child: CircularProgressIndicator())
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
      itemExtent: 72,
      itemBuilder: (context, i) {
        final t = list[i];
        final isPlaying = player.currentTrack?.id == t.id &&
            player.player.playing;
        final isCurrent = player.currentTrack?.id == t.id;
        final isFav = _favoritePaths.contains(t.path);
        final theme = Theme.of(context);

        return ListTile(
          leading: Stack(
            children: [
              TrackArtwork(
                songId: t.id,
                size: 52,
                borderRadius: 8,
                fallbackIcon: isCurrent
                    ? Icons.equalizer_rounded
                    : Icons.music_note,
              ),
              // 🎵 مؤشر التشغيل يظهر على الصورة عند التشغيل
              if (isPlaying)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: PlayingIndicator(
                      color: theme.colorScheme.primary,
                      dotSize: 3,
                      height: 18,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isCurrent ? theme.colorScheme.primary : null,
              fontWeight: isCurrent ? FontWeight.w600 : null,
            ),
          ),
          subtitle: Text(
            '${t.artist} • ${t.album}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                  await FavoritesService.toggleFavorite(t.path);
                  _loadFavorites();
                },
              ),
              MediaItemMenu(
                path: t.path,
                isVideo: false,
                songId: t.id,
                onChanged: () {
                  _forceRescan();
                },
              ),
            ],
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
        itemExtent: 72,
        itemBuilder: (context, i) {
          final t = tracks[i];
          final isPlaying = player.currentTrack?.id == t.id &&
              player.player.playing;
          final theme = Theme.of(context);

          return ListTile(
            leading: Stack(
              children: [
                TrackArtwork(songId: t.id, size: 52),
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: PlayingIndicator(
                        color: theme.colorScheme.primary,
                        dotSize: 3,
                        height: 18,
                      ),
                    ),
                  ),
              ],
            ),
            title:
                Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(t.artist, maxLines: 1),
            trailing: MediaItemMenu(
              path: t.path,
              isVideo: false,
              songId: t.id,
            ),
            onTap: () => player.setPlaylist(tracks, startIndex: i),
          );
        },
      ),
    );
  }
}
