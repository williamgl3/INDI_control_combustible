import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import 'formato_numero.dart';

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
    final proporcion = total > 0
        ? (ejercido / total).clamp(0, 1).toDouble()
        : 0.0;
    final color = proporcion >= 0.9
        ? colors.error
        : (proporcion >= 0.7 ? colors.warning : colors.success);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: colors.border.withValues(alpha: 0.7)),
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
                    Text(
                      'PRESUPUESTO SEMANAL',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    if (etiquetaSemana != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 13,
                            color: colors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Semana del $etiquetaSemana',
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.textMuted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatearMoneda(restante),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    'Disponibles',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: AppRadii.badgeRadius,
            child: LinearProgressIndicator(
              value: proporcion,
              minHeight: 8,
              backgroundColor: colors.surfaceAlt,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${(proporcion * 100).toStringAsFixed(0)}% ejercido de ${formatearMoneda(total)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ),
    );
  }
}
