import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/playlist_service.dart';
import '../../providers/player_provider.dart';
import '../../widgets/track_artwork.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailScreen({super.key, required this.playlistId});

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  Playlist? _playlist;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await PlaylistService.getAll();
    final pl = all.firstWhere(
      (p) => p.id == widget.playlistId,
      orElse: () => Playlist(
        id: '',
        name: '—',
        createdAt: DateTime.now(),
        items: [],
      ),
    );
    if (!mounted) return;
    setState(() {
      _playlist = pl;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pl = _playlist;
    final player = Provider.of<PlayerProvider>(context);

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (pl == null || pl.id.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('القائمة غير موجودة')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(pl.name),
        actions: [
          if (pl.items.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow_rounded),
              tooltip: 'تشغيل الكل',
              onPressed: () {
                final tracks =
                    pl.items.map((i) => i.toAudioTrack()).toList();
                player.setPlaylist(tracks);
              },
            ),
        ],
      ),
      body: pl.items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off_outlined,
                    size: 64,
                    color: theme.colorScheme.primary.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 12),
                  const Text('القائمة فارغة'),
                  const SizedBox(height: 4),
                  Text(
                    'أضف أغاني من قائمة ⋮ بجانب كل أغنية',
                    style: TextStyle(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: pl.items.length,
              itemExtent: 68,
              itemBuilder: (context, i) {
                final item = pl.items[i];
                final track = item.toAudioTrack();
                final isCurrent = player.currentTrack?.id == track.id;

                return Dismissible(
                  key: ValueKey(item.path),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  onDismissed: (_) async {
                    await PlaylistService.removeTrack(pl.id, item.path);
                    _load();
                  },
                  child: ListTile(
                    leading: TrackArtwork(songId: track.id, size: 52),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isCurrent ? theme.colorScheme.primary : null,
                        fontWeight: isCurrent ? FontWeight.w600 : null,
                      ),
                    ),
                    subtitle: Text(
                      track.artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      final tracks =
                          pl.items.map((i) => i.toAudioTrack()).toList();
                      player.setPlaylist(tracks, startIndex: i);
                    },
                  ),
                );
              },
            ),
    );
  }
}
