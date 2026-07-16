import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/perfil.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/stat_tile.dart';
import '../editar_chofer_dialog.dart';

/// Pestaña "Vehículos": un vehículo/maquinaria por chofer (no hay
/// catálogo separado — cada chofer registra el suyo), con acceso directo
/// a editar su tope semanal.
class VehiculosTab extends ConsumerStatefulWidget {
  const VehiculosTab({super.key});

  @override
  ConsumerState<VehiculosTab> createState() => _VehiculosTabState();
}

class _VehiculosTabState extends ConsumerState<VehiculosTab> {
  Future<void> _editarTope(Perfil chofer) async {
    final guardado = await EditarChoferDialog.show(context, chofer);
    if (guardado == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final choferes = ref.watch(authRepositoryProvider).listarChoferes();
    ref.watch(operacionesTickProvider);

    final sinTope = choferes.where((c) => (c.vehiculo?.topeSemanal ?? 0) <= 0).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Vehículos', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Un vehículo o maquinaria por chofer, con su tope semanal en litros.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icono: Icons.local_shipping_outlined,
                  valor: '${choferes.length}',
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
          if (choferes.isEmpty)
            const EstadoVacio(
              icono: Icons.local_shipping_outlined,
              mensaje: 'Aún no hay vehículos registrados.',
            )
          else
            ...choferes.map((c) => _VehiculoTile(chofer: c, onEditar: () => _editarTope(c))),
        ],
      ),
    );
  }
}

class _VehiculoTile extends StatelessWidget {
  const _VehiculoTile({required this.chofer, required this.onEditar});

  final Perfil chofer;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculo = chofer.vehiculo!;
    final sinTope = vehiculo.topeSemanal <= 0;

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
                  '${vehiculo.tipoUnidad} · ${vehiculo.placaONumeroEconomico}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${vehiculo.tipoCombustible} · Responsable: ${chofer.nombreCompleto}',
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
          OutlinedButton(onPressed: onEditar, child: const Text('Editar tope')),
        ],
      ),
    );
  }
}
