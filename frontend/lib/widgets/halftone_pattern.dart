import 'package:flutter/material.dart';

/// Textura de puntos tipo "halftone" (impresión offset/serigrafía) — el
/// mismo tratamiento visual del banner de marca real de INDI (fondo azul
/// con retícula de puntos + fotografía de obra en duotono). Se dibuja con
/// un `CustomPainter` en vez de un asset de imagen para que escale nítido
/// a cualquier tamaño de header sin pesar la app con un PNG grande.
class HalftonePattern extends StatelessWidget {
  const HalftonePattern({
    super.key,
    required this.color,
    this.spacing = 14,
    this.maxRadius = 2.6,
  });

  final Color color;
  final double spacing;
  final double maxRadius;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(
        painter: _HalftonePainter(
          color: color,
          spacing: spacing,
          maxRadius: maxRadius,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _HalftonePainter extends CustomPainter {
  _HalftonePainter({
    required this.color,
    required this.spacing,
    required this.maxRadius,
  });

  final Color color;
  final double spacing;
  final double maxRadius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final columnas = (size.width / spacing).ceil() + 1;
    final filas = (size.height / spacing).ceil() + 1;

    for (var fila = 0; fila < filas; fila++) {
      // Cada fila se desfasa medio espacio, como una trama de impresión
      // real (patrón hexagonal) en vez de una cuadrícula perfecta.
      final desfaseX = (fila.isOdd) ? spacing / 2 : 0.0;
      for (var col = 0; col < columnas; col++) {
        final cx = col * spacing + desfaseX;
        final cy = fila * spacing;
        // El radio decrece hacia la esquina inferior derecha — imita el
        // degradado de densidad de puntos del banner original (más denso
        // arriba/izquierda, se disuelve hacia la fotografía).
        final progreso = (cx / size.width + cy / size.height) / 2;
        final radio = (maxRadius * (1 - progreso * 0.7)).clamp(0.4, maxRadius);
        canvas.drawCircle(Offset(cx, cy), radio, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _HalftonePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.spacing != spacing ||
        oldDelegate.maxRadius != maxRadius;
  }
}
