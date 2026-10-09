import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _nameController.text = auth.profile?['full_name'] ?? '';
  }

  Future<void> _updateProfile() async {
    setState(() => _isSaving = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final userId = auth.currentUser?.id;

    if (userId != null) {
      try {
        await SupabaseService.client
            .from('profiles')
            .update({'full_name': _nameController.text.trim()})
            .eq('id', userId)
            .timeout(SupabaseService.defaultTimeout);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تحديث البيانات بنجاح')),
          );
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('فشل التحديث، تأكد من الاتصال')),
          );
        }
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('الملف الشخصي')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: theme.colorScheme.primary.withAlpha(40),
                    child: Icon(Icons.person, size: 64, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              auth.currentUser?.email ?? 'وضع الزائر (غير مسجل)',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Chip(
              label: Text(
                auth.isAdmin ? 'مشرف (Admin)' : (auth.isGuest ? 'زائر (Guest)' : 'مستخدم (User)'),
                style: const TextStyle(fontSize: 12),
              ),
              backgroundColor: theme.colorScheme.primary.withAlpha(30),
            ),
            const SizedBox(height: 32),

            if (!auth.isGuest) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'الاسم الكامل',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _updateProfile,
                  child: _isSaving ? const CircularProgressIndicator() : const Text('حفظ التعديلات'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
