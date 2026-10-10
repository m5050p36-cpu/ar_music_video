import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_strings.dart';
import '../../core/services/admin_service.dart';

class BannerEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final int nextOrder;

  const BannerEditorScreen({
    super.key,
    this.existing,
    this.nextOrder = 1,
  });

  @override
  State<BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends State<BannerEditorScreen> {
  final _titleController = TextEditingController();
  final _linkController = TextEditingController();
  final _orderController = TextEditingController();
  final _picker = ImagePicker();

  File? _newImageFile;
  String? _existingImageUrl;
  int _height = 145;
  bool _isActive = true;
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _titleController.text = (e['title'] ?? '').toString();
      _linkController.text = (e['target_url'] ?? '').toString();
      _orderController.text = (e['display_order'] ?? 1).toString();
      _height = (e['height'] as num?)?.toInt() ?? 145;
      _isActive = e['is_active'] == true;
      _existingImageUrl = e['image_url'] as String?;
    } else {
      _orderController.text = widget.nextOrder.toString();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _linkController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final x = await _picker.pickImage(
        source: source,
        imageQuality: 90,
      );
      if (x == null) return;
      setState(() {
        _newImageFile = File(x.path);
        _error = null;
      });
    } catch (e) {
      setState(() => _error = '${context.tr('common_error')}: $e');
    }
  }

  Future<void> _save() async {
    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      String? finalImageUrl = _existingImageUrl;
      if (_newImageFile != null) {
        final uploaded =
            await AdminService.uploadBannerImage(_newImageFile!);
        if (uploaded == null) {
          if (!mounted) return;
          setState(() {
            _isSaving = false;
            _error = context.tr('banner_upload_failed');
          });
          return;
        }
        finalImageUrl = uploaded;
      }

      if (finalImageUrl == null) {
        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _error = context.tr('banner_select_image');
        });
        return;
      }

      final order = int.tryParse(_orderController.text.trim()) ?? 1;

      bool ok;
      if (_isEditing) {
        ok = await AdminService.updateBanner(
          bannerId: widget.existing!['id'],
          title: _titleController.text,
          imageUrl: finalImageUrl,
          targetUrl: _linkController.text,
          displayOrder: order,
          height: _height,
          isActive: _isActive,
        );
      } else {
        ok = await AdminService.insertBanner(
          title: _titleController.text,
          imageUrl: finalImageUrl,
          targetUrl: _linkController.text,
          displayOrder: order,
          height: _height,
          isActive: _isActive,
        );
      }

      if (!mounted) return;
      if (ok) {
        Navigator.pop(context, true);
      } else {
        setState(() {
          _isSaving = false;
          _error = context.tr('banner_save_failed');
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _error = '${context.tr('common_error')}: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // استخراج النصوص
    final tTitle = _isEditing
        ? context.tr('banner_edit')
        : context.tr('banner_new');
    final tSave = context.tr('banner_save');
    final tImage = context.tr('banner_image');
    final tNoImage = context.tr('banner_no_image');
    final tGallery = context.tr('banner_from_gallery');
    final tCamera = context.tr('banner_from_camera');
    final tTitleLabel = context.tr('banner_title_label');
    final tTitleHint = context.tr('banner_title_hint');
    final tLinkLabel = context.tr('banner_link_label');
    final tOrderLabel = context.tr('banner_order_label');
    final tHeightLabel = context.tr('banner_height');
    final tActive = context.tr('banner_active');
    final tActiveSub = context.tr('banner_active_sub');
    final tAddBtn = context.tr('banner_add_button');
    final tSaveBtn = context.tr('banner_save_button');
    final tCancel = context.tr('common_cancel');

    return Scaffold(
      appBar: AppBar(
        title: Text(tTitle),
        actions: [
          TextButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save),
            label: Text(tSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_error != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),

          Text(
            tImage,
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: _height.toDouble(),
              width: double.infinity,
              color: theme.colorScheme.surfaceContainerHighest,
              child: _newImageFile != null
                  ? Image.file(_newImageFile!, fit: BoxFit.cover)
                  : (_existingImageUrl != null
                      ? CachedNetworkImage(
                          imageUrl: _existingImageUrl!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                size: 48,
                                color: theme.colorScheme.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(tNoImage),
                            ],
                          ),
                        )),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(tGallery),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isSaving
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(tCamera),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: tTitleLabel,
              hintText: tTitleHint,
              prefixIcon: const Icon(Icons.title),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _linkController,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: tLinkLabel,
              hintText: 'https://example.com',
              prefixIcon: const Icon(Icons.link),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _orderController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: tOrderLabel,
              prefixIcon: const Icon(Icons.format_list_numbered),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              const Icon(Icons.height, size: 20),
              const SizedBox(width: 8),
              Text('$tHeightLabel: $_height'),
            ],
          ),
          Slider(
            value: _height.toDouble(),
            min: 100,
            max: 400,
            divisions: 30,
            label: '$_height px',
            onChanged: _isSaving
                ? null
                : (v) => setState(() => _height = v.round()),
          ),

          const SizedBox(height: 8),

          SwitchListTile(
            title: Text(tActive),
            subtitle: Text(tActiveSub),
            value: _isActive,
            onChanged:
                _isSaving ? null : (v) => setState(() => _isActive = v),
          ),

          const SizedBox(height: 24),

          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSaving ? null : _save,
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(_isEditing ? tSaveBtn : tAddBtn),
            ),
          ),

          const SizedBox(height: 12),

          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: Text(tCancel),
          ),
        ],
      ),
    );
  }
}
