import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Envuelve un widget tocable con un ligero encogimiento al presionar
/// (0.97x) — el mismo micro-feedback táctil de los botones/celdas de iOS,
/// para que las tarjetas se sientan más "vivas" al tocarlas, no solo con
/// el ripple de Material.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _presionado = false;

  void _setPresionado(bool v) {
    if (widget.onTap == null) return;
    setState(() => _presionado = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => _setPresionado(true),
      onTapCancel: () => _setPresionado(false),
      onTapUp: (_) => _setPresionado(false),
      child: AnimatedScale(
        scale: _presionado && !MediaQuery.disableAnimationsOf(context)
            ? 0.98
            : 1.0,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppMotion.fast,
        curve: AppMotion.curve,
        child: widget.child,
      ),
    );
  }
}
