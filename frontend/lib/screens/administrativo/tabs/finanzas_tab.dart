import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/precio_combustible.dart';
import '../../../models/solicitud_autorizacion.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/barra_presupuesto.dart';
import '../../../widgets/stat_tile.dart';
import '../editar_precio_dialog.dart';

/// Pestaña "Finanzas": presupuesto semanal y precios de combustible
/// vigentes (editables).
class FinanzasTab extends ConsumerStatefulWidget {
  const FinanzasTab({super.key});

  @override
  ConsumerState<FinanzasTab> createState() => _FinanzasTabState();
}

class _FinanzasTabState extends ConsumerState<FinanzasTab> {
  Future<void> _editarPrecio(PrecioCombustible precio) async {
    final guardado = await EditarPrecioDialog.show(context, precio);
    if (guardado == true && mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final aprobadas = repo.todasLasSolicitudes.where((s) => s.estado == EstadoSolicitud.aprobada);
    final litrosAutorizados =
        aprobadas.fold(0.0, (suma, s) => suma + (s.litrosAutorizados ?? s.litrosSolicitados));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Finanzas', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text('Presupuesto semanal y precios de combustible vigentes.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
          const SizedBox(height: 20),
          BarraPresupuesto(
            restante: repo.presupuestoRestante,
            total: repo.presupuestoSemanalTotal,
            etiquetaSemana: repo.etiquetaSemanaActual,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  icono: Icons.local_gas_station_outlined,
                  valor: litrosAutorizados.toStringAsFixed(0),
                  etiqueta: 'L autorizados',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: StatTile(
                  icono: Icons.payments_outlined,
                  valor: '\$${repo.presupuestoEjercido.toStringAsFixed(0)}',
                  etiqueta: 'Ejercido esta semana',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Precios de combustible', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...repo.precios.map((p) => _PrecioTile(precio: p, onEditar: () => _editarPrecio(p))),
        ],
      ),
    );
  }
}

class _PrecioTile extends StatelessWidget {
  const _PrecioTile({required this.precio, required this.onEditar});

  final PrecioCombustible precio;
  final VoidCallback onEditar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: AppRadii.cardRadius,
      ),
      child: Row(
        children: [
          Icon(Icons.local_gas_station, color: colors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(precio.tipoCombustible, style: Theme.of(context).textTheme.titleSmall),
          ),
          Text('\$${precio.precioPorLitro.toStringAsFixed(2)} / L',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: colors.primary)),
          IconButton(
            tooltip: 'Editar precio',
            onPressed: onEditar,
            icon: Icon(Icons.edit_outlined, color: colors.textSecondary, size: 20),
          ),
        ],
      ),
    );
  }
}
