import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/vehiculo.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/responsive_scroll_view.dart';
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
  Future<void> _agregar() async {
    final guardado = await EditarVehiculoDialog.show(context);
    if (guardado == true && mounted) setState(() {});
  }

  Future<void> _editar(Vehiculo vehiculo) async {
    final guardado = await EditarVehiculoDialog.show(
      context,
      vehiculo: vehiculo,
    );
    if (guardado == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculos = ref.watch(vehiculosRepositoryProvider).todos;
    ref.watch(operacionesTickProvider);

    final sinTope = vehiculos.where((v) => v.esNuevaSinFormalizar).length;

    return ResponsiveScrollView(
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
                      'Catálogo de vehículos y maquinaria de la obra, con su tope semanal.',
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
              StatTile(
                icono: Icons.warning_amber_outlined,
                valor: '$sinTope',
                etiqueta: 'Sin tope asignado',
                color: colors.warning,
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (vehiculos.isEmpty)
            EstadoVacio(
              icono: Icons.local_shipping_outlined,
              mensaje: 'Aún no hay vehículos registrados.',
              textoAccion: 'Agregar vehículo',
              onAccion: _agregar,
            )
          else
            GroupedSection(
              header: 'Catálogo',
              children: [
                for (final v in vehiculos)
                  GroupedRow(
                    titulo: '${v.tipoUnidad} · ${v.identificador}',
                    subtitulo: v.esNuevaSinFormalizar
                        ? '${v.tipoCombustible} · Sin tope asignado'
                        : '${v.tipoCombustible} · Tope: ${v.topeSemanal.toStringAsFixed(0)} L/semana',
                    icono: Icons.local_shipping_outlined,
                    iconoColor: AppSectionColors.vehiculos,
                    trailing: OutlinedButton(
                      onPressed: () => _editar(v),
                      child: const Text('Editar'),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
