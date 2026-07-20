import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_theme.dart';

/// Input numérico grande con botones +/- y la opción de escribir el valor
/// exacto tocándolo — pensado para capturar litros/kilómetros en campo
/// (con guantes, sin querer teclear en un formulario chico).
class StepperNumerico extends StatelessWidget {
  const StepperNumerico({
    super.key,
    required this.etiqueta,
    required this.valor,
    required this.onChanged,
    this.sufijo = '',
    this.paso = 1,
    this.decimales = 0,
    this.minimo = 0,
  });

  final String etiqueta;
  final double valor;
  final ValueChanged<double> onChanged;
  final String sufijo;
  final double paso;
  final int decimales;
  final double minimo;

  Future<void> _editarManualmente(BuildContext context) async {
    final controller = TextEditingController(
      text: valor.toStringAsFixed(decimales),
    );
    final nuevoValor = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(etiqueta),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.numberWithOptions(decimal: decimales > 0),
          decoration: InputDecoration(suffixText: sufijo),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final parseado = double.tryParse(controller.text.trim());
              Navigator.of(context).pop(parseado);
            },
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    if (nuevoValor != null && nuevoValor >= minimo) {
      onChanged(nuevoValor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            etiqueta.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _BotonPaso(
                icono: Icons.remove,
                onTap: () =>
                    onChanged((valor - paso).clamp(minimo, double.infinity)),
              ),
              Expanded(
                child: GestureDetector(
                  key: Key('stepper-valor-$etiqueta'),
                  onTap: () => _editarManualmente(context),
                  child: Column(
                    children: [
                      Text(
                        valor.toStringAsFixed(decimales),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      Text(
                        sufijo.isEmpty
                            ? 'toca para escribir'
                            : '$sufijo · toca para escribir',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _BotonPaso(
                icono: Icons.add,
                onTap: () => onChanged(valor + paso),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BotonPaso extends StatelessWidget {
  const _BotonPaso({required this.icono, required this.onTap});

  final IconData icono;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surfaceAlt,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        hoverColor: colors.primary.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(icono, color: colors.primary),
        ),
      ),
    );
  }
}
