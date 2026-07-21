import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/cola_solicitudes_offline.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/grouped_section.dart';
import '../../widgets/notificaciones_bell.dart';
import '../../widgets/selector_tema_dialog.dart';
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
    final repo = ref.watch(operacionesRepositoryProvider);
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);
    ref.watch(
      operacionesTickProvider,
    ); // fuerza rebuild tras mutaciones externas

    final solicitudes = repo.solicitudesDeChofer(perfil.id);
    final cargas = repo.cargasDeChofer(perfil.id);

    final foliosComprobados = cargas.map((c) => c.folioAutorizacion).toSet();
    final pendienteDeComprobar = solicitudes.where(
      (s) =>
          s.estado == EstadoSolicitud.aprobada &&
          s.folioAutorizacion != null &&
          !foliosComprobados.contains(s.folioAutorizacion),
    );
    final folioPendiente = pendienteDeComprobar.isEmpty
        ? null
        : pendienteDeComprobar.first.folioAutorizacion;
    final cargaAbiertaDeHoy = repo.cargaAbiertaDeHoy(perfil.id);

    // El tope semanal ya no es del chofer, es del vehículo que esté
    // usando hoy — solo se muestra si ya cargó combustible hoy.
    final vehiculoDeHoy = cargaAbiertaDeHoy == null
        ? null
        : vehiculosRepo.porId(cargaAbiertaDeHoy.vehiculoId);
    final usado = vehiculoDeHoy == null
        ? 0.0
        : repo.litrosAutorizadosAcumulados(vehiculoDeHoy.id);
    final tope = vehiculoDeHoy?.topeSemanal ?? 0;
    final disponible = (tope - usado).clamp(0, tope == 0 ? 0 : double.infinity);
    final progreso = tope > 0 ? (usado / tope).clamp(0, 1).toDouble() : 0.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  BrandHeader(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: AppRadii.inputRadius,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: Image.asset(
                              'assets/images/logo_indi.jpeg',
                              width: 34,
                              height: 34,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hola, ${perfil.nombreCompleto.split(' ').first}',
                                style: Theme.of(context).textTheme.displayLarge
                                    ?.copyWith(color: BrandHeader.onColor),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Control de combustible en obra',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: BrandHeader.onColorMuted,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const NotificacionesBell(color: BrandHeader.onColor),
                        IconButton(
                          tooltip: 'Mi perfil',
                          onPressed: () =>
                              context.push(RoutePaths.choferPerfil),
                          icon: const Icon(
                            Icons.person_outline,
                            color: BrandHeader.onColor,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Tema',
                          onPressed: () => SelectorTemaDialog.show(context),
                          icon: const Icon(
                            Icons.brightness_6_outlined,
                            color: BrandHeader.onColor,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Cerrar sesión',
                          onPressed: () =>
                              ref.read(authControllerProvider).logout(),
                          icon: const Icon(
                            Icons.logout,
                            color: BrandHeader.onColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSize(
                          duration: AppMotion.base,
                          curve: AppMotion.curve,
                          alignment: Alignment.topCenter,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (vehiculoDeHoy != null) ...[
                                Text(
                                  'Hoy usas: ${vehiculoDeHoy.tipoUnidad} · ${vehiculoDeHoy.identificador}',
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: colors.textSecondary),
                                ),
                                const SizedBox(height: 8),
                                TarjetaTopeSemanal(
                                  tope: tope,
                                  usado: usado,
                                  disponible: disponible.toDouble(),
                                  progreso: progreso,
                                ),
                                const SizedBox(height: 20),
                              ],
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
                            ],
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _refrescarAlVolver(
                            () => context.push(RoutePaths.choferSolicitar),
                          ),
                          icon: const Icon(Icons.local_gas_station_outlined),
                          label: const Text('Solicitar carga de combustible'),
                        ),
                        const SizedBox(height: 16),
                        _AccesosRapidos(
                          onMiConsumo: () =>
                              context.push(RoutePaths.choferDashboard),
                          onMisSolicitudes: () =>
                              context.push(RoutePaths.choferSolicitudes),
                        ),
                        Consumer(
                          builder: (context, ref, _) {
                            // Cuenta las cuatro colas offline (solicitar
                            // carga, comprobar carga, cerrar día, reportar
                            // incidencia) — no solo la primera.
                            final total = ref
                                    .watch(totalPendientesOfflineProvider)
                                    .valueOrNull ??
                                0;
                            if (total == 0) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: _BannerPendientesOffline(cantidad: total),
                            );
                          },
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Actividad reciente',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        if (solicitudes.isEmpty)
                          EstadoVacio(
                            icono: Icons.receipt_long_outlined,
                            mensaje: 'Aún no tienes solicitudes de carga.',
                          )
                        else
                          GroupedSection(
                            children: [
                              for (final s in solicitudes.take(8))
                                _SolicitudTile(
                                  solicitud: s,
                                  vehiculo: vehiculosRepo.porId(s.vehiculoId),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
        hoverColor: colors.success.withValues(alpha: 0.12),
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
                    Text(
                      'Tienes una carga aprobada · Folio $folio',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toca para comprobarla',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
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
        hoverColor: colors.info.withValues(alpha: 0.12),
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
                    Text(
                      '¿Ya terminaste tu día?',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Toca para registrar tu km final',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
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
  const _SolicitudTile({required this.solicitud, required this.vehiculo});

  final SolicitudAutorizacion solicitud;
  final Vehiculo? vehiculo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fecha = formatearFechaCorta(solicitud.creadaEn);

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
                      ? fecha
                      : '$fecha · ${vehiculo!.tipoUnidad} ${vehiculo!.identificador}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
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

/// Fila de atajos a las secciones nuevas del chofer — antes de esto solo
/// existían "Solicitar carga" y "Comprobar carga"/"Cerrar día" (estas
/// últimas solo aparecen como tarjeta cuando aplican).
class _AccesosRapidos extends StatelessWidget {
  const _AccesosRapidos({
    required this.onMiConsumo,
    required this.onMisSolicitudes,
  });

  final VoidCallback onMiConsumo;
  final VoidCallback onMisSolicitudes;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _BotonAcceso(
            icono: Icons.insights_outlined,
            etiqueta: 'Mi consumo',
            onTap: onMiConsumo,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _BotonAcceso(
            icono: Icons.assignment_outlined,
            etiqueta: 'Mis solicitudes',
            onTap: onMisSolicitudes,
          ),
        ),
      ],
    );
  }
}

class _BotonAcceso extends StatelessWidget {
  const _BotonAcceso({
    required this.icono,
    required this.etiqueta,
    required this.onTap,
  });

  final IconData icono;
  final String etiqueta;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: colors.border),
          ),
          child: Column(
            children: [
              Icon(icono, color: colors.primary, size: 22),
              const SizedBox(height: 6),
              Text(
                etiqueta,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerPendientesOffline extends StatelessWidget {
  const _BannerPendientesOffline({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 18, color: colors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              cantidad == 1
                  ? 'Tienes 1 solicitud guardada sin conexión — se enviará sola.'
                  : 'Tienes $cantidad solicitudes guardadas sin conexión — se enviarán solas.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
