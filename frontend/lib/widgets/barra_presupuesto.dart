import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_theme.dart';

/// Barra de progreso del presupuesto semanal en pesos, reutilizada en las
/// pestañas Autorizaciones y Finanzas del panel administrativo.
class BarraPresupuesto extends StatelessWidget {
  const BarraPresupuesto({
    super.key,
    required this.restante,
    required this.total,
    this.etiquetaSemana,
  });

  final double restante;
  final double total;

  /// Ej. "15 al 21 jul" — a qué semana corresponde este presupuesto.
  final String? etiquetaSemana;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ejercido = total - restante;
    final proporcion = total > 0 ? (ejercido / total).clamp(0, 1).toDouble() : 0.0;
    final color =
        proporcion >= 0.9 ? colors.error : (proporcion >= 0.7 ? colors.warning : colors.success);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: context.shadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Presupuesto semanal',
                        style: Theme.of(context).textTheme.titleMedium),
                    if (etiquetaSemana != null)
                      Text('Semana del $etiquetaSemana',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
              Text('\$${restante.toStringAsFixed(0)} restantes',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: proporcion,
              minHeight: 8,
              backgroundColor: colors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(proporcion * 100).toStringAsFixed(0)}% ejercido de \$${total.toStringAsFixed(0)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
