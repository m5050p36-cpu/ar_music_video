import 'package:flutter/material.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/playlist_service.dart';
import 'playlist_detail_screen.dart';

class PlaylistsScreen extends StatefulWidget {
  const PlaylistsScreen({super.key});

  @override
  State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  List<Playlist> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final lists = await PlaylistService.getAll();
    if (!mounted) return;
    setState(() {
      _lists = lists;
      _loading = false;
    });
  }

  Future<void> _createDialog() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('قائمة تشغيل جديدة'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'اسم القائمة',
            hintText: 'مثل: أغاني الرياضة',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('common_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('إنشاء'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await PlaylistService.create(name);
    await _load();
  }

  Future<void> _renameDialog(Playlist pl) async {
    final controller = TextEditingController(text: pl.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة تسمية'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.tr('common_cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.tr('common_save')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await PlaylistService.rename(pl.id, name);
    await _load();
  }

  Future<void> _deleteConfirm(Playlist pl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف القائمة؟'),
        content: Text('سيتم حذف "${pl.name}" نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('common_cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('common_delete')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await PlaylistService.delete(pl.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('قوائم التشغيل'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDialog,
        icon: const Icon(Icons.add),
        label: const Text('قائمة جديدة'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.playlist_play,
                        size: 72,
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 12),
                      const Text('لا توجد قوائم بعد'),
                      const SizedBox(height: 4),
                      Text(
                        'اضغط "قائمة جديدة" للبدء',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                  itemCount: _lists.length,
                  itemBuilder: (context, i) {
                    final pl = _lists[i];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.queue_music,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        title: Text(
                          pl.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${pl.items.length} مقطع'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'rename') _renameDialog(pl);
                            if (v == 'delete') _deleteConfirm(pl);
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'rename',
                              child: Row(children: [
                                Icon(Icons.edit_outlined, size: 20),
                                SizedBox(width: 10),
                                Text('إعادة تسمية'),
                              ]),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(children: [
                                Icon(Icons.delete_outline,
                                    size: 20, color: Colors.redAccent),
                                SizedBox(width: 10),
                                Text('حذف',
                                    style:
                                        TextStyle(color: Colors.redAccent)),
                              ]),
                            ),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PlaylistDetailScreen(
                                playlistId: pl.id,
                              ),
                            ),
                          );
                          _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
