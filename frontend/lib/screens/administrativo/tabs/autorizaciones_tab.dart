import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/solicitud_autorizacion.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/barra_presupuesto.dart';
import '../../../widgets/estado_solicitud_badge.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/fecha_formato.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/ios_segmented_control.dart';
import '../../../widgets/responsive_scroll_view.dart';
import '../../../widgets/stat_tile.dart';
import '../../../widgets/stat_tile_row.dart';
import '../revisar_solicitud_dialog.dart';

enum _FiltroEstado { todas, pendientes, aprobadas, rechazadas }

/// Pestaña "Autorizaciones": solicitudes de todos los choferes, filtrables
/// por estado, con acción de revisión manual para las pendientes.
class AutorizacionesTab extends ConsumerStatefulWidget {
  const AutorizacionesTab({super.key});

  @override
  ConsumerState<AutorizacionesTab> createState() => _AutorizacionesTabState();
}

class _AutorizacionesTabState extends ConsumerState<AutorizacionesTab> {
  static const _limiteMostradas = 30;

  _FiltroEstado _filtroVista = _FiltroEstado.todas;

  /// `null` representa el filtro "Todas".
  EstadoSolicitud? get _filtro => switch (_filtroVista) {
    _FiltroEstado.todas => null,
    _FiltroEstado.pendientes => EstadoSolicitud.pendiente,
    _FiltroEstado.aprobadas => EstadoSolicitud.aprobada,
    _FiltroEstado.rechazadas => EstadoSolicitud.rechazada,
  };

  Future<void> _revisar(
    SolicitudAutorizacion solicitud,
    String nombreChofer,
  ) async {
    final resuelta = await RevisarSolicitudDialog.show(
      context,
      solicitud: solicitud,
      nombreChofer: nombreChofer,
    );
    if (resuelta == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final choferes = ref.watch(authRepositoryProvider).listarChoferes();
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final solicitudes = repo.todasLasSolicitudes;
    final nombresPorChoferId = {
      for (final c in choferes) c.id: c.nombreCompleto,
    };

    final pendientes = solicitudes
        .where((s) => s.estado == EstadoSolicitud.pendiente)
        .length;
    final aprobadas = solicitudes.where(
      (s) => s.estado == EstadoSolicitud.aprobada,
    );
    final litrosAutorizados = aprobadas.fold(
      0.0,
      (suma, s) => suma + (s.litrosAutorizados ?? s.litrosSolicitados),
    );

    final filtradas = _filtro == null
        ? solicitudes
        : solicitudes.where((s) => s.estado == _filtro).toList();
    final mostradas = filtradas.take(_limiteMostradas).toList();

    return ResponsiveScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Autorizaciones',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Revisa y resuelve las solicitudes de carga de combustible.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          StatTileRow(
            tiles: [
              StatTile(
                icono: Icons.hourglass_top_outlined,
                valor: '$pendientes',
                etiqueta: 'Por revisar',
                color: colors.warning,
                onTap: () =>
                    setState(() => _filtroVista = _FiltroEstado.pendientes),
              ),
              StatTile(
                icono: Icons.local_gas_station_outlined,
                valor: litrosAutorizados.toStringAsFixed(0),
                etiqueta: 'L autorizados',
                color: AppSectionColors.autorizaciones,
                onTap: () =>
                    setState(() => _filtroVista = _FiltroEstado.aprobadas),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BarraPresupuesto(
            restante: repo.presupuestoRestante,
            total: repo.presupuestoSemanalTotal,
            etiquetaSemana: repo.etiquetaSemanaActual,
          ),
          const SizedBox(height: 24),
          IosSegmentedControl<_FiltroEstado>(
            valor: _filtroVista,
            opciones: const {
              _FiltroEstado.todas: 'Todas',
              _FiltroEstado.pendientes: 'Pendientes',
              _FiltroEstado.aprobadas: 'Aprobadas',
              _FiltroEstado.rechazadas: 'Rechazadas',
            },
            onChanged: (f) => setState(() => _filtroVista = f),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Column(
              key: ValueKey(_filtro),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (filtradas.isEmpty)
                  EstadoVacio(
                    icono: Icons.assignment_outlined,
                    mensaje: _filtro == null
                        ? 'Aún no hay solicitudes registradas.'
                        : 'No hay solicitudes con este filtro.',
                  )
                else ...[
                  GroupedSection(
                    children: [
                      for (final s in mostradas)
                        _SolicitudTile(
                          solicitud: s,
                          nombreChofer:
                              nombresPorChoferId[s.choferId] ?? s.choferId,
                          onRevisar: () => _revisar(
                            s,
                            nombresPorChoferId[s.choferId] ?? s.choferId,
                          ),
                        ),
                    ],
                  ),
                  if (filtradas.length > mostradas.length)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Mostrando las $_limiteMostradas más recientes de ${filtradas.length}.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({
    required this.solicitud,
    required this.nombreChofer,
    required this.onRevisar,
  });

  final SolicitudAutorizacion solicitud;
  final String nombreChofer;
  final VoidCallback? onRevisar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final esPendiente = solicitud.estado == EstadoSolicitud.pendiente;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${solicitud.litrosSolicitados.toStringAsFixed(1)} L · $nombreChofer',
                            style: Theme.of(context).textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (solicitud.esUrgente) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.bolt, size: 14, color: colors.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatearFechaCorta(solicitud.creadaEn),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                    if (solicitud.litrosAutorizados != null &&
                        solicitud.litrosAutorizados !=
                            solicitud.litrosSolicitados) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Autorizado: ${solicitud.litrosAutorizados!.toStringAsFixed(1)} L',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                    if (solicitud.comentario != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        solicitud.comentario!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              EstadoSolicitudBadge(estado: solicitud.estado),
            ],
          ),
          if (esPendiente && onRevisar != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton(
                onPressed: onRevisar,
                child: const Text('Revisar'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
