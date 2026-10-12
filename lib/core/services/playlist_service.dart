import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/audio_track.dart';

class Playlist {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<PlaylistItem> items;

  Playlist({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'items': items.map((i) => i.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      items: (json['items'] as List)
          .map((i) => PlaylistItem.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
    );
  }
}

class PlaylistItem {
  final String path;
  final String title;
  final String artist;
  final String album;
  final String trackId;
  final int durationMs;

  PlaylistItem({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.trackId,
    required this.durationMs,
  });

  Map<String, dynamic> toJson() => {
        'path': path,
        'title': title,
        'artist': artist,
        'album': album,
        'trackId': trackId,
        'durationMs': durationMs,
      };

  factory PlaylistItem.fromJson(Map<String, dynamic> json) => PlaylistItem(
        path: json['path'] ?? '',
        title: json['title'] ?? '',
        artist: json['artist'] ?? '',
        album: json['album'] ?? '',
        trackId: json['trackId'] ?? '',
        durationMs: json['durationMs'] ?? 0,
      );

  AudioTrack toAudioTrack() => AudioTrack(
        id: trackId,
        title: title,
        artist: artist,
        album: album,
        path: path,
        duration: Duration(milliseconds: durationMs),
      );
}

class PlaylistService {
  PlaylistService._();

  static const _key = 'user_playlists_v1';

  static Future<List<Playlist>> getAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return [];
      final list = (jsonDecode(raw) as List)
          .map((j) => Playlist.fromJson(Map<String, dynamic>.from(j)))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (e) {
      debugPrint('PlaylistService.getAll error: $e');
      return [];
    }
  }

  static Future<void> _saveAll(List<Playlist> list) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(list.map((p) => p.toJson()).toList()),
    );
  }

  static Future<Playlist> create(String name) async {
    final all = await getAll();
    final playlist = Playlist(
      id: 'pl_${DateTime.now().millisecondsSinceEpoch}',
      name: name.trim(),
      createdAt: DateTime.now(),
      items: const [],
    );
    all.insert(0, playlist);
    await _saveAll(all);
    return playlist;
  }

  static Future<bool> rename(String id, String newName) async {
    final all = await getAll();
    final idx = all.indexWhere((p) => p.id == id);
    if (idx < 0) return false;
    all[idx] = Playlist(
      id: all[idx].id,
      name: newName.trim(),
      createdAt: all[idx].createdAt,
      items: all[idx].items,
    );
    await _saveAll(all);
    return true;
  }

  static Future<bool> delete(String id) async {
    final all = await getAll();
    all.removeWhere((p) => p.id == id);
    await _saveAll(all);
    return true;
  }

  static Future<bool> addTrack(String playlistId, AudioTrack track) async {
    final all = await getAll();
    final idx = all.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return false;
    final pl = all[idx];
    if (pl.items.any((i) => i.path == track.path)) return true;
    pl.items.add(PlaylistItem(
      path: track.path,
      title: track.title,
      artist: track.artist,
      album: track.album,
      trackId: track.id,
      durationMs: track.duration.inMilliseconds,
    ));
    await _saveAll(all);
    return true;
  }

  static Future<bool> removeTrack(String playlistId, String path) async {
    final all = await getAll();
    final idx = all.indexWhere((p) => p.id == playlistId);
    if (idx < 0) return false;
    all[idx].items.removeWhere((i) => i.path == path);
    await _saveAll(all);
    return true;
  }
}
