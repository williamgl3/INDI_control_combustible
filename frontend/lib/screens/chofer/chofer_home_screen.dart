import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/cola_solicitudes_offline.dart';
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
import '../../widgets/acerca_de_dialog.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_status_chip.dart';
import '../../widgets/ayuda_soporte_dialog.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/confirmar_cerrar_sesion_dialog.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/chofer_header_menu_button.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/logo_glass.dart';
import '../../widgets/section_label.dart';
import '../../widgets/tarjeta_accion_sugerida.dart';
import '../../widgets/selector_tema_dialog.dart';
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

    final sinSolicitudes = solicitudes.isEmpty;
    final esPantallaAncha = AppBreakpoints.isTabletOrDesktop(
      MediaQuery.sizeOf(context).width,
    );
    return Scaffold(
      // Mismo padding/maxWidth que `ContenidoResponsivo` (ver
      // `_buildMovil`), calculado directo con `MediaQuery` en vez de
      // `ContenidoResponsivo` en sí: el FAB vive fuera del `body` (via
      // `Scaffold.floatingActionButton`), y ese slot necesita medir el
      // tamaño intrínseco de su hijo para la animación de entrada del FAB
      // — algo que el `LayoutBuilder` interno de `ContenidoResponsivo` no
      // soporta bien (rompía el hit-test de tarjetas cercanas).
      bottomNavigationBar: !sinSolicitudes && !esPantallaAncha
          ? _BarraSolicitarCarga(
              onPressed: () => context.go(RoutePaths.choferTipoOperacion),
            )
          : null,
      body: SafeArea(
        child: _buildMovil(
          perfil: perfil,
          solicitudes: solicitudes,
          vehiculosRepo: vehiculosRepo,
          vehiculoDeHoy: vehiculoDeHoy,
          folioPendiente: folioPendiente,
          cargaAbiertaDeHoy: cargaAbiertaDeHoy,
          mostrarAccionInline: !sinSolicitudes && esPantallaAncha,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Perfil perfil) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    return BrandHeader(
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
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
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
                icon: Icons.person_outline_rounded,
                label: 'Perfil',
                onSelected: () => context.go(RoutePaths.choferPerfil),
              ),
              ChoferHeaderMenuItem(
                icon: Icons.palette_outlined,
                label: 'Cambiar tema',
                onSelected: () => SelectorTemaDialog.show(context),
              ),
              ChoferHeaderMenuItem(
                icon: Icons.help_outline_rounded,
                label: 'Ayuda y soporte',
                onSelected: () => AyudaSoporteDialog.show(context),
              ),
              ChoferHeaderMenuItem(
                icon: Icons.info_outline_rounded,
                label: 'Acerca de',
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
          ],
          Consumer(
            builder: (context, ref, _) {
              final total =
                  ref.watch(totalPendientesOfflineProvider).valueOrNull ?? 0;
              if (total == 0) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _BannerPendientesOffline(cantidad: total),
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
    required bool mostrarAccionInline,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Actividad reciente',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (mostrarAccionInline) ...[
              const SizedBox(width: 16),
              SizedBox(
                width: AppSizes.choferPrimaryActionDesktopWidth,
                child: _BotonSolicitarCarga(
                  onPressed: () => context.go(RoutePaths.choferTipoOperacion),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : AppMotion.base,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: solicitudes.isEmpty
              ? _EstadoVacioSolicitudes(
                  key: const ValueKey('actividad-vacia'),
                  onSolicitar: () => context.go(RoutePaths.choferTipoOperacion),
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
    required bool mostrarAccionInline,
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
                _buildActividad(
                  context: context,
                  solicitudes: solicitudes,
                  vehiculosRepo: vehiculosRepo,
                  mostrarAccionInline: mostrarAccionInline,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BarraSolicitarCarga extends StatelessWidget {
  const _BarraSolicitarCarga({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final horizontal = ContenidoResponsivo.paddingHorizontalPara(
      MediaQuery.sizeOf(context).width,
    );
    return Material(
      color: colors.surface,
      elevation: 3,
      child: SafeArea(
        top: false,
        minimum: EdgeInsets.fromLTRB(
          horizontal,
          AppSizes.choferPrimaryActionVerticalPadding,
          horizontal,
          AppSizes.choferPrimaryActionVerticalPadding,
        ),
        child: _BotonSolicitarCarga(onPressed: onPressed),
      ),
    );
  }
}

class _BotonSolicitarCarga extends StatelessWidget {
  const _BotonSolicitarCarga({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
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
        child: FloatingActionButton.extended(
          onPressed: onPressed,
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryOn,
          // Mismo nivel de elevación que `AppElevatedButton` (más suave que
          // antes) — `FloatingActionButton` no expone `shadowColor` como
          // `ElevatedButton`, así que aquí solo se pareja la elevación, no
          // el tinte de color de la sombra.
          elevation: 2,
          focusElevation: 4,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.buttonRadius,
          ),
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

class _EstadoVacioSolicitudes extends StatelessWidget {
  const _EstadoVacioSolicitudes({super.key, required this.onSolicitar});

  final VoidCallback onSolicitar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: 'Sin solicitudes de carga',
      child: Container(
        key: const ValueKey('estado-vacio-solicitudes-chofer'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.local_gas_station_outlined,
                  size: 30,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Aún no tienes solicitudes de carga.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(
                'Crea tu primera solicitud para comenzar.',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('solicitar-desde-estado-vacio'),
                onPressed: onSolicitar,
                icon: const Icon(Icons.local_gas_station_rounded),
                label: const Text('Solicitar carga'),
              ),
            ],
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

    return AppCard(
      floating: true,
      onTap: () => DetalleSolicitudDialog.show(
        context,
        solicitud: solicitud,
        vehiculo: vehiculo,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${solicitud.litrosSolicitados.toStringAsFixed(1)} L',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontFamily: 'IBM Plex Mono',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      ' solicitados',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    hora,
                    if (vehiculo != null)
                      vehiculo!.modelo ?? vehiculo!.tipoUnidad,
                    if (vehiculo != null) vehiculo!.etiquetaUnidad,
                    if (vehiculo != null)
                      '· ${vehiculo!.tipoCombustible ?? 'Sin especificar'}',
                  ].join(' · '),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  'Programada: ${formatearFecha(solicitud.fechaProgramada)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
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
          _BadgeEstado(estadoVisual: solicitud.estadoVisual),
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
        colors.warning,
        'En espera',
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
        colors.warning,
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
          border: Border.all(color: color.withValues(alpha: 0.3)),
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
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.success.withValues(alpha: 0.5)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colors.success.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.local_gas_station,
                  color: colors.success,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
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
                    const SizedBox(height: 2),
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
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: colors.success,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt, size: 14, color: colors.primaryOn),
                    const SizedBox(width: 4),
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
  const _BannerPendientesOffline({required this.cantidad});

  final int cantidad;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final offline = context.statusColors.offline;
    return AppCard(
      floating: true,
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
