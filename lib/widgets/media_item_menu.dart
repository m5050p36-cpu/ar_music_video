import 'package:flutter/material.dart';

import '../core/localization/app_strings.dart';
import '../core/services/file_ops_service.dart';

/// زر 3 نقاط مع خيارات: نقل، نسخ، حذف
class MediaItemMenu extends StatelessWidget {
  final String path;
  final bool isVideo;
  final String? songId;
  final String? assetId;
  final VoidCallback? onChanged;

  const MediaItemMenu({
    super.key,
    required this.path,
    required this.isVideo,
    this.songId,
    this.assetId,
    this.onChanged,
  });

  // ═══════════════════════════════════════════════════════════════
  // نقل
  // ═══════════════════════════════════════════════════════════════
  Future<void> _handleMove(BuildContext context) async {
    // حفظ القيم قبل أي await
    final messenger = ScaffoldMessenger.of(context);
    final tMoved = context.tr('file_moved');
    final tFailed = context.tr('file_op_failed');

    final dest = await FileOpsService.pickDestinationDirectory();
    if (dest == null) return;

    final ok = await FileOpsService.moveFile(
      sourcePath: path,
      destDir: dest,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '✅ $tMoved' : '❌ $tFailed'),
      ),
    );
    if (ok) onChanged?.call();
  }

  // ═══════════════════════════════════════════════════════════════
  // نسخ
  // ═══════════════════════════════════════════════════════════════
  Future<void> _handleCopy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final tCopied = context.tr('file_copied');
    final tFailed = context.tr('file_op_failed');

    final dest = await FileOpsService.pickDestinationDirectory();
    if (dest == null) return;

    final ok = await FileOpsService.copyFile(
      sourcePath: path,
      destDir: dest,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '✅ $tCopied' : '❌ $tFailed'),
      ),
    );
    if (ok) onChanged?.call();
  }

  // ═══════════════════════════════════════════════════════════════
  // حذف
  // ═══════════════════════════════════════════════════════════════
  Future<void> _handleDelete(BuildContext context) async {
    final tTitle = context.tr('file_delete_confirm_title');
    final tBody = context.tr('file_delete_confirm_body');
    final tCancel = context.tr('common_cancel');
    final tDelete = context.tr('file_delete');

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tTitle),
        content: Text(tBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tDelete),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final tDeleted = context.tr('file_deleted');
    final tFailed = context.tr('file_op_failed');

    bool ok;
    if (isVideo) {
      ok = await FileOpsService.deleteVideo(
        assetId: assetId ?? '',
        path: path,
      );
    } else {
      ok = await FileOpsService.deleteAudio(
        songId: songId ?? '',
        path: path,
      );
    }

    messenger.showSnackBar(
      SnackBar(
        content: Text(ok ? '✅ $tDeleted' : '❌ $tFailed'),
      ),
    );
    if (ok) onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tOptions = context.tr('common_options');
    final tMove = context.tr('file_move');
    final tCopy = context.tr('file_copy');
    final tDelete = context.tr('file_delete');

    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: tOptions,
      onSelected: (val) {
        switch (val) {
          case 'move':
            _handleMove(context);
            break;
          case 'copy':
            _handleCopy(context);
            break;
          case 'delete':
            _handleDelete(context);
            break;
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'move',
          child: Row(
            children: [
              const Icon(Icons.drive_file_move_outline, size: 20),
              const SizedBox(width: 12),
              Text(tMove),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'copy',
          child: Row(
            children: [
              const Icon(Icons.copy_outlined, size: 20),
              const SizedBox(width: 12),
              Text(tCopy),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline,
                  size: 20, color: Colors.redAccent),
              const SizedBox(width: 12),
              Text(
                tDelete,
                style: const TextStyle(color: Colors.redAccent),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
