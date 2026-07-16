import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Header con gradiente de marca, reutilizado en Login y en los "home"
/// de chofer/administrativo para dar coherencia visual entre pantallas.
///
/// TODO-SPEC: gradiente PLACEHOLDER hasta tener SPEC.md.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.info, colors.primary],
        ),
      ),
      child: child,
    );
  }
}
