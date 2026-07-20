import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header de marca — navy oscuro plano, distinto del azul de
/// botones/acentos. Reutilizado en Login y en los "home" de
/// chofer/administrativo para dar coherencia visual entre pantallas.
class BrandHeader extends StatelessWidget {
  const BrandHeader({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(24, 40, 24, 32),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      width: double.infinity,
      padding: padding,
      color: colors.headerBackground,
      child: child,
    );
  }
}
