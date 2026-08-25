import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'app_dialog.dart';

/// Modal de confirmación genérico para acciones sensibles (ej. desactivar
/// un usuario) — reutilizable en vez de armar un `AlertDialog` distinto
/// cada vez. Devuelve `true` si el usuario confirmó, `false`/`null` si
/// canceló o cerró el diálogo.
class ConfirmarAccionDialog extends StatelessWidget {
  const ConfirmarAccionDialog({
    super.key,
    required this.titulo,
    required this.mensaje,
    this.textoConfirmar = 'Confirmar',
    this.destructivo = false,
  });

  final String titulo;
  final String mensaje;
  final String textoConfirmar;
  final bool destructivo;

  static Future<bool> show(
    BuildContext context, {
    required String titulo,
    required String mensaje,
    String textoConfirmar = 'Confirmar',
    bool destructivo = false,
  }) async {
    final resultado = await mostrarDialogoApp<bool>(
      context,
      builder: (_) => ConfirmarAccionDialog(
        titulo: titulo,
        mensaje: mensaje,
        textoConfirmar: textoConfirmar,
        destructivo: destructivo,
      ),
    );
    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialogShell(
      maxWidth: 380,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            mensaje,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: destructivo
                      ? ElevatedButton.styleFrom(backgroundColor: colors.error)
                      : null,
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(textoConfirmar),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
