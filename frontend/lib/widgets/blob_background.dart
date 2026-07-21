import 'package:flutter/material.dart';

/// Fondo de un solo azul de marca, plano — sin manchas, degradados de
/// varios tonos ni texturas que puedan leerse como un artefacto visual.
class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: color);
  }
}
