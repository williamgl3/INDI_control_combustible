import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Botón para tomar una foto con la cámara (tablero, ticket, etc.) que
/// muestra una miniatura una vez capturada. `onTomarFoto` delega la
/// captura real al [FotoPicker] inyectado por la pantalla — este widget
/// solo se encarga de la presentación.
class CapturaFotoField extends StatelessWidget {
  const CapturaFotoField({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.rutaFoto,
    required this.onTomarFoto,
    this.cargando = false,
  });

  final String etiqueta;
  final IconData icono;
  final String? rutaFoto;
  final VoidCallback onTomarFoto;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tieneFoto = rutaFoto != null;

    final contenido = Container(
      // Padding y tamaños de miniatura/ícono ligeramente más grandes que
      // un tile de lista normal — este control se usa para tomar una
      // foto en campo, a veces con una sola mano, así que el objetivo
      // táctil completo merece ser más grande que el de una fila común.
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        borderRadius: AppRadii.cardRadius,
        border: tieneFoto
            ? Border.all(color: colors.success.withValues(alpha: 0.4))
            : null,
      ),
      child: Row(
        children: [
          if (tieneFoto)
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: AppRadii.inputRadius,
                  child: Image.file(
                    File(rutaFoto!),
                    width: 52,
                    height: 52,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 52,
                      height: 52,
                      color: colors.success.withValues(alpha: 0.15),
                      child: Icon(icono, color: colors.success, size: 22),
                    ),
                  ),
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: Container(
                    padding: const EdgeInsets.all(1.5),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: colors.success,
                      size: 18,
                    ),
                  ),
                ),
              ],
            )
          else
            CircleAvatar(
              radius: 26,
              backgroundColor: colors.primary.withValues(alpha: 0.12),
              child: Icon(icono, color: colors.primary, size: 24),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tieneFoto ? '$etiqueta · lista' : etiqueta,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tieneFoto ? colors.success : colors.textPrimary,
              ),
            ),
          ),
          if (cargando)
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              tieneFoto ? Icons.refresh : Icons.camera_alt_outlined,
              color: colors.textSecondary,
              size: 24,
            ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: tieneFoto
          ? 'Volver a tomar foto: $etiqueta'
          : 'Tomar foto: $etiqueta',
      child: Material(
        color: tieneFoto
            ? colors.success.withValues(alpha: 0.06)
            : colors.surfaceAlt,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          onTap: cargando ? null : onTomarFoto,
          borderRadius: AppRadii.cardRadius,
          hoverColor: colors.primary.withValues(alpha: 0.08),
          child: tieneFoto
              ? contenido
              : CustomPaint(
                  // Sin foto todavía: borde punteado en vez de sólido —
                  // señal visual de "falta un paso" más clara que un
                  // borde continuo igual al de cualquier otra card.
                  foregroundPainter: _DashedBorderPainter(
                    color: colors.border,
                    radius: AppRadii.card,
                  ),
                  child: contenido,
                ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const dashWidth = 6.0;
  static const gapWidth = 4.0;
  static const strokeWidth = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      var distancia = 0.0;
      while (distancia < metric.length) {
        final siguiente = distancia + dashWidth;
        canvas.drawPath(
          metric.extractPath(distancia, siguiente.clamp(0, metric.length)),
          paint,
        );
        distancia = siguiente + gapWidth;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}
