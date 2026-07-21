import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme_mode_provider.dart';
import 'app_dialog.dart';

/// Modal para elegir el tema de la app — claro, oscuro, o el que tenga
/// configurado el sistema operativo.
class SelectorTemaDialog extends ConsumerWidget {
  const SelectorTemaDialog({super.key});

  static Future<void> show(BuildContext context) {
    return mostrarDialogoApp<void>(
      context,
      builder: (_) => const SelectorTemaDialog(),
    );
  }

  static const _opciones = [
    (modo: ThemeMode.light, etiqueta: 'Claro', icono: Icons.light_mode_outlined),
    (modo: ThemeMode.dark, etiqueta: 'Oscuro', icono: Icons.dark_mode_outlined),
    (
      modo: ThemeMode.system,
      etiqueta: 'Predeterminado del sistema',
      icono: Icons.brightness_auto_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actual = ref.watch(themeModeProvider);

    return AppDialogShell(
      maxWidth: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Tema', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          RadioGroup<ThemeMode>(
            groupValue: actual,
            onChanged: (modo) {
              if (modo == null) return;
              ref.read(themeModeProvider.notifier).cambiar(modo);
              Navigator.of(context).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final opcion in _opciones)
                  RadioListTile<ThemeMode>(
                    contentPadding: EdgeInsets.zero,
                    value: opcion.modo,
                    title: Row(
                      children: [
                        Icon(opcion.icono, size: 20),
                        const SizedBox(width: 12),
                        Text(opcion.etiqueta),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
