import 'package:flutter/material.dart';

import '../screens/administrativo/tabs/mantenimiento_calculo.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';

/// Pill de estado reutilizado en la pestaña de Mantenimiento del panel
/// administrativo — mismo tratamiento visual que [EstadoSolicitudBadge].
class EstadoMantenimientoBadge extends StatelessWidget {
  const EstadoMantenimientoBadge({super.key, required this.estado});

  final EstadoMantenimiento estado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, texto) = switch (estado) {
      EstadoMantenimiento.noConfigurado => (colors.textMuted, 'No configurado'),
      EstadoMantenimiento.alDia => (colors.success, 'Al día'),
      EstadoMantenimiento.proximo => (colors.warning, 'Próximo'),
      EstadoMantenimiento.vencido => (colors.error, 'Vencido'),
      EstadoMantenimiento.sinDatos => (colors.textMuted, 'Sin datos'),
    };

    return Semantics(
      label: 'Estado de mantenimiento: $texto',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: AppRadii.badgeRadius,
        ),
        child: Text(
          texto.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}
