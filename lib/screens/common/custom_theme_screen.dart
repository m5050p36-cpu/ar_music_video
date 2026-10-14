import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/custom_theme.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/color_picker_sheet.dart';

class CustomThemeScreen extends StatefulWidget {
  const CustomThemeScreen({super.key});

  @override
  State<CustomThemeScreen> createState() => _CustomThemeScreenState();
}

class _CustomThemeScreenState extends State<CustomThemeScreen> {
  late CustomTheme _working;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ThemeProvider>(context, listen: false);
    _working = provider.custom ??
        (provider.mode.isLight
            ? CustomTheme.defaultLight
            : CustomTheme.defaultDark);
  }

  Future<void> _pickColor(
    String title,
    Color current,
    CustomTheme Function(Color) apply,
  ) async {
    final picked = await ColorPickerSheet.show(
      context,
      initialColor: current,
      title: title,
    );
    if (picked == null || !mounted) return;
    setState(() => _working = apply(picked));
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final provider = Provider.of<ThemeProvider>(context, listen: false);
    await provider.setCustomTheme(_working);
    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ تم تطبيق الثيم المخصص')),
    );
    Navigator.pop(context);
  }

  Future<void> _reset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('إعادة التعيين؟'),
        content: const Text(
          'سيتم استرجاع الألوان الافتراضية. لن تفقد الثيمات الأخرى.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('إعادة التعيين'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() {
      _working = _working.isLight
          ? CustomTheme.defaultLight
          : CustomTheme.defaultDark;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تخصيص الألوان'),
        actions: [
          IconButton(
            icon: const Icon(Icons.restart_alt),
            tooltip: 'إعادة التعيين',
            onPressed: _reset,
          ),
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('حفظ'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ═══ المعاينة الحيّة ═══
          _buildLivePreview(theme),
          const SizedBox(height: 20),

          // ═══ الوضع ═══
          _sectionTitle('النمط الأساسي', theme),
          Card(
            child: SwitchListTile(
              secondary: Icon(
                _working.isLight ? Icons.light_mode : Icons.dark_mode,
                color: _working.primary,
              ),
              title: Text(_working.isLight ? 'وضع فاتح' : 'وضع داكن'),
              subtitle: const Text('يؤثر على النصوص والأيقونات الافتراضية'),
              value: _working.isLight,
              onChanged: (v) => setState(() {
                _working = _working.copyWith(isLight: v);
              }),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ الألوان الأساسية ═══
          _sectionTitle('الألوان الأساسية', theme),
          _colorTile(
            title: 'اللون الأساسي',
            subtitle: 'الأزرار والعناصر المميزة',
            color: _working.primary,
            onTap: () => _pickColor(
              'اللون الأساسي',
              _working.primary,
              (c) => _working.copyWith(primary: c),
            ),
          ),
          _colorTile(
            title: 'اللون الثانوي',
            subtitle: 'تدرجات وأزرار ثانوية',
            color: _working.secondary,
            onTap: () => _pickColor(
              'اللون الثانوي',
              _working.secondary,
              (c) => _working.copyWith(secondary: c),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ الخلفيات ═══
          _sectionTitle('الخلفيات', theme),
          _colorTile(
            title: 'خلفية التطبيق',
            subtitle: 'الخلفية العامة لكل الشاشات',
            color: _working.background,
            onTap: () => _pickColor(
              'خلفية التطبيق',
              _working.background,
              (c) => _working.copyWith(background: c),
            ),
          ),
          _colorTile(
            title: 'خلفية البطاقات',
            subtitle: 'الكروت والقوائم',
            color: _working.surface,
            onTap: () => _pickColor(
              'خلفية البطاقات',
              _working.surface,
              (c) => _working.copyWith(surface: c),
            ),
          ),
          _colorTile(
            title: 'خلفية الحقول',
            subtitle: 'حقول الإدخال والعناصر البديلة',
            color: _working.surfaceAlt,
            onTap: () => _pickColor(
              'خلفية الحقول',
              _working.surfaceAlt,
              (c) => _working.copyWith(surfaceAlt: c),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ الشريط العلوي ═══
          _sectionTitle('الشريط العلوي', theme),
          _colorTile(
            title: 'خلفية الشريط',
            subtitle: 'AppBar background',
            color: _working.appBarBg,
            onTap: () => _pickColor(
              'خلفية الشريط',
              _working.appBarBg,
              (c) => _working.copyWith(appBarBg: c),
            ),
          ),
          _colorTile(
            title: 'نص وأيقونات الشريط',
            subtitle: 'لون العنوان والأزرار',
            color: _working.appBarFg,
            onTap: () => _pickColor(
              'نص الشريط',
              _working.appBarFg,
              (c) => _working.copyWith(appBarFg: c),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ الشريط السفلي ═══
          _sectionTitle('الشريط السفلي', theme),
          _colorTile(
            title: 'خلفية الشريط السفلي',
            subtitle: 'Bottom navigation bar',
            color: _working.bottomNavBg,
            onTap: () => _pickColor(
              'خلفية الشريط السفلي',
              _working.bottomNavBg,
              (c) => _working.copyWith(bottomNavBg: c),
            ),
          ),

          const SizedBox(height: 16),

          // ═══ النصوص ═══
          _sectionTitle('النصوص والأيقونات', theme),
          _colorTile(
            title: 'لون النصوص العام',
            subtitle: 'نصوص القوائم والعناوين',
            color: _working.onSurface,
            onTap: () => _pickColor(
              'لون النصوص',
              _working.onSurface,
              (c) => _working.copyWith(onSurface: c),
            ),
          ),
          _colorTile(
            title: 'لون الأخطاء',
            subtitle: 'رسائل الخطأ والتحذيرات',
            color: _working.error,
            onTap: () => _pickColor(
              'لون الأخطاء',
              _working.error,
              (c) => _working.copyWith(error: c),
            ),
          ),

          const SizedBox(height: 32),

          // ═══ الأزرار ═══
          SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.palette_rounded),
              label: const Text('تطبيق الثيم المخصص'),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('استرجاع الافتراضي'),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ═══════════════ المعاينة الحيّة ═══════════════
  Widget _buildLivePreview(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: _working.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _working.primary.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ─── AppBar وهمي ───
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: _working.appBarBg,
            child: Row(
              children: [
                Icon(Icons.menu, color: _working.appBarFg, size: 20),
                const SizedBox(width: 12),
                Text(
                  'AR Music & Video',
                  style: TextStyle(
                    color: _working.appBarFg,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(Icons.search, color: _working.appBarFg, size: 20),
              ],
            ),
          ),

          // ─── منطقة محتوى ───
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // كرت أغنية
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _working.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _working.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.music_note,
                          color: _working.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'عنوان الأغنية',
                              style: TextStyle(
                                color: _working.onSurface,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'اسم الفنان',
                              style: TextStyle(
                                color: _working.onSurface
                                    .withValues(alpha: 0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.play_arrow,
                        color: _working.primary,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // حقول وأزرار
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: _working.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'حقل إدخال',
                          style: TextStyle(
                            color: _working.onSurface
                                .withValues(alpha: 0.5),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _working.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'زر',
                        style: TextStyle(
                          color: _working.primary.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Bottom nav وهمي ───
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            color: _working.bottomNavBg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Icon(
                  Icons.music_note,
                  color: _working.primary,
                  size: 22,
                ),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _working.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'AR',
                      style: TextStyle(
                        color: _working.primary.computeLuminance() > 0.5
                            ? Colors.black
                            : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                Icon(
                  Icons.video_library,
                  color: _working.onSurface.withValues(alpha: 0.5),
                  size: 22,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        text,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
        ),
      ),
    );
  }

  Widget _colorTile({
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 4,
        ),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(Icons.colorize, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 11),
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: onTap,
      ),
    );
  }
}
