import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/notificaciones_provider.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import 'estado_vacio.dart';
import 'header_glass_button.dart';

IconData _iconoDe(String nombre) => switch (nombre) {
  'check_circle_outline' => Icons.check_circle_outline,
  'cancel_outlined' => Icons.cancel_outlined,
  'schedule_outlined' => Icons.schedule_outlined,
  'error_outline' => Icons.error_outline,
  'assignment_outlined' => Icons.assignment_outlined,
  'report_problem_outlined' => Icons.report_problem_outlined,
  _ => Icons.notifications_outlined,
};

/// IDs de notificaciones "en vivo" que no se marcan como vistas al cerrar
/// la hoja — reflejan un estado actual (recordatorio de cerrar día, avisos
/// de presupuesto), no un evento puntual que ya se "consume" al verlo.
const _idsNoDescartables = {
  'recordatorio-cerrar-dia',
  'presupuesto-70',
  'presupuesto-90',
};

/// Campanita con contador de notificaciones sin ver — antes de esto, la
/// única forma de enterarse de que una solicitud se resolvió era la
/// notificación push del sistema operativo (que se pierde si se
/// descarta) o revisar "Actividad reciente" manualmente. Reutilizada tanto
/// para el chofer (`notificacionesChoferProvider`) como para el
/// administrativo (`notificacionesAdminProvider`) — cada rol pasa su
/// propio [provider].
class NotificacionesBell extends ConsumerWidget {
  const NotificacionesBell({super.key, required this.provider, this.color});

  final FutureProvider<List<NotificacionItem>> provider;

  /// Color del ícono — por defecto `colors.textSecondary` (para usarse
  /// sobre superficies claras); pásalo explícito (ej. blanco) cuando se
  /// use sobre un [BrandHeader].
  final Color? color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final notificaciones = ref.watch(provider).valueOrNull ?? const [];

    final tooltip = notificaciones.isEmpty
        ? 'Notificaciones, sin novedades'
        : 'Notificaciones, ${notificaciones.length} sin ver';

    return HeaderGlassButton(
      tooltip: tooltip,
      onPressed: () => mostrar(context, ref, provider),
      icon: Badge(
        isLabelVisible: notificaciones.isNotEmpty,
        label: Text('${notificaciones.length}'),
        child: Icon(
          Icons.notifications_outlined,
          color: color ?? colors.textSecondary,
        ),
      ),
    );
  }

  /// Abre la misma hoja de notificaciones que el ícono de la campanita —
  /// expuesto aparte para poder engancharlo a otro disparador (ej. la
  /// pestaña "Notificaciones" de la barra inferior del chofer) sin
  /// duplicar la lógica de "marcar como vistas al cerrar".
  static Future<void> mostrar(
    BuildContext context,
    WidgetRef ref,
    FutureProvider<List<NotificacionItem>> provider,
  ) async {
    final notificaciones = ref.read(provider).valueOrNull ?? const [];

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _HojaNotificaciones(notificaciones: notificaciones),
    );

    // Al cerrar la hoja, se marcan como vistas — así no vuelven a
    // aparecer en la campanita la próxima vez, aunque sigan en
    // "Actividad reciente"/"Mis solicitudes".
    final ids = notificaciones
        .map((n) => n.id)
        .where((id) => !_idsNoDescartables.contains(id))
        .toList();
    if (ids.isNotEmpty) {
      await ref.read(notificacionesVistasStorageProvider).marcarVistas(ids);
      ref.invalidate(provider);
    }
  }
}

class _HojaNotificaciones extends StatelessWidget {
  const _HojaNotificaciones({required this.notificaciones});

  final List<NotificacionItem> notificaciones;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Notificaciones', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            if (notificaciones.isEmpty)
              const EstadoVacio(
                icono: Icons.notifications_none_outlined,
                mensaje: 'No tienes notificaciones nuevas.',
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: notificaciones.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final n = notificaciones[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: colors.primary.withValues(alpha: 0.1),
                              borderRadius: AppRadii.badgeRadius,
                            ),
                            child: Icon(
                              _iconoDe(n.icono),
                              size: 18,
                              color: colors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.titulo,
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Text(
                                  n.subtitulo,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: colors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
