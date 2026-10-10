import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/config/supabase_config.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/supabase_service.dart';
import 'banner_editor_screen.dart';

class AdminBannersTab extends StatefulWidget {
  const AdminBannersTab({super.key});

  @override
  State<AdminBannersTab> createState() => _AdminBannersTabState();
}

class _AdminBannersTabState extends State<AdminBannersTab> {
  List<Map<String, dynamic>> _banners = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    if (!SupabaseService.isInitialized) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = context.tr('admin_no_connection');
      });
      return;
    }

    try {
      final res = await SupabaseService.client
          .from('banners')
          .select()
          .order('display_order', ascending: true)
          .timeout(SupabaseConfig.timeout);

      if (!mounted) return;
      setState(() {
        _banners = List<Map<String, dynamic>>.from(res);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '${context.tr('common_error')}: $e';
      });
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? banner}) async {
    final nextOrder = _banners.isEmpty
        ? 1
        : (_banners
                    .map((b) => (b['display_order'] as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a > b ? a : b) +
                1);

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BannerEditorScreen(
          existing: banner,
          nextOrder: nextOrder,
        ),
      ),
    );

    if (saved == true) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('banner_saved'))),
      );
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> banner) async {
    final newValue = !(banner['is_active'] == true);
    final ok = await AdminService.toggleBannerActive(
      banner['id'] as String,
      newValue,
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        final idx = _banners.indexWhere((b) => b['id'] == banner['id']);
        if (idx >= 0) _banners[idx]['is_active'] = newValue;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('admin_failed'))),
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> banner) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.tr('banner_delete_title')),
        content: Text(context.tr('banner_delete_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(context.tr('common_cancel')),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(context.tr('common_delete')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await AdminService.deleteBanner(banner['id'] as String);
    if (!mounted) return;
    if (ok) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('banner_deleted'))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('admin_failed'))),
      );
    }
  }

  Future<void> _move(Map<String, dynamic> banner, int direction) async {
    final idx = _banners.indexWhere((b) => b['id'] == banner['id']);
    if (idx < 0) return;

    final newIdx = idx + direction;
    if (newIdx < 0 || newIdx >= _banners.length) return;

    final other = _banners[newIdx];

    final ok = await AdminService.swapBannerOrder(
      idA: banner['id'] as String,
      orderA: (banner['display_order'] as num?)?.toInt() ?? 0,
      idB: other['id'] as String,
      orderB: (other['display_order'] as num?)?.toInt() ?? 0,
    );

    if (!mounted) return;
    if (ok) {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    // استخراج النصوص
    final tAddFab = context.tr('banner_add_fab');
    final tEmpty = context.tr('banner_empty');
    final tRetry = context.tr('common_retry');

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: Colors.redAccent),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: Text(tRetry),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add_photo_alternate),
        label: Text(tAddFab),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _banners.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.image_not_supported_outlined,
                            size: 64),
                        const SizedBox(height: 12),
                        Text(tEmpty),
                      ],
                    ),
                  ),
                ],
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
                itemCount: _banners.length,
                itemBuilder: (context, i) {
                  final b = _banners[i];
                  return _BannerCard(
                    banner: b,
                    index: i,
                    total: _banners.length,
                    onEdit: () => _openEditor(banner: b),
                    onDelete: () => _delete(b),
                    onToggle: () => _toggleActive(b),
                    onMoveUp: () => _move(b, -1),
                    onMoveDown: () => _move(b, 1),
                  );
                },
              ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Map<String, dynamic> banner;
  final int index;
  final int total;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggle;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;

  const _BannerCard({
    required this.banner,
    required this.index,
    required this.total,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = banner['is_active'] == true;
    final title = (banner['title'] ?? '').toString();
    final target = (banner['target_url'] ?? '').toString();
    final height = (banner['height'] as num?)?.toInt() ?? 145;
    final order = (banner['display_order'] as num?)?.toInt() ?? 0;

    // استخراج النصوص
    final tDisabled = context.tr('banner_disabled');
    final tHeight = context.tr('banner_height_label');
    final tMoveUp = context.tr('banner_move_up');
    final tMoveDown = context.tr('banner_move_down');
    final tEnable = context.tr('banner_enable');
    final tDisable = context.tr('banner_disable');
    final tEdit = context.tr('common_edit');
    final tDelete = context.tr('common_delete');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height > 180 ? 180 : height.toDouble(),
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: banner['image_url'] ?? '',
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: Colors.grey.withValues(alpha: 0.3),
                    child: const Icon(Icons.broken_image),
                  ),
                ),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '#$order',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                if (!isActive)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Chip(
                          label: Text(
                            tDisabled,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: Colors.redAccent,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title.isNotEmpty) ...[
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                ],
                if (target.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.link, size: 14),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          target,
                          style: const TextStyle(fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 4),
                Text(
                  '$tHeight: $height px',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Row(
            children: [
              Expanded(
                child: IconButton(
                  onPressed: index > 0 ? onMoveUp : null,
                  icon: const Icon(Icons.keyboard_arrow_up),
                  tooltip: tMoveUp,
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: index < total - 1 ? onMoveDown : null,
                  icon: const Icon(Icons.keyboard_arrow_down),
                  tooltip: tMoveDown,
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: onToggle,
                  icon: Icon(
                    isActive ? Icons.visibility : Icons.visibility_off,
                    color: isActive ? Colors.green : Colors.grey,
                  ),
                  tooltip: isActive ? tDisable : tEnable,
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  tooltip: tEdit,
                ),
              ),
              Expanded(
                child: IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                  tooltip: tDelete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
