import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/capacidades_rol.dart';
import '../../core/flujo_diario_provider.dart';
import '../../core/session_provider.dart';
import '../../router/route_paths.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/chofer_operation_scaffold.dart';
import '../../widgets/paso_diario_stepper.dart';
import '../../widgets/sidebar_chofer.dart';

/// Pantalla intermedia entre "Solicitar carga" y el formulario real: el
/// chofer elige primero qué tipo de unidad va a operar hoy, y de ahí se
/// navega ya filtrado al mismo formulario único ([SolicitarCargaScreen])
/// o, para Marimba/Despacho, al recorrido operativo — ver
/// `tiposUnidadVehiculo` en `catalogos_vehiculo.dart` para el catálogo
/// compartido de categorías.
///
/// Es una ruta empujada por separado (`context.push`), no un tab de
/// `ChoferHomeShell` — por eso trae su propio sidebar (en pantallas
/// anchas) y su propio stepper, en vez de heredarlos del shell.
class TipoOperacionScreen extends ConsumerWidget {
  const TipoOperacionScreen({super.key});

  /// "Solicitar" (índice 1) es el destino que representa este flujo
  /// completo (tipo de operación → formulario).
  static const _indiceSidebar = 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final perfil = ref.watch(sessionProvider);
    final nombre = perfil?.nombreCompleto.split(' ').first ?? '';
    final paso = ref.watch(pasoDiarioProvider);

    // Header de marca fijo (full-bleed, no se capa), y el contenido debajo
    // va en `ContenidoResponsivo` — el patrón de referencia compartido por
    // todas las pantallas del panel de chofer (ver widget para detalles).
    final puedeOperarGranel =
        perfil != null &&
        tieneCapacidad(perfil.rol, CapacidadOperativa.solicitarUnidadGranel);
    final tarjetas = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PasoDiarioStepper(
          unidad: paso.unidad,
          tablero: paso.tablero,
          solicitud: paso.solicitud,
          evidencia: paso.evidencia,
          pasoActivo: PasoDiarioTipo.unidad,
        ),
        const SizedBox(height: AppSpacing.lg),
        if (puedeOperarGranel) ...[
          _TarjetaTipoOperacion(
            icono: Icons.local_shipping_rounded,
            color: context.colors.primary,
            titulo: 'Cargar la marimba',
            subtitulo: 'Solicitud y comprobación de la carga a granel',
            onTap: () =>
                context.push(RoutePaths.solicitud(CategoriaSolicitud.granel)),
          ),
          const SizedBox(height: AppSpacing.lg),
          _TarjetaTipoOperacion(
            icono: Icons.local_gas_station_rounded,
            color: context.colors.primary,
            titulo: 'Registrar despacho',
            subtitulo: 'Recorrido con varios despachos a maquinaria en campo',
            onTap: () => context.push(RoutePaths.choferRecorridoMarimba),
          ),
        ] else ...[
          _TarjetaTipoOperacion(
            icono: Icons.directions_car_rounded,
            color: context.colors.primary,
            titulo: 'Vehículo Ligero',
            subtitulo: 'Camionetas, pickups y autos (registro por km)',
            onTap: () =>
                context.push(RoutePaths.solicitud(CategoriaSolicitud.vehiculo)),
          ),
          const SizedBox(height: AppSpacing.lg),
          _TarjetaTipoOperacion(
            icono: Icons.precision_manufacturing_rounded,
            color: context.colors.primary,
            titulo: 'Maquinaria Pesada',
            subtitulo:
                'Excavadoras, retro y camiones (horómetro y '
                'mantenimiento)',
            onTap: () => context.push(
              RoutePaths.solicitud(CategoriaSolicitud.maquinaria),
            ),
          ),
        ],
      ],
    );

    return ChoferOperationScaffold(
      titulo: '¡Hola, $nombre! ¿Qué unidad vas a operar hoy?',
      lateral: SidebarChofer(
        indiceSeleccionado: _indiceSidebar,
        onSeleccionar: (i) =>
            navegarDesdeSidebarChofer(context, _indiceSidebar, i),
      ),
      child: tarjetas,
    );
  }
}

/// Tarjeta flotante de alto impacto visual para una opción de tipo de
/// unidad: ícono grande en círculo de color, título+subtítulo y chevron.
class _TarjetaTipoOperacion extends StatelessWidget {
  const _TarjetaTipoOperacion({
    required this.icono,
    required this.color,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      floating: true,
      onTap: onTap,
      rippleColor: color,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 30),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  subtitulo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  }
}
