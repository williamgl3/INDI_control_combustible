import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'halftone_pattern.dart';

/// Header de marca — degradado azul + textura de puntos ("halftone"),
/// tomado directo del banner corporativo real de INDI. Reutilizado en
/// Login y en los "home" de chofer/administrativo para dar coherencia
/// visual e identidad de marca fuerte entre pantallas.
///
/// El contenido ([child]) se pinta sobre fondo oscuro — usa
/// [BrandHeader.onColor]/[BrandHeader.onColorMuted] para texto/íconos en
/// vez de `colors.textPrimary`/`textSecondary` (esos son para texto sobre
/// superficies claras).
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 40, 24, 32),
  });

  final Widget child;
  final EdgeInsets padding;

  /// Color de texto/ícono principal sobre el header (blanco).
  static const onColor = Colors.white;

  /// Color de texto secundario sobre el header (blanco atenuado).
  static const onColorMuted = Color(0xB3FFFFFF);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.brandHeaderStart, colors.brandHeaderEnd],
        ),
      ),
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(
              child: HalftonePattern(
                color: colors.brandHeaderDot.withValues(alpha: 0.35),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}
