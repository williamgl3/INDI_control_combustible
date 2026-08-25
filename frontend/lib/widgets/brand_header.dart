import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header de marca en el azul corporativo del tema. Reutilizado en los home y
/// headers internos para dar estructura consistente sin decoración.
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

    return Container(
      width: double.infinity,
      color: colors.primary,
      padding: padding,
      child: child,
    );
  }
}
