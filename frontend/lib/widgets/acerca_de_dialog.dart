import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_dialog.dart';
import 'logo_glass.dart';

/// "Acerca de" — versión tomada de `pubspec.yaml` a mano (el proyecto no
/// tiene `package_info_plus` como dependencia todavía; si se agrega más
/// adelante, reemplazar este valor fijo por `PackageInfo.fromPlatform()`).
class AcercaDeDialog extends StatelessWidget {
  const AcercaDeDialog({super.key});

  static const _version = '1.0.0';

  static Future<void> show(BuildContext context) {
    return mostrarDialogoApp<void>(
      context,
      builder: (_) => const AcercaDeDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialogShell(
      maxWidth: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LogoGlass(size: 56),
          const SizedBox(height: 16),
          Text(
            'INDI Combustible',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            'Versión $_version',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
          const SizedBox(height: 20),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
