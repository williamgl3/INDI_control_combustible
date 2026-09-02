import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../models/vehiculo.dart';
import '../../router/route_paths.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_section_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/brand_sub_header.dart';
import '../../widgets/estado_solicitud_badge.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/fecha_formato.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/ios_segmented_control.dart';
import '../../widgets/chofer_operation_scaffold.dart';
import '../../widgets/section_label.dart';
import '../../widgets/sidebar_chofer.dart';
import '../../widgets/stat_tile.dart';
import '../../widgets/stat_tile_row.dart';
import 'detalle_solicitud_dialog.dart';

enum _FiltroEstado { todas, pendientes, autorizadas, ajustadas, rechazadas }

/// Historial completo de las solicitudes del chofer, con filtro por
/// estado — antes solo se veían las últimas en "Actividad reciente" del
/// home, sin poder revisar el motivo de un rechazo o de una autorización
/// parcial más allá de esa lista corta.
class MisSolicitudesScreen extends ConsumerStatefulWidget {
  const MisSolicitudesScreen({super.key, this.mostrarComoTab = false});

  /// `true` cuando esta pantalla vive embebida como una pestaña de
  /// [ChoferHomeShell] (sin `Scaffold`/`AppBar`/botón de volver propios,
  /// ya los da el shell) en vez de empujada como ruta independiente
  /// (`context.push(RoutePaths.choferSolicitudes)` desde "Accesos
  /// rápidos" del home, que sigue funcionando igual que antes).
  final bool mostrarComoTab;

  @override
  ConsumerState<MisSolicitudesScreen> createState() =>
      _MisSolicitudesScreenState();
}

class _MisSolicitudesScreenState extends ConsumerState<MisSolicitudesScreen> {
  /// "Historial" (índice 2) — el destino del sidebar que representa esta
  /// pantalla, usado solo en la ruta standalone (fuera del shell).
  static const _indiceSidebar = 2;

  _FiltroEstado _filtroVista = _FiltroEstado.todas;

  EstadoVisualSolicitud? get _filtro => switch (_filtroVista) {
    _FiltroEstado.todas => null,
    _FiltroEstado.pendientes => EstadoVisualSolicitud.pendiente,
    _FiltroEstado.autorizadas => EstadoVisualSolicitud.autorizada,
    _FiltroEstado.ajustadas => EstadoVisualSolicitud.ajustada,
    _FiltroEstado.rechazadas => EstadoVisualSolicitud.rechazada,
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
        : solicitudes.where((s) => s.estadoVisual == _filtro).toList();

    final listaSolicitudes = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatTileRow(
          tiles: [
            StatTile(
              icono: Icons.hourglass_top_outlined,
              valor: '$pendientes',
              etiqueta: 'Por revisar',
              color: colors.textSecondary,
              // Mismo criterio que la versión admin en
              // `autorizaciones_tab.dart` — el chofer es quien más
              // presión de tiempo tiene por revisar esto, no tenía
              // sentido que se viera "menos importante" aquí.
              destacado: pendientes > 0,
              onTap: () =>
                  setState(() => _filtroVista = _FiltroEstado.pendientes),
            ),
            StatTile(
              icono: Icons.local_gas_station_outlined,
              valor: litrosAutorizados.toStringAsFixed(0),
              etiqueta: 'L autorizados',
              color: AppSectionColors.autorizaciones,
              onTap: () =>
                  setState(() => _filtroVista = _FiltroEstado.autorizadas),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // 5 opciones en vez de 4 — mismo caso que el filtro de
        // Mantenimiento (ver doc de `IosSegmentedControl`): si no caben en
        // móvil, el control ya se envuelve en scroll horizontal en vez de
        // truncarse, sin que haga falta ningún ajuste aquí.
        IosSegmentedControl<_FiltroEstado>(
          valor: _filtroVista,
          opciones: const {
            _FiltroEstado.todas: 'Todas',
            _FiltroEstado.pendientes: 'Pendientes',
            _FiltroEstado.autorizadas: 'Autorizadas',
            _FiltroEstado.ajustadas: 'Ajustadas',
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
            textoAccion: _filtro == null ? 'Solicitar carga' : null,
            onAccion: _filtro == null
                ? () => context.push(RoutePaths.choferTipoOperacion)
                : null,
          )
        else
          for (final grupo in agruparPorFecha(filtradas, (s) => s.creadaEn))
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

    // Como pestaña de `ChoferHomeShell`, el header viaja con el resto del
    // scroll (igual que el Home); empujada como ruta independiente, en
    // cambio, queda fijo — así el botón de volver nunca se desplaza fuera
    // de vista al filtrar una lista larga.
    final encabezado = BrandSubHeader(
      titulo: 'Mis solicitudes',
      onBack: widget.mostrarComoTab ? null : () => volverEnFlujoChofer(context),
    );

    if (widget.mostrarComoTab) {
      // Mismo criterio que Inicio: el encabezado (banner de marca a todo
      // el ancho) va fuera de `ContenidoResponsivo`, para que no se encoja
      // como el resto del contenido — antes quedaba metido dentro del
      // scroll y se veía angosto y centrado, a diferencia de Inicio/Solicitar.
      return SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            encabezado,
            Expanded(child: ContenidoResponsivo(child: listaSolicitudes)),
          ],
        ),
      );
    }

    final contenidoStandalone = Column(
      children: [
        encabezado,
        Expanded(
          child: SafeArea(
            top: false,
            child: ContenidoResponsivo(child: listaSolicitudes),
          ),
        ),
      ],
    );

    // Ruta standalone (fuera del `IndexedStack` de `ChoferHomeShell` — se
    // llega aquí, por ejemplo, desde el sidebar de otra pantalla de
    // chofer). Sin el shell alrededor, necesita su propio sidebar en
    // pantallas anchas — mismo patrón que `TipoOperacionScreen`/
    // `SubirEvidenciasScreen`.
    if (AppBreakpoints.isTabletOrDesktop(MediaQuery.sizeOf(context).width)) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SidebarChofer(
                indiceSeleccionado: _indiceSidebar,
                onSeleccionar: (i) =>
                    navegarDesdeSidebarChofer(context, _indiceSidebar, i),
              ),
              Expanded(child: contenidoStandalone),
            ],
          ),
        ),
      );
    }

    return Scaffold(body: contenidoStandalone);
  }
}

class _SolicitudTile extends StatelessWidget {
  const _SolicitudTile({required this.solicitud, required this.vehiculo});

  final SolicitudAutorizacion solicitud;
  final Vehiculo? vehiculo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final identificadorVehiculo = vehiculo?.etiquetaUnidad;

    return AppCard(
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
                    Expanded(
                      child: Text(
                        '${solicitud.litrosSolicitados.toStringAsFixed(1)} L'
                        '${identificadorVehiculo != null ? ' · $identificadorVehiculo' : ''}',
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
                  // Solo la hora: la fecha ya la da el encabezado del
                  // grupo (ver `agruparPorFecha` en el `build` de arriba).
                  formatearHora(solicitud.creadaEn),
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
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
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
          EstadoSolicitudBadge(estadoVisual: solicitud.estadoVisual),
        ],
      ),
    );
  }
}
