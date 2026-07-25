import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header de marca — degradado azul, tomado directo del banner corporativo
/// real de INDI. Reutilizado en Login y en los "home" de chofer/administrativo
/// para dar coherencia visual e identidad de marca fuerte entre pantallas.
///
/// El contenido ([child]) se pinta sobre fondo oscuro — usa
/// [BrandHeader.onColor]/[BrandHeader.onColorMuted] para texto/íconos en
/// vez de `colors.textPrimary`/`textSecondary` (esos son para texto sobre
/// superficies claras).
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 32, 24, 24),
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
    final mid = Color.lerp(colors.brandHeaderStart, colors.brandHeaderEnd, 0.5)!;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.brandHeaderStart, mid, colors.brandHeaderEnd],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}
