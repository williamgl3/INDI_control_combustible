import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_screen_shell.dart';

/// Pantalla de bienvenida: primer punto de entrada de la app sin sesión.
/// Solo el logo/marca (ya en el header de [AuthScreenShell]) y dos
/// acciones — iniciar sesión o crear cuenta — nada de formularios aquí.
class BienvenidaScreen extends StatelessWidget {
  const BienvenidaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AuthScreenShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '¡Bienvenido!',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Controla la carga de combustible de tu flotilla en un solo lugar.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => context.go(RoutePaths.login),
            child: const Text('Iniciar sesión'),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.go(RoutePaths.registroChofer),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              side: BorderSide(color: colors.border),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Crear cuenta'),
          ),
        ],
      ),
    );
  }
}
