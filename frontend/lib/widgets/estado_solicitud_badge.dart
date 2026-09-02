import 'package:flutter/material.dart';

import '../models/solicitud_autorizacion.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';

/// Pill de estado reutilizado en las listas de solicitudes de chofer y
/// del panel administrativo. Toma el estado ya derivado
/// ([EstadoVisualSolicitud], ver `SolicitudAutorizacion.estadoVisual`) en
/// vez del [EstadoSolicitud] crudo, para que "autorizado completo" y
/// "autorizado con recorte" se vean distinguibles en un solo vistazo —
/// antes ambos casos caían en el mismo badge verde "Autorizado".
class EstadoSolicitudBadge extends StatelessWidget {
  const EstadoSolicitudBadge({super.key, required this.estadoVisual});

  final EstadoVisualSolicitud estadoVisual;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, texto) = switch (estadoVisual) {
      EstadoVisualSolicitud.pendiente => (
        colors.textSecondary,
        'Por autorizar',
      ),
      EstadoVisualSolicitud.autorizada => (colors.success, 'Autorizado'),
      // Mismo tono que "En espera" (ámbar = advertencia en la paleta
      // semántica de la app) — se distinguen por el texto, no por el
      // color: "ajustado" no es un error, es información que el chofer
      // debe notar antes de ir a cargar.
      EstadoVisualSolicitud.ajustada => (colors.textSecondary, 'Ajustado'),
      EstadoVisualSolicitud.rechazada => (colors.error, 'Rechazado'),
    };

    return Semantics(
      label: 'Estado de la solicitud: $texto',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
