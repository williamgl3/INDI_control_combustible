import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Chip de selección única para filtros (estado de solicitud, periodo del
/// concentrado, etc.), reutilizado en varias pantallas del panel admin.
class ChipFiltro extends StatelessWidget {
  const ChipFiltro({
    super.key,
    required this.etiqueta,
    required this.seleccionado,
    required this.onTap,
  });

  final String etiqueta;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ChoiceChip(
      label: Text(etiqueta),
      selected: seleccionado,
      onSelected: (_) => onTap(),
      selectedColor: colors.primary.withValues(alpha: 0.15),
      labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
        color: seleccionado ? colors.primary : colors.textSecondary,
      ),
      side: BorderSide(color: seleccionado ? colors.primary : colors.border),
      backgroundColor: colors.surface,
      showCheckmark: false,
    );
  }
}
