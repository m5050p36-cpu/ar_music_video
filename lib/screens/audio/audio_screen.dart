import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/favorites_service.dart';
import '../../core/services/media_cache.dart';
import '../../core/services/media_scanner.dart';
import '../../models/audio_track.dart';
import '../../providers/player_provider.dart';
import '../../widgets/media_item_menu.dart';
import '../../widgets/playing_indicator.dart';
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
    if (mounted) setState(() => _tracks = []);
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
                final idx = _tracks.indexWhere(
                  (t) => t.id == player.currentTrack!.id,
                );
                if (idx < 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('الأغنية الحالية ليست في هذه القائمة'),
                    ),
                  );
                  return;
                }
                _tabController.animateTo(0);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    const rowH = 76.0;
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

  // ═══════════════════════════════════════════════════════════════
  // قائمة الأغاني — تصميم Spotify
  // ═══════════════════════════════════════════════════════════════
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

    final theme = Theme.of(context);

    return ListView.builder(
      controller: _scrollController,
      itemCount: list.length,
      itemExtent: 76,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      itemBuilder: (context, i) {
        final t = list[i];
        final isCurrent = player.currentTrack?.id == t.id;
        final isPlaying = isCurrent && player.player.playing;
        final isFav = _favoritePaths.contains(t.path);

        return InkWell(
          onTap: () => player.setPlaylist(list, startIndex: i),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                // ═══ الغلاف ═══
                Stack(
                  children: [
                    TrackArtwork(
                      songId: t.id,
                      size: 56,
                      borderRadius: 10,
                    ),
                    if (isPlaying)
                      Positioned(
                        bottom: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: PlayingIndicator(
                            color: theme.colorScheme.primary,
                            dotSize: 2.5,
                            height: 12,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 12),

                // ═══ النص ═══
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        t.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight:
                              isCurrent ? FontWeight.w700 : FontWeight.w600,
                          color: isCurrent
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${t.artist} • ${t.album}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // ═══ الأزرار ═══
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    color: isFav ? Colors.redAccent : null,
                    size: 22,
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
                  onChanged: _forceRescan,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // المجلدات
  // ═══════════════════════════════════════════════════════════════
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
      itemExtent: 68,
      itemBuilder: (context, i) {
        final e = entries[i];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(
              Icons.folder_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          title: Text(
            e.key,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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

// ═══════════════════════════════════════════════════════════════
// شاشة مجلد
// ═══════════════════════════════════════════════════════════════
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(folderName)),
      body: ListView.builder(
        itemCount: tracks.length,
        itemExtent: 76,
        itemBuilder: (context, i) {
          final t = tracks[i];
          final isCurrent = player.currentTrack?.id == t.id;
          final isPlaying = isCurrent && player.player.playing;

          return InkWell(
            onTap: () => player.setPlaylist(tracks, startIndex: i),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Stack(
                    children: [
                      TrackArtwork(songId: t.id, size: 56, borderRadius: 10),
                      if (isPlaying)
                        Positioned(
                          bottom: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: PlayingIndicator(
                              color: theme.colorScheme.primary,
                              dotSize: 2.5,
                              height: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          t.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w600,
                            color: isCurrent
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          t.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  MediaItemMenu(
                    path: t.path,
                    isVideo: false,
                    songId: t.id,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
