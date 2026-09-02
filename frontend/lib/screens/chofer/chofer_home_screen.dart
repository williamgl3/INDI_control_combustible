import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/cola_solicitudes_offline.dart';
import '../../core/estadistica_carga_provider.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../data/vehiculos_repository.dart';
import '../../models/perfil.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_sizes.dart';
import '../../theme/app_status_colors.dart';
import '../../theme/app_theme.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/acerca_de_dialog.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_status_chip.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/confirmar_cerrar_sesion_dialog.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/chofer_header_menu_button.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/logo_glass.dart';
import '../../widgets/section_label.dart';
import '../../widgets/tarjeta_accion_sugerida.dart';
import 'detalle_solicitud_dialog.dart';

class ChoferHomeScreen extends ConsumerStatefulWidget {
  const ChoferHomeScreen({super.key});

  @override
  ConsumerState<ChoferHomeScreen> createState() => _ChoferHomeScreenState();
}

class _ChoferHomeScreenState extends ConsumerState<ChoferHomeScreen> {
  int _refreshKey = 0;
  bool _cerrandoSesion = false;
  bool _procesandoLogout = false;

  Future<void> _refrescarAlVolver(Future<void> Function() accion) async {
    await accion();
    if (mounted) setState(() => _refreshKey++);
  }

