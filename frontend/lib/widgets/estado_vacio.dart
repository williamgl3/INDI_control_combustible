import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Mensaje centrado para listas/tablas sin datos, reutilizado en varias
/// pestañas del panel administrativo y pantallas de chofer.
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({super.key, required this.mensaje, this.icono});

  final String mensaje;
  final IconData? icono;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Column(
        children: [
          if (icono != null) ...[
            Icon(icono, size: 36, color: colors.textMuted),
            const SizedBox(height: 12),
          ],
          Text(mensaje,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textMuted)),
        ],
      ),
    );
  }
}
