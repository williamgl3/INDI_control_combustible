import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../data/api_client.dart';
import '../../../models/vehiculo.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/confirmar_accion_dialog.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/stat_tile.dart';
import '../../../widgets/stat_tile_row.dart';
import '../editar_vehiculo_dialog.dart';

/// Pestaña "Vehículos": catálogo compartido de la obra, administrado por
/// el personal administrativo (no cada chofer) — un chofer elige de aquí
/// qué unidad usa en cada solicitud/comprobación de carga, ya que varios
/// choferes pueden compartir o rotar de vehículo.
class VehiculosTab extends ConsumerStatefulWidget {
  const VehiculosTab({super.key});

  @override
  ConsumerState<VehiculosTab> createState() => _VehiculosTabState();
}

class _VehiculosTabState extends ConsumerState<VehiculosTab> {
  final _busquedaController = TextEditingController();
  String _busqueda = '';
  String? _accionEnCurso;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _agregar() async {
    final guardado = await EditarVehiculoDialog.show(context);
    if (guardado == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehículo agregado correctamente.')),
      );
    }
  }

  Future<void> _editar(Vehiculo vehiculo) async {
    final guardado = await EditarVehiculoDialog.show(
      context,
      vehiculo: vehiculo,
    );
    if (guardado == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vehículo actualizado correctamente.')),
      );
    }
  }

  Future<void> _cambiarEstado(Vehiculo vehiculo) async {
    final activar = !vehiculo.activo;
    final confirmado = await ConfirmarAccionDialog.show(
      context,
      titulo: activar ? 'Reactivar vehículo' : 'Desactivar vehículo',
      mensaje: activar
          ? '¿Reactivar ${vehiculo.tipoUnidad} · ${vehiculo.etiquetaUnidad}? '
                'Volverá a aparecer en el selector del chofer.'
          : '¿Desactivar ${vehiculo.tipoUnidad} · ${vehiculo.etiquetaUnidad}? '
                'Dejará de aparecer en el selector del chofer, pero conserva '
                'su historial de solicitudes y cargas.',
      textoConfirmar: activar ? 'Reactivar' : 'Desactivar',
      destructivo: !activar,
    );
    if (!confirmado) return;

    setState(() => _accionEnCurso = vehiculo.id);
    try {
      await ref
          .read(vehiculosRepositoryProvider)
          .cambiarEstado(id: vehiculo.id, activo: activar);
      ref.read(operacionesTickProvider.notifier).state++;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activar
                  ? 'Vehículo reactivado correctamente.'
                  : 'Vehículo desactivado correctamente.',
            ),
          ),
        );
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _accionEnCurso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculos = ref.watch(vehiculosRepositoryProvider).todos;
    ref.watch(operacionesTickProvider);

    final busqueda = _busqueda.trim().toLowerCase();
    final vehiculosFiltrados = busqueda.isEmpty
        ? vehiculos
        : vehiculos
              .where(
                (v) =>
                    (v.placas?.toLowerCase().contains(busqueda) ?? false) ||
                    (v.numeroEconomico?.toLowerCase().contains(busqueda) ??
                        false) ||
                    v.tipoUnidad.toLowerCase().contains(busqueda) ||
                    (v.tipoCombustible?.toLowerCase().contains(busqueda) ??
                        false) ||
                    (v.modelo?.toLowerCase().contains(busqueda) ?? false),
              )
              .toList();

    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehículos',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Catálogo de vehículos y maquinaria de la obra.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _agregar,
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          StatTileRow(
            tiles: [
              StatTile(
                icono: Icons.local_shipping_outlined,
                valor: '${vehiculos.length}',
                etiqueta: 'Vehículos',
                color: AppSectionColors.vehiculos,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (vehiculos.isNotEmpty)
            TextField(
              controller: _busquedaController,
              decoration: const InputDecoration(
                labelText: 'Buscar por identificador, tipo o combustible',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          if (vehiculos.isNotEmpty) const SizedBox(height: 16),
          if (vehiculos.isEmpty)
            EstadoVacio(
              icono: Icons.local_shipping_outlined,
              mensaje: 'Aún no hay vehículos registrados.',
              textoAccion: 'Agregar vehículo',
              onAccion: _agregar,
            )
          else if (vehiculosFiltrados.isEmpty)
            const EstadoVacio(
              icono: Icons.search_off_outlined,
              mensaje: 'Ningún vehículo coincide con esa búsqueda.',
            )
          else
            GroupedSection(
              header: 'Catálogo',
              children: [
                for (final v in vehiculosFiltrados)
                  GroupedRow(
                    titulo: v.modelo ?? v.tipoUnidad,
                    subtitulo:
                        '${v.tipoUnidad} · ${v.etiquetaCompleta ?? v.etiquetaUnidad} · '
                        '${v.tipoCombustible ?? 'Sin especificar'}',
                    icono: Icons.local_shipping_outlined,
                    iconoColor: AppSectionColors.vehiculos,
                    trailing: _accionEnCurso == v.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!v.activo) ...[
                                _BadgeInactivo(),
                                const SizedBox(width: 8),
                              ],
                              OutlinedButton(
                                onPressed: () => _editar(v),
                                child: const Text('Editar'),
                              ),
                              const SizedBox(width: 8),
                              PopupMenuButton<void>(
                                tooltip: 'Más acciones',
                                icon: const Icon(Icons.more_vert),
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    onTap: () => _cambiarEstado(v),
                                    child: Text(
                                      v.activo ? 'Desactivar' : 'Reactivar',
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Mismo estilo que el badge de usuario inactivo (`choferes_tab.dart`).
class _BadgeInactivo extends StatelessWidget {
  const _BadgeInactivo();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.14),
        borderRadius: AppRadii.badgeRadius,
      ),
      child: Text(
        'INACTIVO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.error,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