  /// Mismo patrón que `MiPerfilScreen._cerrarSesion`: confirma, y si acepta
  /// delega en `AuthController.logout()` — limpia tokens/perfil y notifica
  /// `sessionProvider`, el mismo mecanismo que ya usa el guard de go_router
  /// para redirigir a login cuando expira la sesión (401), sin duplicar
  /// lógica aquí.
  Future<void> _cerrarSesion() async {
    if (_cerrandoSesion) return;
    setState(() => _cerrandoSesion = true);
    try {
      final pendientes = await ref.read(totalPendientesOfflineProvider.future);
      if (!mounted) return;
      final confirmado = await confirmarCerrarSesion(
        context,
        tienePendientesOffline: pendientes > 0,
      );
      if (confirmado && mounted) {
        final router = GoRouter.of(context);
        setState(() => _procesandoLogout = true);
        await ref.read(authControllerProvider).logout();
        router.go(RoutePaths.login);
      }
    } finally {
      if (mounted) {
        setState(() {
          _cerrandoSesion = false;
          _procesandoLogout = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final perfil = ref.watch(sessionProvider);
    if (perfil == null) return const SizedBox.shrink();
    final repo = ref.watch(operacionesRepositoryProvider);
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);
    ref.watch(operacionesTickProvider);

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

    final vehiculoDeHoy = cargaAbiertaDeHoy == null
        ? null
        : vehiculosRepo.porId(cargaAbiertaDeHoy.vehiculoId);

    return Scaffold(
      // Mismo padding/maxWidth que `ContenidoResponsivo` (ver
      // `_buildMovil`), calculado directo con `MediaQuery` en vez de
      // `ContenidoResponsivo` en sí: el FAB vive fuera del `body` (via
      // `Scaffold.floatingActionButton`), y ese slot necesita medir el
      // tamaño intrínseco de su hijo para la animación de entrada del FAB
      // — algo que el `LayoutBuilder` interno de `ContenidoResponsivo` no
      // soporta bien (rompía el hit-test de tarjetas cercanas).
      body: SafeArea(
        child: _buildMovil(
          perfil: perfil,
          solicitudes: solicitudes,
          vehiculosRepo: vehiculosRepo,
          vehiculoDeHoy: vehiculoDeHoy,
          folioPendiente: folioPendiente,
          cargaAbiertaDeHoy: cargaAbiertaDeHoy,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Perfil perfil) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return BrandHeader(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IndiLogo(width: internalHeaderLogoWidth(screenWidth)),
          SizedBox(width: internalHeaderLogoGap(screenWidth)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${perfil.nombreCompleto.split(' ').first}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: BrandHeader.onColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Control de combustible en obra',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BrandHeader.onColorMuted,
                  ),
                ),
              ],
            ),
          ),
          ChoferHeaderMenuButton(
            items: [
              ChoferHeaderMenuItem(
                icon: Icons.local_gas_station_outlined,
                label: 'Mi consumo',
                onSelected: () => context.go(RoutePaths.choferDashboard),
              ),
              ChoferHeaderMenuItem(
                icon: Icons.assignment_outlined,
                label: 'Mis solicitudes',
                onSelected: () => context.go(RoutePaths.choferSolicitudes),
              ),
              ChoferHeaderMenuItem(
                icon: Icons.info_outline_rounded,
                label: 'Acerca de',
                dividerBefore: true,
                onSelected: () => AcercaDeDialog.show(context),
              ),
              ChoferHeaderMenuItem(
                icon: Icons.logout_rounded,
                label: _procesandoLogout ? 'Cerrando sesión…' : 'Cerrar sesión',
                destructive: true,
                onSelected: _cerrandoSesion ? () {} : _cerrarSesion,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAlertas({
    required BuildContext context,
    required Vehiculo? vehiculoDeHoy,
    required String? folioPendiente,
    required dynamic cargaAbiertaDeHoy,
  }) {
    final colors = context.colors;
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.base,
      curve: AppMotion.curve,
      alignment: Alignment.topCenter,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (vehiculoDeHoy != null) ...[
            Text(
              'Hoy usas: ${vehiculoDeHoy.modelo ?? vehiculoDeHoy.tipoUnidad} · '
              '${vehiculoDeHoy.etiquetaUnidad}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (folioPendiente != null) ...[
            _BannerCargaAprobada(
              folio: folioPendiente,
              onTap: () => _refrescarAlVolver(
                () => context.push(
                  RoutePaths.choferComprobar,
                  extra: folioPendiente,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          if (cargaAbiertaDeHoy != null) ...[
            TarjetaAccionSugerida(
              icono: Icons.nights_stay_outlined,
              color: colors.info,
              titulo: '¿Ya terminaste tu día?',
              subtitulo: 'Toca para registrar tu km final',
              onTap: () => _refrescarAlVolver(
                () => context.push(
                  RoutePaths.choferCerrarDia,
                  extra: cargaAbiertaDeHoy,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Consumer(
            builder: (context, ref, _) {
              final stats = ref.watch(estadisticaCargaHoyProvider);
              if (stats.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: TarjetaAccionSugerida(
                  icono: Icons.insights_rounded,
                  color: colors.success,
                  titulo: 'Estadísticas de carga',
                  subtitulo:
                      '${stats.totalCargas} carga${stats.totalCargas == 1 ? '' : 's'} · '
                      '${stats.litrosTotales.toStringAsFixed(1)} L hoy',
                  onTap: () => context.go(RoutePaths.choferEstadisticasCarga),
                ),
              );
            },
          ),
          Consumer(
            builder: (context, ref, _) {
              final total =
                  ref.watch(totalPendientesOfflineProvider).valueOrNull ?? 0;
              if (total == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: AppSpacing.md),
                child: _BannerPendientesOffline(
                  cantidad: total,
                  onTap: () =>
                      context.go(RoutePaths.choferCentroSincronizacion),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActividad({
    required BuildContext context,
    required List<SolicitudAutorizacion> solicitudes,
    required VehiculosRepository vehiculosRepo,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Actividad reciente',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.base,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: solicitudes.isEmpty
              ? const EstadoVacio(
                  key: ValueKey('actividad-vacia'),
                  icono: Icons.receipt_long_outlined,
                  mensaje: 'Aún no tienes solicitudes de carga.',
                )
              : Column(
                  key: const ValueKey('actividad-con-datos'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final grupo in agruparPorFecha(
                      solicitudes.take(5).toList(),
                      (s) => s.creadaEn,
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionLabel(grupo.etiqueta),
                            for (final s in grupo.items)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: _SolicitudTile(
                                  key: ValueKey('solicitud-${s.id}'),
                                  solicitud: s,
                                  vehiculo: vehiculosRepo.porId(s.vehiculoId),
                                ),
                              ),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () =>
                            context.go(RoutePaths.choferSolicitudes),
                        icon: const Icon(Icons.history_rounded, size: 18),
                        label: const Text('Ver historial'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildMovil({
    required Perfil perfil,
    required List<SolicitudAutorizacion> solicitudes,
    required VehiculosRepository vehiculosRepo,
    required Vehiculo? vehiculoDeHoy,
    required String? folioPendiente,
    required dynamic cargaAbiertaDeHoy,
  }) {
    return Column(
      children: [
        _buildHeader(context, perfil),
        Expanded(
          // Mismo `ContenidoResponsivo` compartido por todo el panel de
          // chofer — ver `ChoferHomeShell` (ya no envuelve las pestañas en
          // un tope de 480px, cada una controla el suyo).
          child: ContenidoResponsivo(
            paddingSuperior: 16,
            paddingInferior: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAlertas(
                  context: context,
                  vehiculoDeHoy: vehiculoDeHoy,
                  folioPendiente: folioPendiente,
                  cargaAbiertaDeHoy: cargaAbiertaDeHoy,
                ),
                const SizedBox(height: 20),
                _AccionesInicioChofer(
                  onSolicitar: () =>
                      context.push(RoutePaths.choferTipoOperacion),
                  onMiConsumo: () => context.go(RoutePaths.choferDashboard),
                  onMisSolicitudes: () =>
                      context.go(RoutePaths.choferSolicitudes),
                ),
                const SizedBox(height: 24),
                _buildActividad(
                  context: context,
                  solicitudes: solicitudes,
                  vehiculosRepo: vehiculosRepo,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccionesInicioChofer extends StatelessWidget {
  const _AccionesInicioChofer({
    required this.onSolicitar,
    required this.onMiConsumo,
    required this.onMisSolicitudes,
  });

  final VoidCallback onSolicitar;
  final VoidCallback onMiConsumo;
  final VoidCallback onMisSolicitudes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Acciones', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: AppSpacing.md),
        _BotonSolicitarCarga(onPressed: onSolicitar),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AccesoRapidoChofer(
                key: const ValueKey('inicio-mi-consumo'),
                icono: Icons.insights_outlined,
                etiqueta: 'Mi consumo',
                onTap: onMiConsumo,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _AccesoRapidoChofer(
                key: const ValueKey('inicio-mis-solicitudes'),
                icono: Icons.assignment_outlined,
                etiqueta: 'Mis solicitudes',
                onTap: onMisSolicitudes,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccesoRapidoChofer extends StatelessWidget {
  const _AccesoRapidoChofer({
    super.key,
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
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, color: colors.primary, size: 22),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              etiqueta,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _BotonSolicitarCarga extends StatelessWidget {
  const _BotonSolicitarCarga({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final esEscritorio = AppBreakpoints.isTabletOrDesktop(
      MediaQuery.sizeOf(context).width,
    );
    // Sin `Padding` horizontal propio: el ancho/margen lateral ya lo da
    // `ContenidoResponsivo` en el `build()` de `ChoferHomeScreen`, igual
    // que a las tarjetas de arriba — duplicarlo aquí las desalineaba.
    return Align(
      alignment: esEscritorio ? Alignment.centerRight : Alignment.center,
      child: SizedBox(
        key: const ValueKey('accion-solicitar-carga'),
        width: esEscritorio
            ? AppSizes.choferPrimaryActionDesktopWidth
            : double.infinity,
        height: AppSizes.choferPrimaryActionHeight,
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.local_gas_station_rounded, size: 24),
          label: const Text(
            'Solicitar carga',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({
    super.key,
    required this.solicitud,
    required this.vehiculo,
  });

  final SolicitudAutorizacion solicitud;
  final Vehiculo? vehiculo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hora = formatearHora(solicitud.creadaEn);
    final unidad = vehiculo == null
        ? null
        : [
            vehiculo!.modelo ?? vehiculo!.tipoUnidad,
            vehiculo!.etiquetaUnidad,
          ].join(' · ');
    final combustible = vehiculo?.tipoCombustible ?? 'Sin especificar';
    final detalle = vehiculo == null ? hora : '$combustible · $hora';

    return AppCard(
      floating: true,
      onTap: () => DetalleSolicitudDialog.show(
        context,
        solicitud: solicitud,
        vehiculo: vehiculo,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text:
                            '${solicitud.litrosSolicitados.toStringAsFixed(1)} L',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontFamily: 'IBM Plex Mono',
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      TextSpan(
                        text: ' solicitados',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (unidad != null) ...[
                  Text(
                    unidad,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  detalle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Programada: ${formatearFecha(solicitud.fechaProgramada)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                if (solicitud.comentario != null) ...[
                  const SizedBox(height: AppSpacing.xs),
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
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: _BadgeEstado(estadoVisual: solicitud.estadoVisual),
            ),
          ),
        ],
      ),
    );
  }
}

class _BadgeEstado extends StatelessWidget {
  const _BadgeEstado({required this.estadoVisual});

  final EstadoVisualSolicitud estadoVisual;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, texto, icono) = switch (estadoVisual) {
      EstadoVisualSolicitud.pendiente => (
        colors.textSecondary,
        'Por autorizar',
        Icons.schedule_outlined,
      ),
      EstadoVisualSolicitud.autorizada => (
        colors.success,
        'Autorizado',
        Icons.check_circle_outline,
      ),
      // Mismo criterio que `EstadoSolicitudBadge`: ámbar (advertencia),
      // no rojo — un ajuste no es un error, es algo que el chofer debe
      // notar antes de ir a cargar.
      EstadoVisualSolicitud.ajustada => (
        colors.textSecondary,
        'Ajustado',
        Icons.tune_outlined,
      ),
      EstadoVisualSolicitud.rechazada => (
        colors.error,
        'Rechazado',
        Icons.cancel_outlined,
      ),
    };

    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : AppMotion.fast,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: Container(
        key: ValueKey(estadoVisual),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              texto.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BannerCargaAprobada extends StatelessWidget {
  const _BannerCargaAprobada({required this.folio, required this.onTap});

  final String folio;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.success.withValues(alpha: 0.14),
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: colors.success.withValues(alpha: 0.28)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_gas_station_outlined,
                color: colors.success,
                size: 24,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Carga aprobada',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Folio $folio',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: colors.success,
                  borderRadius: AppRadii.navButtonRadius,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: colors.primaryOn),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      'COMPROBAR AHORA',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.primaryOn,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
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

class _BannerPendientesOffline extends StatelessWidget {
  const _BannerPendientesOffline({required this.cantidad, this.onTap});

  final int cantidad;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final offline = context.statusColors.offline;
    return AppCard(
      floating: true,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: offline.withValues(alpha: 0.08),
      child: Row(
        children: [
          AppStatusChip(
            label: 'Pendiente',
            icon: Icons.cloud_off_outlined,
            color: offline,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              cantidad == 1
                  ? 'Tienes 1 operación guardada sin conexión — toca para ver detalles.'
                  : 'Tienes $cantidad operaciones guardadas sin conexión — toca para ver detalles.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
          ),
          if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              color: colors.textMuted,
              size: 20,
            ),
        ],
      ),
    );
  }
}
