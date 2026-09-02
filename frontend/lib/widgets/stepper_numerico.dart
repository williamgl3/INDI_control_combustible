import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import 'pressable_scale.dart';

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
    this.referenciaMaxima,
    this.referenciaEtiqueta,
  });

  final String etiqueta;
  final double valor;
  final ValueChanged<double> onChanged;
  final String sufijo;
  final double paso;
  final int decimales;
  final double minimo;

  /// Referencia (ej. tope semanal del vehículo elegido) para dibujar una
  /// barra de proporción bajo el contador — se omite si no aplica (sin
  /// vehículo elegido todavía, o sin tope asignado).
  final double? referenciaMaxima;

  /// Texto bajo la barra de referencia (ej. "de tu tope semanal: 350 L").
  final String? referenciaEtiqueta;

  Future<void> _editarManualmente(BuildContext context) async {
    // En blanco cuando el valor sigue en su default (0) — no es común
    // que se necesiten decimales, así que forzar a borrar "0.0" antes de
    // poder escribir el número de verdad solo hace más lento un registro
    // que debería ser rápido. Si ya hay un valor real cargado (se está
    // corrigiendo, no capturando por primera vez), sí se precarga para
    // editarlo en vez de tener que volver a escribirlo entero.
    final controller = TextEditingController(
      text: valor == 0 ? '' : valor.toStringAsFixed(decimales),
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
    final maxRef = referenciaMaxima;
    final mostrarReferencia = maxRef != null && maxRef > 0;
    final progreso = mostrarReferencia
        ? (valor / maxRef).clamp(0, 1).toDouble()
        : 0.0;

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
                      // Protagonista de la pantalla (es la acción principal
                      // del formulario): número grande en el azul de marca
                      // en vez del negro por defecto de un `headline`.
                      Text(
                        valor.toStringAsFixed(decimales),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displayMedium
                            ?.copyWith(color: colors.primary),
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
          if (mostrarReferencia) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: AppRadii.badgeRadius,
              child: SizedBox(
                height: 6,
                child: Stack(
                  children: [
                    Container(color: colors.surfaceAlt),
                    AnimatedFractionallySizedBox(
                      duration: AppMotion.base,
                      curve: AppMotion.curve,
                      widthFactor: progreso,
                      child: Container(
                        color: progreso >= 1 ? colors.warning : colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (referenciaEtiqueta != null) ...[
              const SizedBox(height: 6),
              Text(
                referenciaEtiqueta!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          ],
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
    return PressableScale(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: context.shadows.card,
        ),
        child: Material(
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
        ),
      ),
    );
  }
}
