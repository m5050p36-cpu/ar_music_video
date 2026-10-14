import 'package:flutter/material.dart';

/// منتقي لون احترافي — Palette جاهز + HSV Sliders + Hex Input
class ColorPickerSheet extends StatefulWidget {
  final Color initialColor;
  final String title;

  const ColorPickerSheet({
    super.key,
    required this.initialColor,
    required this.title,
  });

  /// يُظهر الـ sheet ويعيد اللون المختار أو null إن أُلغى
  static Future<Color?> show(
    BuildContext context, {
    required Color initialColor,
    required String title,
  }) {
    return showModalBottomSheet<Color>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ColorPickerSheet(
        initialColor: initialColor,
        title: title,
      ),
    );
  }

  @override
  State<ColorPickerSheet> createState() => _ColorPickerSheetState();
}

class _ColorPickerSheetState extends State<ColorPickerSheet> {
  late HSVColor _hsv;
  late TextEditingController _hexController;

  // لوحة ألوان مُعدّة مسبقًا
  static const List<Color> _palette = [
    // Row 1 — Basic
    Color(0xFF000000), Color(0xFF424242), Color(0xFF9E9E9E),
    Color(0xFFE0E0E0), Color(0xFFFFFFFF),
    // Row 2 — Reds
    Color(0xFFB71C1C), Color(0xFFD32F2F), Color(0xFFE53935),
    Color(0xFFFF5252), Color(0xFFFF8A80),
    // Row 3 — Pinks
    Color(0xFF880E4F), Color(0xFFC2185B), Color(0xFFE91E63),
    Color(0xFFFF4081), Color(0xFFFF80AB),
    // Row 4 — Purples
    Color(0xFF4A148C), Color(0xFF6A1B9A), Color(0xFF9C27B0),
    Color(0xFFAB47BC), Color(0xFFCE93D8),
    // Row 5 — Blues
    Color(0xFF0D47A1), Color(0xFF1976D2), Color(0xFF2196F3),
    Color(0xFF42A5F5), Color(0xFF90CAF9),
    // Row 6 — Cyans
    Color(0xFF006064), Color(0xFF0097A7), Color(0xFF00BCD4),
    Color(0xFF26C6DA), Color(0xFF80DEEA),
    // Row 7 — Greens
    Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF4CAF50),
    Color(0xFF66BB6A), Color(0xFFA5D6A7),
    Color(0xFF1DB954), Color(0xFF1ED760), Color(0xFF00E676),
    Color(0xFF43A047), Color(0xFF004D40),
    // Row 8 — Yellows/Oranges
    Color(0xFFF57F17), Color(0xFFFBC02D), Color(0xFFFFEB3B),
    Color(0xFFFFC107), Color(0xFFFF9800),
    Color(0xFFE65100), Color(0xFFF57C00), Color(0xFFFF7043),
    Color(0xFFFF5722), Color(0xFFBF360C),
  ];

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initialColor);
    _hexController = TextEditingController(
      text: _colorToHex(widget.initialColor),
    );
  }

  @override
  void dispose() {
    _hexController.dispose();
    super.dispose();
  }

  String _colorToHex(Color c) {
    final v = c.toARGB32();
    return '#${v.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
  }

  Color? _hexToColor(String hex) {
    try {
      var h = hex.trim().replaceAll('#', '');
      if (h.length == 6) h = 'FF$h';
      if (h.length != 8) return null;
      return Color(int.parse(h, radix: 16));
    } catch (_) {
      return null;
    }
  }

  void _updateFromColor(Color c, {bool syncHex = true}) {
    setState(() {
      _hsv = HSVColor.fromColor(c);
      if (syncHex) _hexController.text = _colorToHex(c);
    });
  }

  void _updateFromHsv(HSVColor h) {
    setState(() {
      _hsv = h;
      _hexController.text = _colorToHex(h.toColor());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentColor = _hsv.toColor();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══ المقبض العلوي ═══
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // ═══ العنوان ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(Icons.colorize, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ═══ المحتوى القابل للتمرير ═══
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══ لوحة الألوان ═══
                    Text(
                      'لوحة الألوان',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildPaletteGrid(theme),
                    const SizedBox(height: 20),

                    // ═══ Hue Slider ═══
                    _sliderLabel('درجة اللون', theme),
                    _hueSlider(theme),
                    const SizedBox(height: 12),

                    // ═══ Saturation ═══
                    _sliderLabel('التشبع', theme),
                    _satSlider(theme),
                    const SizedBox(height: 12),

                    // ═══ Brightness ═══
                    _sliderLabel('السطوع', theme),
                    _valSlider(theme),
                    const SizedBox(height: 20),

                    // ═══ Hex Input ═══
                    Text(
                      'كود اللون (Hex)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _hexController,
                      decoration: InputDecoration(
                        hintText: '#1DB954',
                        prefixIcon: const Icon(Icons.tag),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          onPressed: () {
                            final c = _hexToColor(_hexController.text);
                            if (c != null) _updateFromColor(c);
                          },
                        ),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      onSubmitted: (v) {
                        final c = _hexToColor(v);
                        if (c != null) _updateFromColor(c);
                      },
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),

            // ═══ الأزرار السفلية ═══
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, currentColor),
                      icon: const Icon(Icons.check),
                      label: const Text('اختيار هذا اللون'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderLabel(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildPaletteGrid(ThemeData theme) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 10,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
      ),
      itemCount: _palette.length,
      itemBuilder: (context, i) {
        final c = _palette[i];
        final selected = c.toARGB32() == _hsv.toColor().toARGB32();
        return GestureDetector(
          onTap: () => _updateFromColor(c),
          child: Container(
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.white.withValues(alpha: 0.3),
                width: selected ? 3 : 1,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: c.withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: selected
                ? Icon(
                    Icons.check,
                    size: 16,
                    color: c.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _hueSlider(ThemeData theme) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 14,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
      child: Slider(
        value: _hsv.hue,
        min: 0,
        max: 360,
        onChanged: (v) => _updateFromHsv(_hsv.withHue(v)),
        activeColor: _hsv.toColor(),
        inactiveColor: _hsv.toColor().withValues(alpha: 0.3),
      ),
    );
  }

  Widget _satSlider(ThemeData theme) {
    final full = HSVColor.fromAHSV(1, _hsv.hue, 1, _hsv.value).toColor();
    return Stack(
      children: [
        Container(
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: LinearGradient(
              colors: [
                Colors.white,
                full,
              ],
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 14,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: _hsv.toColor(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: _hsv.saturation,
            onChanged: (v) => _updateFromHsv(_hsv.withSaturation(v)),
          ),
        ),
      ],
    );
  }

  Widget _valSlider(ThemeData theme) {
    final full = HSVColor.fromAHSV(1, _hsv.hue, _hsv.saturation, 1).toColor();
    return Stack(
      children: [
        Container(
          height: 14,
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(7),
            gradient: LinearGradient(
              colors: [Colors.black, full],
            ),
          ),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 14,
            activeTrackColor: Colors.transparent,
            inactiveTrackColor: Colors.transparent,
            thumbColor: _hsv.toColor(),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: _hsv.value,
            onChanged: (v) => _updateFromHsv(_hsv.withValue(v)),
          ),
        ),
      ],
    );
  }
}
