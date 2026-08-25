import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/catalogos_vehiculo.dart';
import '../../core/providers.dart';
import '../../data/api_client.dart';
import '../../models/vehiculo.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// Modal para que un administrativo registre que se realizó el servicio
/// general mecánico de una unidad, con la lectura del medidor en ese
/// momento.
class RegistrarServicioDialog extends ConsumerStatefulWidget {
  const RegistrarServicioDialog({
    super.key,
    required this.vehiculo,
    this.lecturaActualSugerida,
  });

  final Vehiculo vehiculo;
  final double? lecturaActualSugerida;

  static Future<bool?> show(
    BuildContext context, {
    required Vehiculo vehiculo,
    double? lecturaActualSugerida,
  }) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => RegistrarServicioDialog(
        vehiculo: vehiculo,
        lecturaActualSugerida: lecturaActualSugerida,
      ),
    );
  }

  @override
  ConsumerState<RegistrarServicioDialog> createState() =>
      _RegistrarServicioDialogState();
}

class _RegistrarServicioDialogState
    extends ConsumerState<RegistrarServicioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _lecturaController = TextEditingController(
    text: widget.lecturaActualSugerida?.toStringAsFixed(0) ?? '',
  );

  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _lecturaController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });
    try {
      await ref
          .read(vehiculosRepositoryProvider)
          .registrarServicio(
            id: widget.vehiculo.id,
            lectura: double.parse(_lecturaController.text.trim()),
            fecha: DateTime.now(),
          );
      ref.read(operacionesTickProvider.notifier).state++;
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final porHorometro = esUnidadPorHorometro(widget.vehiculo.tipoUnidad);
    final unidad = porHorometro ? 'horas' : 'km';

    return AppDialogShell(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar servicio',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.vehiculo.tipoUnidad} · ${widget.vehiculo.etiquetaUnidad}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _lecturaController,
              decoration: InputDecoration(
                labelText: porHorometro
                    ? 'Horómetro al momento del servicio'
                    : 'Km al momento del servicio',
                suffixText: unidad,
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
                ).textTheme.bodySmall?.copyWith(color: context.colors.error),
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
                        : const Text('Guardar'),
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
