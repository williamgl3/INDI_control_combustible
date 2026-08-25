import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/validators.dart';
import '../../data/api_client.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// Modal para editar el presupuesto semanal total (Finanzas) — antes era
/// una `CeldaEditable` en el lugar, sin ningún ícono que indicara que el
/// monto era interactivo (solo un subtítulo de texto). Mismo patrón
/// `AppDialogShell` que el resto de los diálogos del panel admin
/// (`EditarVehiculoDialog`, `RegistrarServicioDialog`, etc.).
class EditarPresupuestoDialog extends ConsumerStatefulWidget {
  const EditarPresupuestoDialog({super.key, required this.valorActual});

  final double valorActual;

  static Future<bool?> show(
    BuildContext context, {
    required double valorActual,
  }) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => EditarPresupuestoDialog(valorActual: valorActual),
    );
  }

  @override
  ConsumerState<EditarPresupuestoDialog> createState() =>
      _EditarPresupuestoDialogState();
}

class _EditarPresupuestoDialogState
    extends ConsumerState<EditarPresupuestoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _montoController = TextEditingController(
    text: widget.valorActual.toStringAsFixed(0),
  );

  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _montoController.dispose();
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
          .read(operacionesRepositoryProvider)
          .actualizarPresupuestoSemanalTotal(
            double.parse(_montoController.text.trim()),
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
    return AppDialogShell(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Editar presupuesto semanal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Monto disponible para combustible cada semana (lunes a domingo).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _montoController,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Presupuesto semanal',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (v) =>
                  Validators.numeroPositivo(v, etiqueta: 'El presupuesto'),
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
