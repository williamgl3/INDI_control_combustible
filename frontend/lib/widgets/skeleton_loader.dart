import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Bloque gris con una animación de opacidad pulsante en loop, usado como
/// placeholder de una fila (`GroupedRow`) mientras un dato real está en
/// camino — reemplaza al `CircularProgressIndicator` centrado, que no da
/// ninguna pista de la forma final del contenido.
class SkeletonLoader extends StatefulWidget {
  const SkeletonLoader({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacidad;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _opacidad = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AnimatedBuilder(
      animation: _opacidad,
      builder: (context, child) {
        return Opacity(
          opacity: _opacidad.value,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: colors.surfaceAlt,
              borderRadius: widget.borderRadius ?? AppRadii.inputRadius,
              border: Border.all(color: colors.border, width: 0.5),
            ),
          ),
        );
      },
    );
  }
}

/// Placeholder del tamaño aproximado de una [GroupedRow] (ícono circular +
/// título + subtítulo), para usarse mientras una lista está cargando —
/// da la sensación de que el contenido ya "está ahí", solo pendiente de
/// llenarse, en vez del vacío total que deja un spinner centrado.
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          SkeletonLoader(
            width: 36,
            height: 36,
            borderRadius: BorderRadius.circular(18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SkeletonLoader(width: 160),
                const SizedBox(height: AppSpacing.xs),
                SkeletonLoader(
                  width: 100,
                  height: 11,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Grupo de [SkeletonRow] dentro de un contenedor con la misma forma que
/// [GroupedSection] (rectángulo blanco de esquinas redondeadas), para
/// sustituir un `CircularProgressIndicator` centrado mientras carga una
/// lista completa.
class SkeletonGroupedSection extends StatelessWidget {
  const SkeletonGroupedSection({super.key, this.filas = 4});

  final int filas;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < filas; i++) ...[
            const SkeletonRow(),
            if (i != filas - 1)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: Divider(height: 1, thickness: 0.5, color: colors.border),
              ),
          ],
        ],
      ),
    );
  }
}
