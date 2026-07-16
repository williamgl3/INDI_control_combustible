import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/carga.dart';
import '../../models/perfil.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/fecha_formato.dart';

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
    ref.watch(operacionesTickProvider); // fuerza rebuild tras mutaciones externas

    final solicitudes = repo.solicitudesDeChofer(chofer.id);
    final cargas = repo.cargasDeChofer(chofer.id);

    final idsVehiculosUsados = {
      ...solicitudes.map((s) => s.vehiculoId),
      ...cargas.map((c) => c.vehiculoId),
    };
    final vehiculosUsados =
        idsVehiculosUsados.map(vehiculosRepo.porId).whereType<Vehiculo>().toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(chofer.nombreCompleto),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Vehículos usados', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (vehiculosUsados.isEmpty)
                _EstadoVacio(mensaje: 'Este chofer aún no ha usado ningún vehículo.')
              else
                ...vehiculosUsados.map((v) => _VehiculoUsadoTile(vehiculo: v)),
              const SizedBox(height: 28),
              Text('Solicitudes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (solicitudes.isEmpty)
                _EstadoVacio(mensaje: 'Este chofer aún no tiene solicitudes.')
              else
                ...solicitudes.map((s) => _SolicitudTile(
                      solicitud: s,
                      vehiculo: vehiculosRepo.porId(s.vehiculoId),
                    )),
              const SizedBox(height: 28),
              Text('Cargas registradas', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (cargas.isEmpty)
                _EstadoVacio(mensaje: 'Este chofer aún no ha registrado cargas.')
              else
                ...cargas.map((c) => _CargaTile(
                      carga: c,
                      vehiculo: vehiculosRepo.porId(c.vehiculoId),
                    )),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehiculoUsadoTile extends StatelessWidget {
  const _VehiculoUsadoTile({required this.vehiculo});

  final Vehiculo vehiculo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sinTope = vehiculo.topeSemanal <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.info.withValues(alpha: 0.12),
            child: Icon(Icons.local_shipping_outlined, color: colors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${vehiculo.tipoUnidad} · ${vehiculo.identificador}',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  vehiculo.tipoCombustible,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          Text(
            sinTope
                ? 'Sin tope asignado'
                : '${vehiculo.topeSemanal.toStringAsFixed(0)} L/semana',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: sinTope ? colors.warning : colors.textSecondary),
          ),
        ],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${solicitud.litrosSolicitados.toStringAsFixed(1)} L solicitados',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  vehiculo == null
                      ? formatearFechaCorta(solicitud.creadaEn)
                      : '${formatearFechaCorta(solicitud.creadaEn)} · ${vehiculo!.tipoUnidad} '
                          '${vehiculo!.identificador}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.textMuted),
                ),
                if (solicitud.folioAutorizacion != null) ...[
                  const SizedBox(height: 2),
                  Text('Folio ${solicitud.folioAutorizacion}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.textSecondary)),
                ],
                if (solicitud.comentario != null) ...[
                  const SizedBox(height: 4),
                  Text(solicitud.comentario!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.error)),
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

class _CargaTile extends StatelessWidget {
  const _CargaTile({required this.carga, required this.vehiculo});

  final Carga carga;
  final Vehiculo? vehiculo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: colors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colors.success.withValues(alpha: 0.12),
            child: Icon(Icons.local_gas_station, color: colors.success, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${carga.litrosCargados.toStringAsFixed(1)} L cargados',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  vehiculo == null
                      ? 'Folio ${carga.folioAutorizacion} · ${formatearFechaCorta(carga.creadaEn)}'
                      : 'Folio ${carga.folioAutorizacion} · ${formatearFechaCorta(carga.creadaEn)}'
                          ' · ${vehiculo!.tipoUnidad} ${vehiculo!.identificador}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.mensaje});

  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(mensaje,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textMuted)),
    );
  }
}
