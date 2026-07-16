import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_theme.dart';

/// Tarjeta de progreso del tope semanal de un vehículo, reutilizada en el
/// inicio del chofer y en el detalle de chofer del panel administrativo.
class TarjetaTopeSemanal extends StatelessWidget {
  const TarjetaTopeSemanal({
    super.key,
    required this.tope,
    required this.usado,
    required this.disponible,
    required this.progreso,
  });

  final double tope;
  final double usado;
  final double disponible;
  final double progreso;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorBarra =
        progreso >= 0.9 ? colors.error : (progreso >= 0.7 ? colors.warning : colors.success);

    return Container(
      padding: const EdgeInsets.all(20),
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
                child: Text('Tope semanal', style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(
                tope > 0 ? '${disponible.toStringAsFixed(1)} L disponibles' : 'Sin asignar',
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(color: tope > 0 ? colorBarra : colors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progreso),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                value: tope > 0 ? value : 0,
                minHeight: 10,
                backgroundColor: colors.surfaceAlt,
                valueColor: AlwaysStoppedAnimation(colorBarra),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tope > 0
                ? '${usado.toStringAsFixed(1)} L usados de $tope L'
                : 'Pide a un administrativo que asigne el tope de tu vehículo.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
