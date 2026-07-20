import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/providers.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// El chofer reporta sobre la marcha una unidad que no está en el
/// catálogo (ej. una unidad recién llegada a la obra). Queda sin tope
/// asignado hasta que un administrativo la formalice — ver
/// `MockVehiculosRepository.reportarNuevo`.
class ReportarVehiculoNuevoDialog extends ConsumerStatefulWidget {
  const ReportarVehiculoNuevoDialog({super.key});

  static Future<Vehiculo?> show(BuildContext context) {
    return mostrarDialogoApp<Vehiculo>(
      context,
      builder: (_) => const ReportarVehiculoNuevoDialog(),
    );
  }

  @override
  ConsumerState<ReportarVehiculoNuevoDialog> createState() =>
      _ReportarVehiculoNuevoDialogState();
}

class _ReportarVehiculoNuevoDialogState
    extends ConsumerState<ReportarVehiculoNuevoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _identificadorController = TextEditingController();

  String _tipoUnidad = tiposUnidadVehiculo.first;
  String _tipoCombustible = tiposCombustibleVehiculo.first;
  bool _cargando = false;

  @override
  void dispose() {
    _identificadorController.dispose();
    super.dispose();
  }

  Future<void> _reportar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _cargando = true);
    final vehiculo = await ref
        .read(vehiculosRepositoryProvider)
        .reportarNuevo(
          tipoUnidad: _tipoUnidad,
          identificador: _identificadorController.text.trim(),
          tipoCombustible: _tipoCombustible,
        );
    ref.read(operacionesTickProvider.notifier).state++;
    if (mounted) Navigator.of(context).pop(vehiculo);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialogShell(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Vehículo nuevo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Repórtalo y ya puedes seguir — un administrativo le asignará su '
              'tope semanal después.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _tipoUnidad,
              decoration: const InputDecoration(
                labelText: 'Tipo de unidad',
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
              items: tiposUnidadVehiculo
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipoUnidad = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _identificadorController,
              decoration: const InputDecoration(
                labelText: 'Placas, número económico o descripción',
                hintText: 'Ej. ABC-123, EC-45, o "Retroexcavadora amarilla"',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'Este dato es obligatorio.'
                  : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _tipoCombustible,
              decoration: const InputDecoration(
                labelText: 'Tipo de combustible',
                prefixIcon: Icon(Icons.local_gas_station_outlined),
              ),
              items: tiposCombustibleVehiculo
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipoCombustible = v!),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _reportar,
                    child: _cargando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Reportar y usar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
