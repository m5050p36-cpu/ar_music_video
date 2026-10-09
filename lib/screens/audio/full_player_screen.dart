import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import '../../providers/player_provider.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  String _getLoopLabel(CustomLoopMode mode) {
    switch (mode) {
      case CustomLoopMode.none: return 'بدون تكرار';
      case CustomLoopMode.repeatOnce: return 'مرة';
      case CustomLoopMode.repeatTwice: return 'مرتين';
      case CustomLoopMode.repeatThrice: return '3 مرات';
      case CustomLoopMode.repeatAll: return 'الكل';
    }
  }

  void _showSleepTimerDialog(BuildContext context, PlayerProvider provider) {
    final durations = [5, 10, 15, 30, 60, 120];
    showModalBottomSheet(
      context: context,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('مؤقت النوم', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...durations.map((m) => ListTile(
              title: Text(m >= 60 ? '${m ~/ 60} ساعة' : '$m دقيقة'),
              onTap: () {
                provider.setSleepTimer(m);
                Navigator.pop(context);
              },
            )),
            if (provider.remainingSleepDuration != null)
              ListTile(
                title: const Text('إلغاء المؤقت', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  provider.cancelSleepTimer();
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = Provider.of<PlayerProvider>(context);
    final track = player.currentTrack;
    final theme = Theme.of(context);

    if (track == null) {
      return const Scaffold(body: Center(child: Text('لا يوجد مقطع قيد التشغيل')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المشغل الصوتي'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bedtime_outlined),
            onPressed: () => _showSleepTimerDialog(context, player),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              const Spacer(),
              Hero(
                tag: 'album_art_${track.id}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxHeight: 320),
                    color: theme.colorScheme.primary.withAlpha(50),
                    child: track.albumArtBytes != null
                        ? Image.memory(track.albumArtBytes!, fit: BoxFit.cover)
                        : Icon(Icons.music_note, size: 100, color: theme.colorScheme.primary),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  track.title,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${track.artist} • ${track.album}',
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withAlpha(160)),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 24),

              StreamBuilder<Duration>(
                stream: player.player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final total = player.player.duration ?? track.duration;
                  return ProgressBar(
                    progress: position,
                    total: total,
                    progressBarColor: theme.colorScheme.primary,
                    baseBarColor: theme.colorScheme.surface.withAlpha(120),
                    thumbColor: theme.colorScheme.primary,
                    onSeek: (pos) => player.player.seek(pos),
                  );
                },
              ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: player.setPointA,
                    child: Text(player.pointA != null ? 'A: ${player.pointA!.inSeconds}s' : 'نقطة A'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: player.setPointB,
                    child: Text(player.pointB != null ? 'B: ${player.pointB!.inSeconds}s' : 'نقطة B'),
                  ),
                  if (player.pointA != null || player.pointB != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20, color: Colors.redAccent),
                      onPressed: player.clearABRepeat,
                    ),
                  ],
                ],
              ),

              const Spacer(),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.repeat, color: player.loopMode != CustomLoopMode.none ? theme.colorScheme.primary : null),
                        Text(_getLoopLabel(player.loopMode), style: const TextStyle(fontSize: 9)),
                      ],
                    ),
                    onPressed: player.toggleLoopMode,
                  ),

                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 36),
                    onPressed: player.playPrevious,
                  ),

                  IconButton(
                    icon: Icon(
                      player.player.playing ? Icons.pause_circle_filled_rounded : Icons.play_circle_filled_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: player.togglePlayPause,
                  ),

                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 36),
                    onPressed: player.playNext,
                  ),

                  PopupMenuButton<double>(
                    initialValue: player.speed,
                    onSelected: player.setPlaybackSpeed,
                    itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0].map((s) => PopupMenuItem(
                      value: s,
                      child: Text('${s}x'),
                    )).toList(),
                    child: Chip(label: Text('${player.speed}x')),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
