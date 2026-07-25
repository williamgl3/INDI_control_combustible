import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';

/// Una foto a mostrar en [ConfirmarFotosDialog]: su etiqueta (ej. "Foto del
/// tablero") y la ruta local del archivo ya capturado.
class FotoPreview {
  const FotoPreview({required this.etiqueta, required this.ruta});

  final String etiqueta;
  final String ruta;
}

/// Diálogo de última revisión antes de enviar un formulario que incluye
/// fotos (comprobar carga, cerrar día): las muestra en tamaño más grande
/// que la miniatura de [CapturaFotoField], para que el chofer confirme
/// que se ven bien antes de mandarlas — evita reenvíos por una foto
/// borrosa o del ángulo equivocado que solo se nota ya en el panel admin.
class ConfirmarFotosDialog extends StatelessWidget {
  const ConfirmarFotosDialog({super.key, required this.fotos});

  final List<FotoPreview> fotos;

  /// Devuelve `true` si el usuario eligió "Confirmar y enviar", `false`
  /// (o `null` si cerró el diálogo de otra forma) si eligió "Volver a
  /// tomar" — en ese caso no se hace nada más, el chofer decide qué foto
  /// retomar desde la pantalla de origen.
  static Future<bool> show(
    BuildContext context, {
    required List<FotoPreview> fotos,
  }) async {
    final resultado = await mostrarDialogoApp<bool>(
      context,
      builder: (_) => ConfirmarFotosDialog(fotos: fotos),
    );
    return resultado ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppDialogShell(
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Revisa tus fotos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Confirma que se ven bien antes de enviar — no podrás cambiarlas '
            'después.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 16),
          for (final foto in fotos) ...[
            Text(
              foto.etiqueta,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: AppRadii.cardRadius,
              child: Image.file(
                File(foto.ruta),
                width: double.infinity,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: double.infinity,
                  height: 220,
                  color: colors.surfaceAlt,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: colors.textMuted,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Volver a tomar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Confirmar y enviar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
