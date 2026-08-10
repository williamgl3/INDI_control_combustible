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
import '../../theme/app_sizes.dart';
import '../../theme/app_theme.dart';
import '../../widgets/acerca_de_dialog.dart';
import '../../widgets/app_card.dart';
import '../../widgets/ayuda_soporte_dialog.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/confirmar_cerrar_sesion_dialog.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/header_menu_button.dart';
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
    final confirmado = await confirmarCerrarSesion(context);
    if (confirmado && mounted) {
      await ref.read(authControllerProvider).logout();
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      // Mismo padding/maxWidth que `ContenidoResponsivo` (ver
      // `_buildMovil`), calculado directo con `MediaQuery` en vez de
      // `ContenidoResponsivo` en sí: el FAB vive fuera del `body` (via
      // `Scaffold.floatingActionButton`), y ese slot necesita medir el
      // tamaño intrínseco de su hijo para la animación de entrada del FAB
      // — algo que el `LayoutBuilder` interno de `ContenidoResponsivo` no
      // soporta bien (rompía el hit-test de tarjetas cercanas).
      floatingActionButton: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: ContenidoResponsivo.paddingHorizontalPara(
            MediaQuery.sizeOf(context).width,
          ),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppBreakpoints.wideContentMaxWidth,
          ),
          child: _FabSolicitar(
            onPressed: () => _refrescarAlVolver(
              () => context.push(RoutePaths.choferTipoOperacion),
            ),
          ),
        ),
      ),
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
    return BrandHeader(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LogoGlass(size: AppSizes.logoHeaderSize),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${perfil.nombreCompleto.split(' ').first}',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    color: BrandHeader.onColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Control de combustible en obra',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: BrandHeader.onColorMuted,
                  ),
                ),
              ],
            ),
          ),
          HeaderMenuButton(
            items: [
              HeaderMenuItem(
                icon: Icons.info_outline,
                label: 'Acerca de',
                onTap: () => AcercaDeDialog.show(context),
              ),
              HeaderMenuItem(
                icon: Icons.help_outline,
                label: 'Ayuda y soporte',
                onTap: () => AyudaSoporteDialog.show(context),
              ),
              HeaderMenuItem(
                icon: Icons.logout,
                label: 'Cerrar sesión',
                destructive: true,
                onTap: _cerrarSesion,
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
      duration: AppMotion.base,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Actividad reciente',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        if (solicitudes.isEmpty)
          const EstadoVacio(
            icono: Icons.receipt_long_outlined,
            mensaje: 'Aún no tienes solicitudes de carga.',
          )
        else
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
                        solicitud: s,
                        vehiculo: vehiculosRepo.porId(s.vehiculoId),
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
            paddingInferior: 88,
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
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _FabSolicitar extends StatelessWidget {
  const _FabSolicitar({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Sin `Padding` horizontal propio: el ancho/margen lateral ya lo da
    // `ContenidoResponsivo` en el `build()` de `ChoferHomeScreen`, igual
    // que a las tarjetas de arriba — duplicarlo aquí las desalineaba.
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: FloatingActionButton.extended(
        onPressed: onPressed,
        backgroundColor: colors.primary,
        foregroundColor: colors.primaryOn,
        // Mismo nivel de elevación que `AppElevatedButton` (más suave que
        // antes) — `FloatingActionButton` no expone `shadowColor` como
        // `ElevatedButton`, así que aquí solo se pareja la elevación, no
        // el tinte de color de la sombra.
        elevation: 8,
        focusElevation: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.local_gas_station_rounded, size: 24),
        label: const Text(
          'Solicitar carga',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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

    return Container(
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
    return AppCard(
      floating: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: colors.warning.withValues(alpha: 0.1),
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
