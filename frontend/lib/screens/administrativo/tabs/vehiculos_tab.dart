import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/vehiculo.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/stat_tile.dart';
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
    final guardado = await EditarVehiculoDialog.show(context, vehiculo: vehiculo);
    if (guardado == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculos = ref.watch(vehiculosRepositoryProvider).todos;
    ref.watch(operacionesTickProvider);

    final sinTope = vehiculos.where((v) => v.esNuevaSinFormalizar).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
                    Text('Vehículos', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 4),
                    Text(
                      'Catálogo de vehículos y maquinaria de la obra, con su tope semanal.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colors.textSecondary),
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
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icono: Icons.local_shipping_outlined,
                  valor: '${vehiculos.length}',
                  etiqueta: 'Vehículos',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icono: Icons.warning_amber_outlined,
                  valor: '$sinTope',
                  etiqueta: 'Sin tope asignado',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (vehiculos.isEmpty)
            const EstadoVacio(
              icono: Icons.local_shipping_outlined,
              mensaje: 'Aún no hay vehículos registrados.',
            )
          else
            ...vehiculos.map((v) => _VehiculoTile(vehiculo: v, onEditar: () => _editar(v))),
        ],
      ),
    );
  }
}

class _VehiculoTile extends StatelessWidget {
  const _VehiculoTile({required this.vehiculo, required this.onEditar});

  final Vehiculo vehiculo;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final sinTope = vehiculo.esNuevaSinFormalizar;

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
          CircleAvatar(
            backgroundColor: colors.info.withValues(alpha: 0.12),
            child: Icon(Icons.local_shipping_outlined, color: colors.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${vehiculo.tipoUnidad} · ${vehiculo.identificador}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  vehiculo.tipoCombustible,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.textMuted),
                ),
                Text(
                  sinTope
                      ? 'Sin tope semanal asignado'
                      : 'Tope: ${vehiculo.topeSemanal.toStringAsFixed(0)} L/semana',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: sinTope ? colors.warning : colors.textSecondary),
                ),
              ],
            ),
          ),
          OutlinedButton(onPressed: onEditar, child: const Text('Editar')),
        ],
      ),
    );
  }
}
