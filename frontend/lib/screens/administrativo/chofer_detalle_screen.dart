import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/perfil.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/responsive_scroll_view.dart';

/// Historial completo (solicitudes + cargas) de un chofer, visto desde el
/// panel administrativo. Llega vía `state.extra` (el [Perfil] del chofer)
/// desde la lista de choferes registrados de [AdministrativoHomeScreen].
///
/// Un chofer ya no tiene un vehículo fijo — puede haber usado distintas
/// unidades en días distintos (ver [Vehiculo]) — por eso aquí se muestra
/// el historial de vehículos usados, no un tope semanal único.
class ChoferDetalleScreen extends ConsumerWidget {
  const ChoferDetalleScreen({super.key, required this.chofer});

  final Perfil chofer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(operacionesRepositoryProvider);
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);
    ref.watch(
      operacionesTickProvider,
    ); // fuerza rebuild tras mutaciones externas

    final solicitudes = repo.solicitudesDeChofer(chofer.id);
    final cargas = repo.cargasDeChofer(chofer.id);

    final idsVehiculosUsados = {
      ...solicitudes.map((s) => s.vehiculoId),
      ...cargas.map((c) => c.vehiculoId),
    };
    final vehiculosUsados = idsVehiculosUsados
        .map(vehiculosRepo.porId)
        .whereType<Vehiculo>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(chofer.nombreCompleto),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: ResponsiveScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Vehículos usados',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (vehiculosUsados.isEmpty)
                EstadoVacio(
                  mensaje: 'Este chofer aún no ha usado ningún vehículo.',
                )
              else
                GroupedSection(
                  children: [
                    for (final v in vehiculosUsados)
                      GroupedRow(
                        titulo: '${v.tipoUnidad} · ${v.identificador}',
                        subtitulo: v.tipoCombustible,
                        icono: Icons.local_shipping_outlined,
                        iconoColor: context.colors.info,
                        trailing: Text(
                          v.topeSemanal <= 0
                              ? 'Sin tope asignado'
                              : '${v.topeSemanal.toStringAsFixed(0)} L/semana',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: v.topeSemanal <= 0
                                    ? context.colors.warning
                                    : context.colors.textSecondary,
                              ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 28),
              Text(
                'Solicitudes',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (solicitudes.isEmpty)
                EstadoVacio(mensaje: 'Este chofer aún no tiene solicitudes.')
              else
                GroupedSection(
                  children: [
                    for (final s in solicitudes)
                      _SolicitudTile(
                        solicitud: s,
                        vehiculo: vehiculosRepo.porId(s.vehiculoId),
                      ),
                  ],
                ),
              const SizedBox(height: 28),
              Text(
                'Cargas registradas',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (cargas.isEmpty)
                EstadoVacio(mensaje: 'Este chofer aún no ha registrado cargas.')
              else
                GroupedSection(
                  children: [
                    for (final c in cargas)
                      GroupedRow(
                        titulo:
                            '${c.litrosCargados.toStringAsFixed(1)} L cargados',
                        subtitulo: () {
                          final vehiculo = vehiculosRepo.porId(c.vehiculoId);
                          final base =
                              'Folio ${c.folioAutorizacion} · ${formatearFechaCorta(c.creadaEn)}';
                          return vehiculo == null
                              ? base
                              : '$base · ${vehiculo.tipoUnidad} ${vehiculo.identificador}';
                        }(),
                        icono: Icons.local_gas_station_outlined,
                        iconoColor: context.colors.success,
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
  final Vehiculo? vehiculo;

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
                Text(
                  '${solicitud.litrosSolicitados.toStringAsFixed(1)} L solicitados',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  vehiculo == null
                      ? formatearFechaCorta(solicitud.creadaEn)
                      : '${formatearFechaCorta(solicitud.creadaEn)} · ${vehiculo!.tipoUnidad} '
                            '${vehiculo!.identificador}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                if (solicitud.folioAutorizacion != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Folio ${solicitud.folioAutorizacion}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
                if (solicitud.comentario != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    solicitud.comentario!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.error),
                  ),
                ],
              ],
            ),
          ),
          EstadoSolicitudBadge(estado: solicitud.estado),
        ],
      ),
    );
  }
}
