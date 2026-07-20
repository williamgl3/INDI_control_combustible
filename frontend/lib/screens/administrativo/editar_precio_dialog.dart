import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/api_client.dart';
import '../../models/precio_combustible.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_dialog.dart';

/// Modal para que un administrativo actualice el precio por litro de un
/// tipo de combustible del catálogo.
class EditarPrecioDialog extends ConsumerStatefulWidget {
  const EditarPrecioDialog({super.key, required this.precio});

  final PrecioCombustible precio;

  static Future<bool?> show(BuildContext context, PrecioCombustible precio) {
    return mostrarDialogoApp<bool>(
      context,
      builder: (_) => EditarPrecioDialog(precio: precio),
    );
  }

  @override
  ConsumerState<EditarPrecioDialog> createState() => _EditarPrecioDialogState();
}

class _EditarPrecioDialogState extends ConsumerState<EditarPrecioDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _precioController = TextEditingController(
    text: widget.precio.precioPorLitro.toStringAsFixed(2),
  );

  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _precioController.dispose();
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
          .actualizarPrecio(
            tipoCombustible: widget.precio.tipoCombustible,
            nuevoPrecio: double.parse(_precioController.text.trim()),
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
    final colors = context.colors;

    return AppDialogShell(
      maxWidth: 380,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.precio.tipoCombustible,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _precioController,
              decoration: const InputDecoration(
                labelText: 'Precio por litro',
                prefixText: '\$ ',
                prefixIcon: Icon(Icons.sell_outlined),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              validator: (v) {
                final valor = v?.trim() ?? '';
                if (valor.isEmpty) return 'Ingresa el precio por litro.';
                final n = double.tryParse(valor);
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
                        : const Text('Guardar precio'),
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
