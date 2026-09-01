import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/solicitud_autorizacion.dart';
import '../../router/route_paths.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_text_styles.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/chofer_operation_scaffold.dart';

/// Muestra el resultado de una [SolicitudAutorizacion] recién creada.
/// Llega vía `state.extra` desde /chofer/solicitar. Puede estar ya
/// resuelta (aprobada/rechazada automáticamente) o [EstadoSolicitud.pendiente]
/// de revisión manual de un administrativo.
class RespuestaSolicitudScreen extends StatelessWidget {
  const RespuestaSolicitudScreen({super.key, required this.solicitud});

  final SolicitudAutorizacion solicitud;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, icono, titulo) = switch (solicitud.estado) {
      EstadoSolicitud.aprobada => (
        colors.success,
        Icons.check_circle,
        'Solicitud aprobada',
      ),
      EstadoSolicitud.rechazada => (
        colors.error,
        Icons.cancel,
        'Solicitud rechazada',
      ),
      EstadoSolicitud.pendiente => (
        colors.textSecondary,
        Icons.hourglass_top,
        'En revisión',
      ),
    };

    return ChoferOperationScaffold(
      titulo: 'Resultado de solicitud',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.slow,
            curve: AppMotion.celebratory,
            builder: (context, value, child) =>
                Transform.scale(scale: value, child: child),
            child: CircleAvatar(
              radius: 40,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icono, color: color, size: 44),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            titulo,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '${solicitud.litrosSolicitados.toStringAsFixed(1)} L solicitados',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            'Para: ${formatearFecha(solicitud.fechaProgramada)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          if (solicitud.estado == EstadoSolicitud.aprobada)
            AppCard(
              floating: true,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (solicitud.litrosAutorizados != null &&
                      solicitud.litrosAutorizados !=
                          solicitud.litrosSolicitados) ...[
                    Text(
                      'Te autorizaron ${solicitud.litrosAutorizados!.toStringAsFixed(1)} L',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(
                    'Folio de autorización',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    solicitud.folioAutorizacion!,
                    style: AppTextStyles.monoData(
                      colors.textPrimary,
                    ).copyWith(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            )
          else if (solicitud.comentario != null)
            Text(
              solicitud.comentario!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: solicitud.estado == EstadoSolicitud.rechazada
                    ? colors.error
                    : colors.textSecondary,
              ),
            ),
          const SizedBox(height: 28),
          if (solicitud.estado == EstadoSolicitud.aprobada) ...[
            ElevatedButton(
              onPressed: () => context.go(
                RoutePaths.choferComprobar,
                extra: solicitud.folioAutorizacion,
              ),
              child: const Text('Comprobar carga ahora'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(RoutePaths.chofer),
              child: const Text('Hacerlo más tarde'),
            ),
          ] else
            ElevatedButton(
              onPressed: () => context.go(RoutePaths.chofer),
              child: const Text('Entendido'),
            ),
        ],
      ),
    );
  }
}
