import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../router/route_paths.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/gradient_header.dart';
import '../../widgets/tarjeta_tope_semanal.dart';

class ChoferHomeScreen extends ConsumerStatefulWidget {
  const ChoferHomeScreen({super.key});

  @override
  ConsumerState<ChoferHomeScreen> createState() => _ChoferHomeScreenState();
}

class _ChoferHomeScreenState extends ConsumerState<ChoferHomeScreen> {
  // Se refresca al volver de /chofer/solicitar o /chofer/comprobar
  // (el repositorio mock es en memoria, no notifica cambios por sí solo).
  int _refreshKey = 0;

  Future<void> _refrescarAlVolver(Future<void> Function() accion) async {
    await accion();
    if (mounted) setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final perfil = ref.watch(sessionProvider);
    // El guard de rutas redirige a /login en cuanto la sesión se cierra,
    // pero este widget puede reconstruirse un frame antes de que el
    // router lo retire — evita el crash mientras tanto.
    if (perfil == null) return const SizedBox.shrink();
    final vehiculo = perfil.vehiculo!;
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider); // fuerza rebuild tras mutaciones externas

    final solicitudes = repo.solicitudesDeChofer(perfil.id);
    final cargas = repo.cargasDeChofer(perfil.id);
    final usado = repo.litrosAutorizadosAcumulados(perfil.id);
    final tope = vehiculo.topeSemanal;
    final disponible = (tope - usado).clamp(0, tope == 0 ? 0 : double.infinity);
    final progreso = tope > 0 ? (usado / tope).clamp(0, 1).toDouble() : 0.0;

    final foliosComprobados = cargas.map((c) => c.folioAutorizacion).toSet();
    final pendienteDeComprobar = solicitudes.where(
      (s) =>
          s.estado == EstadoSolicitud.aprobada &&
          s.folioAutorizacion != null &&
          !foliosComprobados.contains(s.folioAutorizacion),
    );
    final folioPendiente =
        pendienteDeComprobar.isEmpty ? null : pendienteDeComprobar.first.folioAutorizacion;
    final cargaAbiertaDeHoy = repo.cargaAbiertaDeHoy(perfil.id);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GradientHeader(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hola, ${perfil.nombreCompleto.split(' ').first}',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(color: colors.primaryOn),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${vehiculo.tipoUnidad} · ${vehiculo.placaONumeroEconomico}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.primaryOn.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar sesión',
                      onPressed: () => ref.read(authControllerProvider).logout(),
                      icon: Icon(Icons.logout, color: colors.primaryOn),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TarjetaTopeSemanal(
                      tope: tope,
                      usado: usado,
                      disponible: disponible.toDouble(),
                      progreso: progreso,
                    ),
                    const SizedBox(height: 20),
                    if (folioPendiente != null) ...[
                      _TarjetaCargaPendiente(
                        folio: folioPendiente,
                        onTap: () => _refrescarAlVolver(
                          () => context.push(
                            RoutePaths.choferComprobar,
                            extra: folioPendiente,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (cargaAbiertaDeHoy != null) ...[
                      _TarjetaCerrarDia(
                        onTap: () => _refrescarAlVolver(
                          () => context.push(
                            RoutePaths.choferCerrarDia,
                            extra: cargaAbiertaDeHoy,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                    ElevatedButton.icon(
                      onPressed: () => _refrescarAlVolver(
                        () => context.push(RoutePaths.choferSolicitar),
                      ),
                      icon: const Icon(Icons.local_gas_station),
                      label: const Text('Solicitar carga de combustible'),
                    ),
                    const SizedBox(height: 28),
                    Text('Actividad reciente', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    if (solicitudes.isEmpty)
                      _EstadoVacio(
                        icono: Icons.receipt_long_outlined,
                        mensaje: 'Aún no tienes solicitudes de carga.',
                      )
                    else
                      ...solicitudes.take(8).map((s) => _SolicitudTile(solicitud: s)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaCargaPendiente extends StatelessWidget {
  const _TarjetaCargaPendiente({required this.folio, required this.onTap});

  final String folio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.success.withValues(alpha: 0.08),
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: colors.success.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.success.withValues(alpha: 0.15),
                child: Icon(Icons.check_circle_outline, color: colors.success),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tienes una carga aprobada · Folio $folio',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Toca para comprobarla',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.success),
            ],
          ),
        ),
      ),
    );
  }
}

class _TarjetaCerrarDia extends StatelessWidget {
  const _TarjetaCerrarDia({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Material(
      color: colors.info.withValues(alpha: 0.08),
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: colors.info.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.info.withValues(alpha: 0.15),
                child: Icon(Icons.nights_stay_outlined, color: colors.info),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('¿Ya terminaste tu día?', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Toca para registrar tu km final',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.info),
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
    final fecha = formatearFechaCorta(solicitud.creadaEn);

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
                Text(fecha,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.textMuted)),
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

class _EstadoVacio extends StatelessWidget {
  const _EstadoVacio({required this.icono, required this.mensaje});

  final IconData icono;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(icono, size: 40, color: colors.textMuted),
          const SizedBox(height: 12),
          Text(mensaje,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}
