import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../providers/auth_provider.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/supabase_service.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('لوحة الإدارة المشرفة'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.people_alt_rounded), text: 'المستخدمين'),
              Tab(icon: Icon(Icons.view_carousel_rounded), text: 'البنرات'),
              Tab(icon: Icon(Icons.system_update_rounded), text: 'الإصدارات'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _UsersTab(),
            _BannersTab(),
            _VersionsTab(),
          ],
        ),
      ),
    );
  }
}

// 1. تبويب إدارة المستخدمين
class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  String _searchQuery = '';

  void _showPasswordDialog(BuildContext context, String targetUserId, String email) {
    final pwdController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('تغيير كلمة مرور $email'),
        content: TextField(
          controller: pwdController,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final auth = Provider.of<AuthProvider>(context, listen: false);
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);

              final success = await AdminService.changeUserPassword(
                targetUserId: targetUserId,
                newPassword: pwdController.text.trim(),
                adminId: auth.currentUser?.id ?? '',
              );

              navigator.pop();
              messenger.showSnackBar(
                SnackBar(content: Text(success ? 'تم تحديث كلمة المرور فورياً عبر Edge Function' : 'فشل التحديث')),
              );
            },
            child: const Text('تغيير الآن'),
          ),
        ],
      ),
    );
  }

  void _showRoleDialog(BuildContext context, String targetUserId, String currentRole) {
    String selected = currentRole;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('تعديل صلاحية المستخدم'),
          content: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'user', child: Text('مستخدم عادي (user)')),
              DropdownMenuItem(value: 'admin', child: Text('مشرف (admin)')),
              DropdownMenuItem(value: 'superuser', child: Text('مدير نظام (superuser)')),
            ],
            onChanged: (val) {
              if (val != null) setDialogState(() => selected = val);
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(ctx);
                final success = await AdminService.updateUserRole(targetUserId, selected);
                navigator.pop();
                if (mounted) setState(() {});
                messenger.showSnackBar(
                  SnackBar(content: Text(success ? 'تم تحديث الصلاحية' : 'فشل التحديث')),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'بحث بالبريد أو الاسم...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: SupabaseService.client.from('profiles').select(),
            builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final list = snapshot.data!;
              final filtered = list.where((u) {
                final email = (u['email'] ?? '').toString().toLowerCase();
                final name = (u['full_name'] ?? '').toString().toLowerCase();
                return email.contains(_searchQuery) || name.contains(_searchQuery);
              }).toList();

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, i) {
                  final u = filtered[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(u['email'] ?? ''),
                    subtitle: Text('الاسم: ${u['full_name']} • الصلاحية: ${u['role']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.key, color: Colors.amber),
                          tooltip: 'تغيير كلمة المرور',
                          onPressed: () => _showPasswordDialog(context, u['id'], u['email'] ?? ''),
                        ),
                        IconButton(
                          icon: const Icon(Icons.security, color: Colors.cyan),
                          tooltip: 'تعديل الصلاحية',
                          onPressed: () => _showRoleDialog(context, u['id'], u['role'] ?? 'user'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// 2. تبويب إدارة البنرات الإعلانية
class _BannersTab extends StatefulWidget {
  const _BannersTab();

  @override
  State<_BannersTab> createState() => _BannersTabState();
}

class _BannersTabState extends State<_BannersTab> {
  final _picker = ImagePicker();

  Future<void> _addNewBanner() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    if (!mounted) return;
    final titleController = TextEditingController();
    final linkController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إضافة بنر إعلاني جديد'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'عنوان البنر')),
            TextField(controller: linkController, decoration: const InputDecoration(labelText: 'رابط التوجيه (اختياري)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(ctx);

              final uploadedUrl = await AdminService.uploadBannerImage(File(xfile.path));
              if (uploadedUrl != null) {
                await AdminService.insertBanner(
                  title: titleController.text.trim(),
                  imageUrl: uploadedUrl,
                  targetUrl: linkController.text.trim(),
                  displayOrder: 1,
                );
                navigator.pop();
                if (mounted) setState(() {});
                messenger.showSnackBar(const SnackBar(content: Text('تم رفع وضغط وحفظ البنر بنجاح')));
              } else {
                messenger.showSnackBar(const SnackBar(content: Text('فشل رفع الصورة')));
              }
            },
            child: const Text('رفع وحفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNewBanner,
        icon: const Icon(Icons.add_photo_alternate),
        label: const Text('إضافة بنر'),
      ),
      body: FutureBuilder(
        future: SupabaseService.client.from('banners').select().order('display_order'),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final banners = snapshot.data!;

          if (banners.isEmpty) {
            return const Center(child: Text('لا توجد بنرات مضافة بعد'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: banners.length,
            itemBuilder: (context, i) {
              final b = banners[i];
              return Card(
                clipBehavior: Clip.antiAlias,
                margin: const EdgeInsets.only(bottom: 12),
                child: Column(
                  children: [
                    SizedBox(
                      height: 120,
                      width: double.infinity,
                      child: CachedNetworkImage(
                        imageUrl: b['image_url'] ?? '',
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: Colors.grey.withAlpha(50)),
                      ),
                    ),
                    ListTile(
                      title: Text(b['title'] ?? ''),
                      subtitle: Text(b['target_url'] ?? 'بدون رابط'),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
                        onPressed: () async {
                          await AdminService.deleteBanner(b['id']);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// 3. تبويب إدارة الإصدارات والتحديث الإجباري
class _VersionsTab extends StatefulWidget {
  const _VersionsTab();

  @override
  State<_VersionsTab> createState() => _VersionsTabState();
}

class _VersionsTabState extends State<_VersionsTab> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: SupabaseService.client.from('app_versions').select(),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final versions = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: versions.length,
          itemBuilder: (context, i) {
            final v = versions[i];
            final isForce = v['force_update'] == true;

            return Card(
              child: ListTile(
                title: Text('الإصدار: ${v['version_name']} (Code: ${v['version_code']})'),
                subtitle: Text('ملاحظات: ${v['release_notes']}\nرابط التحميل: ${v['download_url']}'),
                isThreeLine: true,
                trailing: Switch(
                  value: isForce,
                  activeThumbColor: Colors.redAccent,
                  onChanged: (val) async {
                    await AdminService.toggleForceUpdate(v['id'], val);
                    if (mounted) setState(() {});
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}
