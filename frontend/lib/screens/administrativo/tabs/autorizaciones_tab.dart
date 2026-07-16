import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/perfil.dart';
import '../../../models/solicitud_autorizacion.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/barra_presupuesto.dart';
import '../../../widgets/chip_filtro.dart';
import '../../../widgets/estado_solicitud_badge.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/fecha_formato.dart';
import '../../../widgets/stat_tile.dart';
import '../revisar_solicitud_dialog.dart';

/// Pestaña "Autorizaciones": solicitudes de todos los choferes, filtrables
/// por estado, con acción de revisión manual para las pendientes.
class AutorizacionesTab extends ConsumerStatefulWidget {
  const AutorizacionesTab({super.key});

  @override
  ConsumerState<AutorizacionesTab> createState() => _AutorizacionesTabState();
}

class _AutorizacionesTabState extends ConsumerState<AutorizacionesTab> {
  static const _limiteMostradas = 30;

  /// `null` representa el filtro "Todas".
  EstadoSolicitud? _filtro;

  Future<void> _revisar(SolicitudAutorizacion solicitud, Perfil chofer) async {
    final resuelta =
        await RevisarSolicitudDialog.show(context, solicitud: solicitud, chofer: chofer);
    if (resuelta == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final choferes = ref.watch(authRepositoryProvider).listarChoferes();
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final solicitudes = repo.todasLasSolicitudes;
    final choferesPorId = {for (final c in choferes) c.id: c};
    final nombresPorChoferId = {for (final c in choferes) c.id: c.nombreCompleto};

    final pendientes = solicitudes.where((s) => s.estado == EstadoSolicitud.pendiente).length;
    final aprobadas = solicitudes.where((s) => s.estado == EstadoSolicitud.aprobada);
    final litrosAutorizados =
        aprobadas.fold(0.0, (suma, s) => suma + (s.litrosAutorizados ?? s.litrosSolicitados));

    final filtradas =
        _filtro == null ? solicitudes : solicitudes.where((s) => s.estado == _filtro).toList();
    final mostradas = filtradas.take(_limiteMostradas).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Autorizaciones', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Revisa y resuelve las solicitudes de carga de combustible.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icono: Icons.hourglass_top_outlined,
                  valor: '$pendientes',
                  etiqueta: 'Por revisar',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icono: Icons.local_gas_station_outlined,
                  valor: litrosAutorizados.toStringAsFixed(0),
                  etiqueta: 'L autorizados',
                ),
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChipFiltro(
                etiqueta: 'Todas',
                seleccionado: _filtro == null,
                onTap: () => setState(() => _filtro = null),
              ),
              ChipFiltro(
                etiqueta: 'Pendientes',
                seleccionado: _filtro == EstadoSolicitud.pendiente,
                onTap: () => setState(() => _filtro = EstadoSolicitud.pendiente),
              ),
              ChipFiltro(
                etiqueta: 'Aprobadas',
                seleccionado: _filtro == EstadoSolicitud.aprobada,
                onTap: () => setState(() => _filtro = EstadoSolicitud.aprobada),
              ),
              ChipFiltro(
                etiqueta: 'Rechazadas',
                seleccionado: _filtro == EstadoSolicitud.rechazada,
                onTap: () => setState(() => _filtro = EstadoSolicitud.rechazada),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (filtradas.isEmpty)
            EstadoVacio(
              icono: Icons.assignment_outlined,
              mensaje: _filtro == null
                  ? 'Aún no hay solicitudes registradas.'
                  : 'No hay solicitudes con este filtro.',
            )
          else ...[
            ...mostradas.map((s) => _SolicitudTile(
                  solicitud: s,
                  nombreChofer: nombresPorChoferId[s.choferId] ?? s.choferId,
                  onRevisar: choferesPorId[s.choferId] == null
                      ? null
                      : () => _revisar(s, choferesPorId[s.choferId]!),
                )),
            if (filtradas.length > mostradas.length)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Mostrando las $_limiteMostradas más recientes de ${filtradas.length}.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ),
          ],
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

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(
            color: esPendiente ? colors.warning.withValues(alpha: 0.4) : colors.border),
      ),
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
                        Text('${solicitud.litrosSolicitados.toStringAsFixed(1)} L · $nombreChofer',
                            style: Theme.of(context).textTheme.titleSmall),
                        if (solicitud.esUrgente) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.bolt, size: 14, color: colors.error),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(formatearFechaCorta(solicitud.creadaEn),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textMuted)),
                    if (solicitud.litrosAutorizados != null &&
                        solicitud.litrosAutorizados != solicitud.litrosSolicitados) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Autorizado: ${solicitud.litrosAutorizados!.toStringAsFixed(1)} L',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textSecondary),
                      ),
                    ],
                    if (solicitud.comentario != null) ...[
                      const SizedBox(height: 2),
                      Text(solicitud.comentario!,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.textMuted)),
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
              child: OutlinedButton(onPressed: onRevisar, child: const Text('Revisar')),
            ),
          ],
        ],
      ),
    );
  }
}
