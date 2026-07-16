import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../models/carga.dart';
import '../../models/perfil.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/tarjeta_tope_semanal.dart';
import 'editar_chofer_dialog.dart';

/// Historial completo (solicitudes + cargas) de un chofer, visto desde el
/// panel administrativo. Llega vía `state.extra` (el [Perfil] del chofer)
/// desde la lista de choferes registrados de [AdministrativoHomeScreen].
class ChoferDetalleScreen extends ConsumerStatefulWidget {
  const ChoferDetalleScreen({super.key, required this.chofer});

  final Perfil chofer;

  @override
  ConsumerState<ChoferDetalleScreen> createState() => _ChoferDetalleScreenState();
}

class _ChoferDetalleScreenState extends ConsumerState<ChoferDetalleScreen> {
  late Perfil _chofer = widget.chofer;

  Future<void> _editarTope() async {
    final guardado = await EditarChoferDialog.show(context, _chofer);
    if (guardado == true && mounted) {
      final actualizado = ref.read(authRepositoryProvider).listarChoferes().firstWhere(
            (c) => c.usuario == _chofer.usuario,
            orElse: () => _chofer,
          );
      setState(() => _chofer = actualizado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculo = _chofer.vehiculo!;
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider); // fuerza rebuild tras mutaciones externas

    final solicitudes = repo.solicitudesDeChofer(_chofer.id);
    final cargas = repo.cargasDeChofer(_chofer.id);
    final usado = repo.litrosAutorizadosAcumulados(_chofer.id);
    final tope = vehiculo.topeSemanal;
    final disponible = (tope - usado).clamp(0, tope == 0 ? 0 : double.infinity).toDouble();
    final progreso = tope > 0 ? (usado / tope).clamp(0, 1).toDouble() : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(_chofer.nombreCompleto),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.surfaceAlt,
                  borderRadius: AppRadii.cardRadius,
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_outlined, color: colors.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${vehiculo.tipoUnidad} · ${vehiculo.placaONumeroEconomico} · '
                        '${vehiculo.tipoCombustible}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TarjetaTopeSemanal(
                tope: tope,
                usado: usado,
                disponible: disponible,
                progreso: progreso,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _editarTope,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar tope semanal'),
              ),
              const SizedBox(height: 28),
              Text('Solicitudes', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (solicitudes.isEmpty)
                _EstadoVacio(mensaje: 'Este chofer aún no tiene solicitudes.')
              else
                ...solicitudes.map((s) => _SolicitudTile(solicitud: s)),
              const SizedBox(height: 28),
              Text('Cargas registradas', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (cargas.isEmpty)
                _EstadoVacio(mensaje: 'Este chofer aún no ha registrado cargas.')
              else
                ...cargas.map((c) => _CargaTile(carga: c)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({required this.solicitud});

  final SolicitudAutorizacion solicitud;

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
                Text(formatearFechaCorta(solicitud.creadaEn),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.textMuted)),
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
  const _CargaTile({required this.carga});

  final Carga carga;

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
                Text('Folio ${carga.folioAutorizacion} · ${formatearFechaCorta(carga.creadaEn)}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.textMuted)),
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
