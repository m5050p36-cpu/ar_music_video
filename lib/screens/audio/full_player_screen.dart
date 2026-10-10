import 'package:audio_video_progress_bar/audio_video_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../providers/player_provider.dart';

class FullPlayerScreen extends StatelessWidget {
  const FullPlayerScreen({super.key});

  String _loopLabel(String key, BuildContext context) {
    switch (key) {
      case 'none':
        return context.tr('player_loop_none');
      case 'repeatOnce':
        return context.tr('player_loop_once');
      case 'repeatTwice':
        return context.tr('player_loop_twice');
      case 'repeatThrice':
        return context.tr('player_loop_thrice');
      case 'repeatAll':
        return context.tr('player_loop_all');
      default:
        return '';
    }
  }

  void _showSleepTimerDialog(
    BuildContext context,
    PlayerProvider provider,
  ) {
    final durations = [5, 10, 15, 30, 60, 120];
    final tTitle = context.tr('player_sleep_timer');
    final tCancel = context.tr('player_cancel_timer');
    final tHour = context.tr('player_hour');
    final tMin = context.tr('player_minute');

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...durations.map((m) => ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: Text(
                    m >= 60 ? '${m ~/ 60} $tHour' : '$m $tMin',
                  ),
                  onTap: () {
                    provider.setSleepTimer(m);
                    Navigator.pop(context);
                  },
                )),
            if (provider.remainingSleepDuration != null)
              ListTile(
                leading:
                    const Icon(Icons.cancel, color: Colors.redAccent),
                title: Text(
                  tCancel,
                  style: const TextStyle(color: Colors.redAccent),
                ),
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

    // استخراج النصوص
    final tNoTrack = context.tr('player_no_track');
    final tPlayerTitle = context.tr('player_full_title');
    final tPointA = context.tr('player_point_a');
    final tPointB = context.tr('player_point_b');

    if (track == null) {
      return Scaffold(
        body: Center(child: Text(tNoTrack)),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tPlayerTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.bedtime_outlined),
            tooltip: context.tr('player_sleep_timer'),
            onPressed: () => _showSleepTimerDialog(context, player),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                    color:
                        theme.colorScheme.primary.withValues(alpha: 0.2),
                    child: track.albumArtBytes != null
                        ? Image.memory(
                            track.albumArtBytes!,
                            fit: BoxFit.cover,
                          )
                        : Icon(
                            Icons.music_note,
                            size: 100,
                            color: theme.colorScheme.primary,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  track.title,
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${track.artist} • ${track.album}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: 24),

              // شريط التقدم
              StreamBuilder<Duration>(
                stream: player.player.positionStream,
                builder: (context, snapshot) {
                  final position = snapshot.data ?? Duration.zero;
                  final total =
                      player.player.duration ?? track.duration;
                  return ProgressBar(
                    progress: position,
                    total: total,
                    progressBarColor: theme.colorScheme.primary,
                    baseBarColor: theme.colorScheme.surface
                        .withValues(alpha: 0.5),
                    thumbColor: theme.colorScheme.primary,
                    onSeek: (pos) => player.player.seek(pos),
                  );
                },
              ),

              const SizedBox(height: 16),

              // A-B Repeat
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: player.setPointA,
                    child: Text(
                      player.pointA != null
                          ? '$tPointA: ${player.pointA!.inSeconds}s'
                          : tPointA,
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: player.setPointB,
                    child: Text(
                      player.pointB != null
                          ? '$tPointB: ${player.pointB!.inSeconds}s'
                          : tPointB,
                    ),
                  ),
                  if (player.pointA != null || player.pointB != null) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.close,
                          size: 20, color: Colors.redAccent),
                      onPressed: player.clearABRepeat,
                    ),
                  ],
                ],
              ),

              const Spacer(),

              // أزرار التحكم
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Loop
                  IconButton(
                    icon: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.repeat,
                          color: player.loopMode !=
                                  CustomLoopMode.repeatAll &&
                              player.loopMode != CustomLoopMode.none
                              ? theme.colorScheme.primary
                              : null,
                        ),
                        Text(
                          _loopLabel(player.loopMode.name, context),
                          style: const TextStyle(fontSize: 9),
                        ),
                      ],
                    ),
                    onPressed: player.toggleLoopMode,
                  ),

                  // Previous
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 36),
                    onPressed: player.playPrevious,
                  ),

                  // Play/Pause
                  IconButton(
                    icon: Icon(
                      player.player.playing
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      size: 64,
                      color: theme.colorScheme.primary,
                    ),
                    onPressed: player.togglePlayPause,
                  ),

                  // Next
                  IconButton(
                    icon: const Icon(Icons.skip_next_rounded, size: 36),
                    onPressed: player.playNext,
                  ),

                  // Speed
                  PopupMenuButton<double>(
                    initialValue: player.speed,
                    onSelected: player.setPlaybackSpeed,
                    itemBuilder: (_) => [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0]
                        .map((s) => PopupMenuItem(
                              value: s,
                              child: Text('${s}x'),
                            ))
                        .toList(),
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
