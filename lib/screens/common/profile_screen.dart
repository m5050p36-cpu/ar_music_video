import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/profile_service.dart';
import '../../core/services/supabase_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _picker = ImagePicker();

  bool _isSavingName = false;
  bool _isUploadingAvatar = false;
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = (auth.profile?['full_name'] ?? '').toString();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar(ImageSource source) async {
    if (_isUploadingAvatar) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;
    final messenger = ScaffoldMessenger.of(context);

    if (userId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('profile_guest_cant_edit'))),
      );
      return;
    }

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;

      setState(() {
        _isUploadingAvatar = true;
        _localAvatarPath = picked.path;
      });

      final url = await ProfileService.updateAvatar(
        userId: userId,
        file: File(picked.path),
      );

      if (!mounted) return;

      if (url != null) {
        await auth.refreshProfile();
        if (!mounted) return;
        setState(() => _isUploadingAvatar = false);
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('profile_avatar_updated'))),
        );
      } else {
        setState(() {
          _isUploadingAvatar = false;
          _localAvatarPath = null;
        });
        messenger.showSnackBar(
          SnackBar(content: Text(context.tr('profile_avatar_failed'))),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
        _localAvatarPath = null;
      });
      messenger.showSnackBar(
        SnackBar(content: Text('${context.tr('common_error')}: $e')),
      );
    }
  }

  Future<void> _removeAvatar() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    setState(() => _isUploadingAvatar = true);
    final ok = await ProfileService.updateAvatarUrl(
      userId: userId,
      avatarUrl: null,
    );
    if (!mounted) return;

    if (ok) {
      await auth.refreshProfile();
      if (!mounted) return;
      setState(() {
        _isUploadingAvatar = false;
        _localAvatarPath = null;
      });
    } else {
      setState(() => _isUploadingAvatar = false);
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('profile_avatar_failed'))),
      );
    }
  }

  void _showAvatarSheet() {
    final theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('profile_change_photo'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(context.tr('profile_photo_gallery')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(context.tr('profile_photo_camera')),
              onTap: () {
                Navigator.pop(ctx);
                _pickAvatar(ImageSource.camera);
              },
            ),
            if ((Provider.of<AuthProvider>(context, listen: false)
                        .profile?['avatar_url'] ??
                    '')
                .toString()
                .isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                title: Text(
                  context.tr('profile_photo_remove'),
                  style: const TextStyle(color: Colors.redAccent),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _removeAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _saveName() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final userId = auth.currentUser?.id;

    if (userId == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('profile_guest_cant_edit'))),
      );
      return;
    }

    if (!SupabaseService.isInitialized) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('profile_no_connection'))),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('fill_fullname'))),
      );
      return;
    }

    setState(() => _isSavingName = true);
    final ok = await ProfileService.updateFullName(
      userId: userId,
      fullName: name,
    );

    if (!mounted) return;
    setState(() => _isSavingName = false);

    if (ok) {
      await auth.refreshProfile();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('profile_updated'))),
      );
    } else {
      messenger.showSnackBar(
        SnackBar(content: Text(context.tr('profile_no_connection'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    // اجعل الصفحة تُعيد البناء عند تغيير اللغة
    Provider.of<LanguageProvider>(context);

    final avatarUrl = (auth.profile?['avatar_url'] ?? '').toString();
    final email = auth.currentUser?.email ?? context.tr('drawer_guest');

    String roleText;
    if (auth.isAdmin) {
      roleText = context.tr('profile_role_admin');
    } else if (auth.isGuest) {
      roleText = context.tr('profile_role_guest');
    } else {
      roleText = context.tr('profile_role_user');
    }

    return Scaffold(
      appBar: AppBar(title: Text(context.tr('profile_title'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // ─── الصورة الرمزية ───
            Center(
              child: GestureDetector(
                onTap: _isUploadingAvatar ? null : _showAvatarSheet,
                child: Stack(
                  children: [
                    Container(
                      width: 130,
                      height: 130,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.15),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.4),
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: _buildAvatarContent(avatarUrl),
                      ),
                    ),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: _isUploadingAvatar
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.camera_alt,
                                size: 18,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              context.tr('profile_change_photo'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // ─── البريد ───
            Text(
              email,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // ─── الشارة ───
            Chip(
              avatar: Icon(
                auth.isAdmin
                    ? Icons.verified_user
                    : (auth.isGuest ? Icons.person_outline : Icons.person),
                size: 16,
                color: theme.colorScheme.primary,
              ),
              label: Text(
                roleText,
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor:
                  theme.colorScheme.primary.withValues(alpha: 0.12),
              side: BorderSide.none,
            ),

            const SizedBox(height: 32),

            if (!auth.isGuest) ...[
              // ─── الاسم ───
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('profile_name_label'),
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ─── زر الحفظ ───
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSavingName ? null : _saveName,
                  icon: _isSavingName
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(context.tr('profile_save')),
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarContent(String url) {
    // صورة محلية (وقت الرفع)
    if (_localAvatarPath != null && File(_localAvatarPath!).existsSync()) {
      return Image.file(
        File(_localAvatarPath!),
        fit: BoxFit.cover,
        width: 130,
        height: 130,
      );
    }
    // صورة من السيرفر
    if (url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: 130,
        height: 130,
        placeholder: (_, __) => Icon(
          Icons.person,
          size: 60,
          color: Theme.of(context).colorScheme.primary,
        ),
        errorWidget: (_, __, ___) => Icon(
          Icons.person,
          size: 60,
          color: Theme.of(context).colorScheme.primary,
        ),
      );
    }
    // افتراضية
    return Icon(
      Icons.person,
      size: 60,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
