import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

/// cache للصور المصغرة — 3 طبقات:
/// 1. ذاكرة (LRU، 150 صورة)
/// 2. قرص (دائم في app_support/video_thumbs)
/// 3. توليد من AssetEntity (عند الطلب فقط)
class VideoThumbnailCache {
  VideoThumbnailCache._();

  static const int _maxMemoryItems = 150;

  /// LRU memory cache
  static final LinkedHashMap<String, Uint8List> _mem = LinkedHashMap();
  static Directory? _dir;

  /// Futures الجارية (لمنع طلبات متكررة)
  static final Map<String, Future<Uint8List?>> _pending = {};

  static Future<Directory> _getDir() async {
    if (_dir != null && _dir!.existsSync()) return _dir!;
    final base = await getApplicationSupportDirectory();
    final d = Directory('${base.path}/video_thumbs');
    if (!d.existsSync()) await d.create(recursive: true);
    _dir = d;
    return d;
  }

  static void _putMem(String key, Uint8List bytes) {
    if (_mem.length >= _maxMemoryItems) {
      _mem.remove(_mem.keys.first); // احذف الأقدم
    }
    _mem[key] = bytes;
    // حرّك للمؤخرة (MRU)
    _mem.remove(key);
    _mem[key] = bytes;
  }

  /// يُعيد الصورة المصغرة — من الذاكرة أو القرص أو توليد جديد.
  /// [asset] يمكن أن يكون null عند التحميل من cache — عندها يعتمد على القرص فقط.
  static Future<Uint8List?> get({
    required String assetId,
    AssetEntity? asset,
  }) {
    // 1. ذاكرة
    if (_mem.containsKey(assetId)) {
      return Future.value(_mem[assetId]);
    }
    // 2. طلب جارٍ
    if (_pending.containsKey(assetId)) {
      return _pending[assetId]!;
    }

    final future = _load(assetId: assetId, asset: asset);
    _pending[assetId] = future;
    future.whenComplete(() => _pending.remove(assetId));
    return future;
  }

  static Future<Uint8List?> _load({
    required String assetId,
    AssetEntity? asset,
  }) async {
    try {
      final dir = await _getDir();
      final file = File('${dir.path}/$assetId.jpg');

      // قرص
      if (await file.exists()) {
        final len = await file.length();
        if (len > 0) {
          final bytes = await file.readAsBytes();
          _putMem(assetId, bytes);
          return bytes;
        }
      }

      // لا AssetEntity → لا نستطيع التوليد
      if (asset == null) return null;

      // توليد من MediaStore (سريع — لا يقرأ الفيديو كاملاً)
      final bytes = await asset.thumbnailDataWithSize(
        const ThumbnailSize(400, 400),
        quality: 70,
      );
      if (bytes == null) return null;

      _putMem(assetId, bytes);

      // احفظ على القرص (غير حاجب للواجهة)
      unawaited(_writeDisk(file, bytes));
      return bytes;
    } catch (e) {
      debugPrint('VideoThumbnailCache error ($assetId): $e');
      return null;
    }
  }

  static Future<void> _writeDisk(File f, Uint8List bytes) async {
    try {
      await f.writeAsBytes(bytes, flush: false);
    } catch (_) {}
  }

  /// حذف صورة مصغرة (عند حذف الفيديو)
  static Future<void> remove(String assetId) async {
    _mem.remove(assetId);
    try {
      final dir = await _getDir();
      final f = File('${dir.path}/$assetId.jpg');
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// مسح كامل
  static Future<void> clearAll() async {
    _mem.clear();
    _pending.clear();
    try {
      final dir = await _getDir();
      if (dir.existsSync()) {
        for (final e in dir.listSync()) {
          if (e is File) {
            try {
              await e.delete();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}

/// مساعد لتنفيذ async دون انتظار
void unawaited(Future<void> f) {}
