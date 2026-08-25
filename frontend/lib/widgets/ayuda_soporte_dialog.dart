import 'package:flutter/material.dart';

import 'app_dialog.dart';

/// Ayuda/soporte — muestra el canal oficial de soporte de INDI Combustible.
class AyudaSoporteDialog extends StatelessWidget {
  const AyudaSoporteDialog({super.key});

  static const _correoSoporte = 'soporte@indicombustible.com';

  static Future<void> show(BuildContext context) {
    return mostrarDialogoApp<void>(
      context,
      builder: (_) => const AyudaSoporteDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppDialogShell(
      maxWidth: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Ayuda y soporte',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          const Text(
            'Si tienes un problema con la app o con una solicitud, '
            'escríbenos a:',
          ),
          const SizedBox(height: 8),
          Text(
            _correoSoporte,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}
