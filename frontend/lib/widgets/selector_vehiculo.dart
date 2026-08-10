import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers.dart';
import '../models/vehiculo.dart';
import '../screens/chofer/reportar_vehiculo_nuevo_dialog.dart';
import '../theme/app_borders.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

const _valorVehiculoNuevo = '__nuevo__';

/// Selector de "qué vehículo vas a usar" — se elige en cada solicitud/
/// comprobación de carga, ya no es un dato fijo del perfil del chofer
/// (ver `Vehiculo`). Incluye la opción de reportar una unidad que no
/// está en el catálogo, y una caja de búsqueda (necesaria desde que el
/// catálogo pasó a tener ~96 unidades entre placas y números
/// económicos).
class SelectorVehiculo extends ConsumerStatefulWidget {
  const SelectorVehiculo({
    super.key,
    required this.vehiculoSeleccionado,
    required this.onSeleccionar,
    this.filtroTipoUnidad,
    this.filtroUnidad,
    this.tipoUnidadInicialReporte,
    this.filtroUbicacion,
  });

  final Vehiculo? vehiculoSeleccionado;
  final ValueChanged<Vehiculo> onSeleccionar;

  /// Restringe el catálogo mostrado a un solo `tipoUnidad` (ej.
  /// "Maquinaria") — usado cuando el chofer ya eligió una categoría en
  /// `TipoOperacionScreen`. `null` (default) muestra el catálogo completo.
  final String? filtroTipoUnidad;
  final bool Function(Vehiculo unidad)? filtroUnidad;
  final String? tipoUnidadInicialReporte;

  /// Restringe el catálogo a `vehiculo.ubicacion == filtroUbicacion` (ej.
  /// el frente de un recorrido de marimba) — con "ver todas" disponible
  /// vía [_verTodasUbicaciones] cuando la máquina buscada no aparece
  /// (la ubicación del inventario puede estar desactualizada). `null`
  /// (default) no filtra por ubicación.
  final String? filtroUbicacion;

  @override
  ConsumerState<SelectorVehiculo> createState() => _SelectorVehiculoState();
}

