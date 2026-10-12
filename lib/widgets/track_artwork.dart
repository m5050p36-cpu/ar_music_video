import 'package:flutter/material.dart';

import '../core/services/album_art_service.dart';

/// عرض غلاف الألبوم — وإذا لم يوجد، يظهر شعار AR.
class TrackArtwork extends StatelessWidget {
  final String songId;
  final double size;
  final double borderRadius;
  final Color? fallbackColor;
  final IconData fallbackIcon;
  final bool showFallbackIcon;

  const TrackArtwork({
    super.key,
    required this.songId,
    this.size = 52,
    this.borderRadius = 8,
    this.fallbackColor,
    this.fallbackIcon = Icons.music_note,
    this.showFallbackIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = fallbackColor ??
        theme.colorScheme.primary.withValues(alpha: 0.12);

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
            if (snapshot.connectionState != ConnectionState.done) {
              return Container(
                color: color,
                alignment: Alignment.center,
                child: SizedBox(
                  width: size * 0.3,
                  height: size * 0.3,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
              );
            }
            return _fallback(color);
          },
        ),
      ),
    );
  }

  Widget _fallback(Color color) {
    if (showFallbackIcon) {
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
    // ✨ شعار AR
    return Container(
      color: color,
      alignment: Alignment.center,
      padding: EdgeInsets.all(size * 0.15),
      child: Image.asset(
        'assets/images/ar_logo.png',
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(
          Icons.music_note,
          color: Colors.white.withValues(alpha: 0.85),
          size: size * 0.5,
        ),
      ),
    );
  }
}
