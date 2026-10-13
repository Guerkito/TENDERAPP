import 'package:flutter/material.dart';

/// Escala sutil al presionar: feedback táctil para tarjetas, ítems y botones.
/// Respeta "reducir movimiento" del sistema.
class PressScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  const PressScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.96,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && !reduceMotion ? widget.scale : 1.0,
        duration: Duration(milliseconds: reduceMotion ? 0 : 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Número que "cuenta" hasta su valor cuando aparece o cambia.
class AnimatedCount extends StatelessWidget {
  final num value;
  final String Function(num) format;
  final Duration duration;
  final TextStyle? style;

  const AnimatedCount({
    super.key,
    required this.value,
    required this.format,
    this.duration = const Duration(milliseconds: 700),
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) {
      return Text(format(value), style: style);
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text(format(v), style: style),
    );
  }
}
