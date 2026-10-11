import 'package:flutter/material.dart';

import '../core/services/album_art_service.dart';

/// عرض غلاف الألبوم — من الميتاداتا مباشرة أو من cache.
/// إن لم يُوجد غلاف، يُعرض placeholder ملوّن.
class TrackArtwork extends StatelessWidget {
  final String songId;
  final double size;
  final double borderRadius;
  final Color? fallbackColor;
  final IconData fallbackIcon;

  const TrackArtwork({
    super.key,
    required this.songId,
    this.size = 52,
    this.borderRadius = 8,
    this.fallbackColor,
    this.fallbackIcon = Icons.music_note,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = fallbackColor ??
        theme.colorScheme.primary.withValues(alpha: 0.18);

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
        child: FutureBuilder(
          future: AlbumArtService.getArt(songId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done &&
                snapshot.data != null) {
              return Image.memory(
                snapshot.data!,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _fallback(color),
              );
            }
            return _fallback(color);
          },
        ),
      ),
    );
  }

  Widget _fallback(Color color) {
    return Container(
      color: color,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: Colors.white.withValues(alpha: 0.9),
        size: size * 0.5,
      ),
    );
  }
}
