import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../theme/app_section_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/ios_segmented_control.dart';
import '../../widgets/responsive_scroll_view.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/stat_tile_row.dart';

enum _FiltroEstado { todas, pendientes, aprobadas, rechazadas }

/// Historial completo de las solicitudes del chofer, con filtro por
/// estado — antes solo se veían las últimas en "Actividad reciente" del
/// home, sin poder revisar el motivo de un rechazo o de una autorización
/// parcial más allá de esa lista corta.
class MisSolicitudesScreen extends ConsumerStatefulWidget {
  const MisSolicitudesScreen({super.key});

  @override
  ConsumerState<MisSolicitudesScreen> createState() =>
      _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends ConsumerState<MisSolicitudesScreen> {
  _FiltroEstado _filtroVista = _FiltroEstado.todas;

  EstadoSolicitud? get _filtro => switch (_filtroVista) {
    _FiltroEstado.todas => null,
    _FiltroEstado.pendientes => EstadoSolicitud.pendiente,
    _FiltroEstado.aprobadas => EstadoSolicitud.aprobada,
    _FiltroEstado.rechazadas => EstadoSolicitud.rechazada,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final perfil = ref.watch(sessionProvider);
    if (perfil == null) return const SizedBox.shrink();

    final repo = ref.watch(operacionesRepositoryProvider);
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final solicitudes = repo.solicitudesDeChofer(perfil.id);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis solicitudes'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ResponsiveScrollView(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
              const SizedBox(height: 20),
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
              if (filtradas.isEmpty)
                EstadoVacio(
                  icono: Icons.assignment_outlined,
                  mensaje: _filtro == null
                      ? 'Aún no has hecho ninguna solicitud.'
                      : 'No hay solicitudes con este filtro.',
                )
              else
                GroupedSection(
                  children: [
                    for (final s in filtradas)
                      _SolicitudTile(
                        solicitud: s,
                        vehiculo: vehiculosRepo.porId(s.vehiculoId)?.identificador,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({required this.solicitud, required this.vehiculo});

  final SolicitudAutorizacion solicitud;
  final String? vehiculo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${solicitud.litrosSolicitados.toStringAsFixed(1)} L'
                        '${vehiculo != null ? ' · $vehiculo' : ''}',
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
                const SizedBox(height: 2),
                Text(
                  solicitud.actividad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                if (solicitud.litrosAutorizados != null &&
                    solicitud.litrosAutorizados !=
                        solicitud.litrosSolicitados) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Te autorizaron: ${solicitud.litrosAutorizados!.toStringAsFixed(1)} L',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
                if (solicitud.comentario != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    solicitud.comentario!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          EstadoSolicitudBadge(estado: solicitud.estado),
        ],
      ),
    );
  }
}
