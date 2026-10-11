import 'package:flutter/material.dart';

/// 3 نقاط/أعمدة تتحرك عند تشغيل مقطع
class PlayingIndicator extends StatefulWidget {
  final Color color;
  final double dotSize;
  final double height;

  const PlayingIndicator({
    super.key,
    required this.color,
    this.dotSize = 4,
    this.height = 16,
  });

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(3, (i) {
              // إزاحة زمنية لكل عمود
              final phase = (_ctrl.value + i * 0.25) % 1.0;
              // 0..1..0 (قمة في المنتصف)
              final wave = 1 - (phase * 2 - 1).abs();
              final h = widget.height * (0.35 + 0.65 * wave);

              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: widget.dotSize * 0.35,
                ),
                width: widget.dotSize,
                height: h,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius:
                      BorderRadius.circular(widget.dotSize / 2),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