class _SelectorVehiculoState extends ConsumerState<SelectorVehiculo> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';
  bool _verTodasUbicaciones = false;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  /// Mayúsculas y sin guiones/espacios — para que "PL-0762-C", "pl0762c"
  /// y "PL 0762 C" se traten como la misma búsqueda. Se aplica igual al
  /// término que escribe el chofer y al valor guardado, así ninguno de
  /// los dos lados necesita venir ya "bien escrito".
  static String _normalizarParaBusqueda(String texto) =>
      texto.toUpperCase().replaceAll(RegExp(r'[-\s]'), '');

  bool _coincide(Vehiculo v, String consultaNormalizada) {
    if (consultaNormalizada.isEmpty) return true;
    if (_normalizarParaBusqueda(v.placas ?? '').contains(consultaNormalizada)) {
      return true;
    }
    if (_normalizarParaBusqueda(
      v.numeroEconomico ?? '',
    ).contains(consultaNormalizada)) {
      return true;
    }
    if (_normalizarParaBusqueda(v.modelo ?? '').contains(consultaNormalizada)) {
      return true;
    }
    return false;
  }

  Future<void> _manejarSeleccion(
    BuildContext context,
    WidgetRef ref,
    String? valor,
  ) async {
    if (valor == null) return;
    if (valor == _valorVehiculoNuevo) {
      final nuevo = await ReportarVehiculoNuevoDialog.show(
        context,
        tipoUnidadInicial:
            widget.tipoUnidadInicialReporte ?? widget.filtroTipoUnidad,
      );
      if (nuevo != null) widget.onSeleccionar(nuevo);
      return;
    }
    final repo = ref.read(vehiculosRepositoryProvider);
    final vehiculo = repo.porId(valor);
    if (vehiculo != null) widget.onSeleccionar(vehiculo);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final catalogo = ref.watch(catalogoUnidadesProvider);
    if (catalogo.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (catalogo.hasError) {
      return Semantics(
        liveRegion: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('No fue posible cargar las unidades.'),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => ref.invalidate(catalogoUnidadesProvider),
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }
    final filtro = widget.filtroTipoUnidad;
    final filtroSemantico = widget.filtroUnidad;
    final filtroUbicacion = widget.filtroUbicacion;
    final vehiculosSinUbicacion = catalogo.requireValue
        .where(
          (v) =>
              v.activo &&
              (filtro == null || v.tipoUnidad == filtro) &&
              (filtroSemantico == null || filtroSemantico(v)),
        )
        .toList();
    final vehiculosDeLaUbicacion = filtroUbicacion == null
        ? vehiculosSinUbicacion
        : vehiculosSinUbicacion
              .where((v) => v.ubicacion == filtroUbicacion)
              .toList();
    // Si el filtro por ubicación deja la lista vacía (inventario
    // desactualizado) no tiene sentido bloquear con "ver todas" oculto —
    // se muestra el catálogo completo directo, sin que el operador tenga
    // que descubrir el botón primero.
    final hayQueOfrecerVerTodas =
        filtroUbicacion != null && vehiculosDeLaUbicacion.isNotEmpty;
    final vehiculos = (!hayQueOfrecerVerTodas || _verTodasUbicaciones)
        ? vehiculosSinUbicacion
        : vehiculosDeLaUbicacion;

    final consultaNormalizada = _normalizarParaBusqueda(_busqueda);
    final vehiculosFiltrados = vehiculos
        .where((v) => _coincide(v, consultaNormalizada))
        .toList();
    // La unidad ya elegida siempre debe seguir en la lista de opciones
    // aunque la búsqueda en curso no la incluya — si no, `DropdownButton`
    // truena (su `value` dejaría de matchear ningún `item`).
    final seleccionado = widget.vehiculoSeleccionado;
    if (seleccionado != null &&
        !vehiculosFiltrados.any((v) => v.id == seleccionado.id)) {
      vehiculosFiltrados.insert(0, seleccionado);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hayQueOfrecerVerTodas) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () =>
                  setState(() => _verTodasUbicaciones = !_verTodasUbicaciones),
              child: Text(
                _verTodasUbicaciones
                    ? 'Ver solo "$filtroUbicacion"'
                    : 'No la encuentro — ver todo el catálogo',
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
        if (vehiculos.length > 6) ...[
          TextField(
            controller: _busquedaController,
            decoration: const InputDecoration(
              labelText: 'Buscar por placa, económico o modelo',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _busqueda = v),
          ),
          const SizedBox(height: 12),
        ],
        // Fondo blanco + sombra propia (en vez del `fillColor` gris casi
        // idéntico al fondo de la pantalla que usa el resto de los
        // inputs) — así combina con el resto de cards de la pantalla en
        // vez de verse plano/perdido contra el fondo.
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.cardRadius,
            boxShadow: context.shadows.card,
          ),
          child: DropdownButtonFormField<String>(
            initialValue: seleccionado?.id,
            decoration: InputDecoration(
              labelText: '¿Qué vehículo vas a usar?',
              filled: true,
              fillColor: colors.surface,
              prefixIcon: Icon(
                Icons.local_shipping_outlined,
                color: colors.textMuted,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadii.cardRadius,
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadii.cardRadius,
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadii.cardRadius,
                borderSide: BorderSide(
                  color: colors.primary,
                  width: AppBorders.focus,
                ),
              ),
            ),
            isExpanded: true,
            // `null` para que cada opción mida lo que necesite su
            // contenido — modelo + identificador + badge de combustible
            // no caben en la altura fija de un solo renglón.
            itemHeight: null,
            selectedItemBuilder: (context) => [
              ...vehiculosFiltrados.map(
                (v) => _OpcionVehiculo(vehiculo: v, compacto: true),
              ),
              const SizedBox.shrink(),
            ],
            items: [
              ...vehiculosFiltrados.map(
                (v) => DropdownMenuItem(
                  value: v.id,
                  child: _OpcionVehiculo(vehiculo: v),
                ),
              ),
              DropdownMenuItem(
                value: _valorVehiculoNuevo,
                child: Semantics(
                  button: true,
                  label: 'Agregar vehículo que no está en la lista',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 48),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_circle_outline_rounded,
                          size: 24,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Agregar vehículo que no está en la lista',
                            style: TextStyle(color: colors.primary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            validator: (v) =>
                v == null ? 'Elige el vehículo que vas a usar.' : null,
            onChanged: (valor) => _manejarSeleccion(context, ref, valor),
          ),
        ),
      ],
    );
  }
}

/// Modelo como texto principal, identificador (placas/económico, o
/// ambos si la unidad tiene los dos — ej. la marimba) en tipografía
/// monoespaciada, y el combustible como badge de color — nunca texto
/// plano entre paréntesis, y nunca condicionales repetidos: toda la
/// decisión de qué identificador mostrar vive en
/// `Vehiculo.etiquetaUnidad`/`etiquetaCompleta`.
///
/// `compacto` se usa para el estado "cerrado" del dropdown (vía
/// `selectedItemBuilder`): esa área tiene una altura fija de una sola
/// línea, así que ahí va todo en una sola línea de texto plano (sin
/// badge — una caja de color no cabe bien en un renglón tan angosto).
/// El menú abierto sí tiene espacio para dos líneas + badge.
class _OpcionVehiculo extends StatelessWidget {
  const _OpcionVehiculo({required this.vehiculo, this.compacto = false});

  final Vehiculo vehiculo;
  final bool compacto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final modelo = vehiculo.modelo ?? vehiculo.tipoUnidad;
    final identificador = vehiculo.etiquetaCompleta ?? vehiculo.etiquetaUnidad;

    if (compacto) {
      final combustibleTexto = vehiculo.tipoCombustible ?? 'Sin especificar';
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '$modelo · $identificador · $combustibleTexto',
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            modelo,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(
                  identificador,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.ibmPlexMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _BadgeCombustible(tipoCombustible: vehiculo.tipoCombustible),
            ],
          ),
        ],
      ),
    );
  }
}

/// Pill de color por tipo de combustible — mismo tratamiento visual que
/// `EstadoMantenimientoBadge`/`EstadoSolicitudBadge`. `null` (aún sin
/// confirmar con el cliente, ej. maquinaria recién importada) se
/// muestra como "Sin especificar" en gris neutro, nunca vacío ni "null".
class _BadgeCombustible extends StatelessWidget {
  const _BadgeCombustible({required this.tipoCombustible});

  final String? tipoCombustible;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (color, texto) = switch (tipoCombustible) {
      'Magna' => (colors.success, 'MAGNA'),
      'Diésel' => (colors.primary, 'DIÉSEL'),
      'Premium' => (colors.error, 'PREMIUM'),
      null => (colors.textMuted, 'SIN ESPECIFICAR'),
      final otro => (colors.textMuted, otro.toUpperCase()),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadii.badgeRadius,
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
