import 'dart:typed_data';

class AudioTrack {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final Duration duration;
  final Uint8List? albumArtBytes;
  final String? albumArtUri;

  AudioTrack({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
    this.albumArtBytes,
    this.albumArtUri,
  });

  factory AudioTrack.fromMap(Map<String, dynamic> map) {
    return AudioTrack(
      id: map['id'] ?? '',
      title: map['title'] ?? 'مقطع صوتي',
      artist: map['artist'] ?? 'فنان غير معروف',
      album: map['album'] ?? 'ألبوم عام',
      path: map['path'] ?? '',
      duration: Duration(milliseconds: map['durationMs'] ?? 0),
      albumArtUri: map['albumArtUri'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'artist': artist,
    'album': album,
    'path': path,
    'durationMs': duration.inMilliseconds,
    'albumArtUri': albumArtUri,
  };
}
