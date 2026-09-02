import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Etiqueta discreta en mayúsculas sobre un grupo de contenido (ej. una
/// fecha agrupando varias tarjetas) — mismo estilo que usaba el `header`
/// de [GroupedSection], para no perderlo al pasar de una lista agrupada
/// (un solo rectángulo) a tarjetas individuales flotantes.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: context.colors.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
