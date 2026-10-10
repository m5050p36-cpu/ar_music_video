import 'package:flutter/material.dart';

import '../../core/config/supabase_config.dart';
import '../../core/localization/app_strings.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/supabase_service.dart';
import 'admin_banners_tab.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tTitle = context.tr('admin_title');
    final tUsers = context.tr('admin_tab_users');
    final tBanners = context.tr('admin_tab_banners');
    final tVersions = context.tr('admin_tab_versions');

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(tTitle),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.people_alt_rounded),
                text: tUsers,
              ),
              Tab(
                icon: const Icon(Icons.view_carousel_rounded),
                text: tBanners,
              ),
              Tab(
                icon: const Icon(Icons.system_update_rounded),
                text: tVersions,
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            AdminBannersTab(),
            _VersionsTab(),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// تبويب المستخدمين
// ═══════════════════════════════════════════════════════════════
class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _searchQuery = '';
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
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
          .from('profiles')
          .select()
          .order('created_at', ascending: false)
          .timeout(SupabaseConfig.timeout);

      if (!mounted) return;
      setState(() {
        _users = List<Map<String, dynamic>>.from(res);
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

  void _showPasswordDialog(
    String targetUserId,
    String email,
  ) {
    final pwdController = TextEditingController();
    final tChange = context.tr('admin_change_password_for');
    final tNew = context.tr('admin_new_password_label');
    final tNow = context.tr('admin_change_now');
    final tCancel = context.tr('common_cancel');
    final tSuccess = context.tr('admin_password_updated');
    final tFailed = context.tr('admin_failed');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$tChange $email'),
        content: TextField(
          controller: pwdController,
          obscureText: true,
          decoration: InputDecoration(labelText: tNew),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tCancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);

              final success = await AdminService.changeUserPassword(
                targetUserId: targetUserId,
                newPassword: pwdController.text.trim(),
              );

              navigator.pop();
              messenger.showSnackBar(
                SnackBar(content: Text(success ? tSuccess : tFailed)),
              );
            },
            child: Text(tNow),
          ),
        ],
      ),
    );
  }

  void _showRoleDialog(String targetUserId, String currentRole) {
    String selected = currentRole;

    final tTitle = context.tr('admin_edit_role_title');
    final tUser = context.tr('admin_role_user');
    final tAdmin = context.tr('admin_role_admin');
    final tSuperuser = context.tr('admin_role_superuser');
    final tSave = context.tr('common_save');
    final tCancel = context.tr('common_cancel');
    final tSuccess = context.tr('admin_role_updated');
    final tFailed = context.tr('admin_failed');

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(tTitle),
          content: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: [
              DropdownMenuItem(value: 'user', child: Text(tUser)),
              DropdownMenuItem(value: 'admin', child: Text(tAdmin)),
              DropdownMenuItem(value: 'superuser', child: Text(tSuperuser)),
            ],
            onChanged: (val) {
              if (val != null) setDialogState(() => selected = val);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tCancel),
            ),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);

                final success = await AdminService.updateUserRole(
                  targetUserId,
                  selected,
                );

                navigator.pop();
                if (mounted) await _loadUsers();

                messenger.showSnackBar(
                  SnackBar(content: Text(success ? tSuccess : tFailed)),
                );
              },
              child: Text(tSave),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tSearchHint = context.tr('admin_search_hint');
    final tEmpty = context.tr('admin_users_empty');
    final tRetry = context.tr('common_retry');
    final tName = context.tr('admin_name_label');
    final tRole = context.tr('admin_role_label');

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
                onPressed: _loadUsers,
                icon: const Icon(Icons.refresh),
                label: Text(tRetry),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _users.where((u) {
      final email = (u['email'] ?? '').toString().toLowerCase();
      final name = (u['full_name'] ?? '').toString().toLowerCase();
      return email.contains(_searchQuery) || name.contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: tSearchHint,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (val) =>
                setState(() => _searchQuery = val.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(child: Text(tEmpty))
              : RefreshIndicator(
                  onRefresh: _loadUsers,
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final u = filtered[i];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text((u['email'] ?? '').toString()),
                        subtitle: Text(
                          '$tName: ${u['full_name'] ?? ''} • '
                          '$tRole: ${u['role'] ?? 'user'}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.key,
                                  color: Colors.amber),
                              tooltip:
                                  context.tr('admin_change_password_for'),
                              onPressed: () => _showPasswordDialog(
                                u['id'] as String,
                                (u['email'] ?? '').toString(),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.security,
                                  color: Colors.cyan),
                              tooltip:
                                  context.tr('admin_edit_role_title'),
                              onPressed: () => _showRoleDialog(
                                u['id'] as String,
                                (u['role'] ?? 'user').toString(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// تبويب الإصدارات
// ═══════════════════════════════════════════════════════════════
class _VersionsTab extends StatefulWidget {
  const _VersionsTab();

  @override
  State<_VersionsTab> createState() => _VersionsTabState();
}

class _VersionsTabState extends State<_VersionsTab> {
  List<Map<String, dynamic>> _versions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadVersions();
  }

  Future<void> _loadVersions() async {
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
          .from('app_versions')
          .select()
          .order('version_code', ascending: false)
          .timeout(SupabaseConfig.timeout);

      if (!mounted) return;
      setState(() {
        _versions = List<Map<String, dynamic>>.from(res);
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

  @override
  Widget build(BuildContext context) {
    final tRetry = context.tr('common_retry');
    final tForce = context.tr('banner_active');

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
                onPressed: _loadVersions,
                icon: const Icon(Icons.refresh),
                label: Text(tRetry),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVersions,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _versions.length,
        itemBuilder: (context, i) {
          final v = _versions[i];
          final isForce = v['force_update'] == true;

          return Card(
            child: ListTile(
              title: Text(
                '${v['version_name']} (Code: ${v['version_code']})',
              ),
              subtitle: Text(
                '${v['release_notes'] ?? ''}\n${v['download_url'] ?? ''}',
              ),
              isThreeLine: true,
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    tForce,
                    style: const TextStyle(fontSize: 10),
                  ),
                  Switch(
                    value: isForce,
                    activeThumbColor: Colors.redAccent,
                    onChanged: (val) async {
                      await AdminService.toggleForceUpdate(
                        v['id'] as String,
                        val,
                      );
                      if (mounted) await _loadVersions();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
