import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Control segmentado nativo de iOS (`UISegmentedControl`) para filtros de
/// pocas opciones mutuamente excluyentes (periodo, estado) — reemplaza el
/// `Wrap` de `ChipFiltro` de la dirección visual anterior.
///
/// En teléfonos angostos (~320-360px) con 5 opciones (ej. el filtro de
/// Mantenimiento), el control de Cupertino no hace wrap ni se encoge más
/// allá del ancho natural de su texto — así que se envuelve en scroll
/// horizontal como red de seguridad: si todo cabe, se ve idéntico (llena
/// el ancho disponible); si no cabe, se desliza en vez de desbordar.
class IosSegmentedControl<T extends Object> extends StatelessWidget {
  const IosSegmentedControl({
    super.key,
    required this.opciones,
    required this.valor,
    required this.onChanged,
  });

  final Map<T, String> opciones;
  final T valor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estilo = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary);

    final control = Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: colors.surfaceAlt,
        borderRadius: AppRadii.inputRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entrada in opciones.entries)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: ChoiceChip(
                label: Text(entrada.value, softWrap: false),
                selected: entrada.key == valor,
                onSelected: (_) => onChanged(entrada.key),
                selectedColor: colors.primary,
                backgroundColor: Colors.transparent,
                side: BorderSide.none,
                showCheckmark: false,
                labelStyle: estilo?.copyWith(
                  color: entrada.key == valor
                      ? colors.primaryOn
                      : colors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth),
          child: control,
        ),
      ),
    );
  }
}
