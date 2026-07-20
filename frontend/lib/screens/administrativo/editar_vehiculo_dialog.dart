import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/providers.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// Modal para que un administrativo dé de alta un vehículo en el catálogo
/// compartido, o edite uno existente (tope semanal, identificador, tipo).
/// Si [vehiculo] es `null` se trata de un alta nueva.
class EditarVehiculoDialog extends ConsumerStatefulWidget {
  const EditarVehiculoDialog({super.key, this.vehiculo});

  final Vehiculo? vehiculo;

  static Future<bool?> show(BuildContext context, {Vehiculo? vehiculo}) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => EditarVehiculoDialog(vehiculo: vehiculo),
    );
  }

  @override
  ConsumerState<EditarVehiculoDialog> createState() =>
      _EditarVehiculoDialogState();
}

class _EditarVehiculoDialogState extends ConsumerState<EditarVehiculoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _identificadorController = TextEditingController(
    text: widget.vehiculo?.identificador ?? '',
  );
  late final _topeController = TextEditingController(
    text: (widget.vehiculo != null && widget.vehiculo!.topeSemanal > 0)
        ? widget.vehiculo!.topeSemanal.toStringAsFixed(0)
        : '',
  );
  late final _intervaloController = TextEditingController(
    text:
        (widget.vehiculo?.intervaloServicio ??
                intervaloServicioPorDefecto(
                  widget.vehiculo?.tipoUnidad ?? tiposUnidadVehiculo.first,
                ))
            .toStringAsFixed(0),
  );

  late String _tipoUnidad =
      widget.vehiculo?.tipoUnidad ?? tiposUnidadVehiculo.first;
  late String _tipoCombustible =
      widget.vehiculo?.tipoCombustible ?? tiposCombustibleVehiculo.first;
  bool _cargando = false;
  String? _errorGeneral;

  bool get _esAlta => widget.vehiculo == null;

  @override
  void dispose() {
    _identificadorController.dispose();
    _topeController.dispose();
    _intervaloController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      final repo = ref.read(vehiculosRepositoryProvider);
      final tope = double.tryParse(_topeController.text.trim()) ?? 0;
      final intervalo =
          double.tryParse(_intervaloController.text.trim()) ??
          intervaloServicioPorDefecto(_tipoUnidad);
      if (_esAlta) {
        await repo.crear(
          tipoUnidad: _tipoUnidad,
          identificador: _identificadorController.text.trim(),
          tipoCombustible: _tipoCombustible,
          topeSemanal: tope,
          intervaloServicio: intervalo,
        );
      } else {
        await repo.actualizar(
          id: widget.vehiculo!.id,
          tipoUnidad: _tipoUnidad,
          identificador: _identificadorController.text.trim(),
          tipoCombustible: _tipoCombustible,
          topeSemanal: tope,
          intervaloServicio: intervalo,
        );
      }
      ref.read(operacionesTickProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
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
              _esAlta ? 'Agregar vehículo' : 'Editar vehículo',
              style: Theme.of(context).textTheme.titleLarge,
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _topeController,
              decoration: const InputDecoration(
                labelText: 'Tope semanal (déjalo vacío si aún no se asigna)',
                suffixText: 'L',
                prefixIcon: Icon(Icons.speed_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final valor = v?.trim() ?? '';
                if (valor.isEmpty) return null;
                final n = double.tryParse(valor);
                if (n == null || n <= 0) {
                  return 'Ingresa un número válido mayor a 0.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _guardar(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _intervaloController,
              decoration: InputDecoration(
                labelText: 'Intervalo de servicio general mecánico',
                suffixText: esUnidadPorHorometro(_tipoUnidad) ? 'horas' : 'km',
                prefixIcon: const Icon(Icons.build_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) {
                  return 'Ingresa un número válido mayor a 0.';
                }
                return null;
              },
              onFieldSubmitted: (_) => _guardar(),
            ),
            if (_errorGeneral != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorGeneral!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.error),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _cargando
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cargando ? null : _guardar,
                    child: _cargando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _esAlta ? 'Agregar vehículo' : 'Guardar vehículo',
                          ),
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
