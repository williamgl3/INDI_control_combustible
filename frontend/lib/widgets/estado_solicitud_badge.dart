import 'package:flutter/material.dart';

import '../models/solicitud_autorizacion.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';

/// Pill de estado reutilizado en las listas de solicitudes de chofer y
/// del panel administrativo.
class EstadoSolicitudBadge extends StatelessWidget {
  const EstadoSolicitudBadge({super.key, required this.estado});

  final EstadoSolicitud estado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, texto) = switch (estado) {
      EstadoSolicitud.pendiente => (colors.warning, 'En espera'),
      EstadoSolicitud.aprobada => (colors.success, 'Autorizado'),
      EstadoSolicitud.rechazada => (colors.error, 'Rechazado'),
    };

    return Container(
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
    );
  }
}
