import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/mock_auth_repository.dart';
import '../../models/perfil.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';

/// Modal para que un administrativo asigne/actualice el tope semanal del
/// vehículo de un chofer (no se captura en /registro-chofer).
class EditarChoferDialog extends ConsumerStatefulWidget {
  const EditarChoferDialog({super.key, required this.chofer});

  final Perfil chofer;

  static Future<bool?> show(BuildContext context, Perfil chofer) {
    return showDialog<bool>(
      context: context,
      builder: (_) => EditarChoferDialog(chofer: chofer),
    );
  }

  @override
  ConsumerState<EditarChoferDialog> createState() => _EditarChoferDialogState();
}

class _EditarChoferDialogState extends ConsumerState<EditarChoferDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _topeController = TextEditingController(
    text: widget.chofer.vehiculo!.topeSemanal > 0
        ? widget.chofer.vehiculo!.topeSemanal.toStringAsFixed(0)
        : '',
  );

  bool _cargando = false;
  String? _errorGeneral;

  @override
  void dispose() {
    _topeController.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _cargando = true;
      _errorGeneral = null;
    });

    try {
      await ref.read(authRepositoryProvider).actualizarTopeSemanal(
            usuario: widget.chofer.usuario,
            nuevoTope: double.parse(_topeController.text.trim()),
          );
      if (mounted) Navigator.of(context).pop(true);
    } on AuthException catch (e) {
      setState(() => _errorGeneral = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculo = widget.chofer.vehiculo!;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(widget.chofer.nombreCompleto,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${vehiculo.tipoUnidad} · ${vehiculo.placaONumeroEconomico} · '
                  '${vehiculo.tipoCombustible}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _topeController,
                  decoration: const InputDecoration(
                    labelText: 'Tope semanal',
                    suffixText: 'L',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  autofocus: true,
                  validator: (v) {
                    final valor = v?.trim() ?? '';
                    if (valor.isEmpty) return 'Ingresa el tope semanal.';
                    final n = double.tryParse(valor);
                    if (n == null || n <= 0) return 'Ingresa un número válido mayor a 0.';
                    return null;
                  },
                  onFieldSubmitted: (_) => _guardar(),
                ),
                if (_errorGeneral != null) ...[
                  const SizedBox(height: 12),
                  Text(_errorGeneral!, style: TextStyle(color: colors.error)),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _cargando ? null : () => Navigator.of(context).pop(false),
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
        ),
      ),
    );
  }
}
