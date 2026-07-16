import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_theme.dart';

/// Tarjeta compacta de una métrica (ícono + valor + etiqueta), reutilizada
/// en las pestañas del panel administrativo.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.icono, required this.valor, required this.etiqueta});

  final IconData icono;
  final String valor;
  final String etiqueta;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        boxShadow: context.shadows.card,
      ),
      child: Column(
        children: [
          Icon(icono, color: colors.primary),
          const SizedBox(height: 8),
          Text(valor, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 2),
          Text(etiqueta,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
