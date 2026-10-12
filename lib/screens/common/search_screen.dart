import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/media_cache.dart';
import '../../models/audio_track.dart';
import '../../models/video_item.dart';
import '../../providers/player_provider.dart';
import '../../widgets/track_artwork.dart';
import '../video/video_player_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  String _query = '';
  List<AudioTrack> _audio = [];
  List<VideoItem> _video = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final a = await MediaCache.loadAudio();
    final v = await MediaCache.loadVideos();
    if (!mounted) return;
    setState(() {
      _audio = a;
      _video = v;
      _loading = false;
    });
  }

  List<AudioTrack> get _filteredAudio {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    return _audio
        .where((t) =>
            t.title.toLowerCase().contains(q) ||
            t.artist.toLowerCase().contains(q) ||
            t.album.toLowerCase().contains(q))
        .take(50)
        .toList();
  }

  List<VideoItem> get _filteredVideo {
    if (_query.isEmpty) return const [];
    final q = _query.toLowerCase();
    return _video
        .where((v) =>
            v.title.toLowerCase().contains(q) ||
            v.folderName.toLowerCase().contains(q))
        .take(30)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioResults = _filteredAudio;
    final videoResults = _filteredVideo;
    final hasResults = audioResults.isNotEmpty || videoResults.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'ابحث في الصوتيات والفيديو...',
            border: InputBorder.none,
          ),
          onChanged: (v) => setState(() => _query = v.trim()),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _controller.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _query.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Opacity(
                        opacity: 0.4,
                        child: Icon(Icons.search, size: 72,
                            color: theme.colorScheme.primary),
                      ),
                      const SizedBox(height: 12),
                      const Text('اكتب للبحث'),
                    ],
                  ),
                )
              : !hasResults
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off,
                              size: 64,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text('لا توجد نتائج لـ "$_query"'),
                        ],
                      ),
                    )
                  : ListView(
                      children: [
                        if (audioResults.isNotEmpty) ...[
                          _sectionHeader(
                              'الصوتيات', audioResults.length),
                          ...audioResults.asMap().entries.map((e) {
                            final i = e.key;
                            final t = e.value;
                            return ListTile(
                              leading:
                                  TrackArtwork(songId: t.id, size: 48),
                              title: Text(t.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                '${t.artist} • ${t.album}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                final player = Provider.of<PlayerProvider>(
                                    context,
                                    listen: false);
                                player.setPlaylist(audioResults,
                                    startIndex: i);
                              },
                            );
                          }),
                        ],
                        if (videoResults.isNotEmpty) ...[
                          _sectionHeader(
                              'الفيديوهات', videoResults.length),
                          ...videoResults.asMap().entries.map((e) {
                            final i = e.key;
                            final v = e.value;
                            return ListTile(
                              leading: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(Icons.play_circle_outline,
                                    color: theme.colorScheme.primary),
                              ),
                              title: Text(v.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              subtitle: Text(
                                v.folderName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => VideoPlayerScreen(
                                      videoPath: v.path,
                                      title: v.title,
                                      playlist: videoResults,
                                      initialIndex: i,
                                    ),
                                  ),
                                );
                              },
                            );
                          }),
                        ],
                        const SizedBox(height: 20),
                      ],
                    ),
    );
  }

  Widget _sectionHeader(String title, int count) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count', style: const TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
