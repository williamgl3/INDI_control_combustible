import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import 'app_dialog.dart';

/// Diálogo simple para ver una foto ya subida en tamaño grande — tanto
/// fotos ya en el servidor (URL, ej. las de incidencias/cargas vistas por
/// un administrativo) como locales todavía sin subir (ruta de archivo,
/// ej. las que un chofer acaba de tomar). Antes no había forma de volver
/// a ver una foto una vez enviado el formulario que la capturó.
class VerFotoDialog {
  const VerFotoDialog._();

  static Future<void> show(
    BuildContext context, {
    required String titulo,
    String? url,
    String? rutaLocal,
  }) {
    assert(
      (url == null) != (rutaLocal == null),
      'Pasa exactamente uno de url/rutaLocal.',
    );
    return mostrarDialogoApp<void>(
      context,
      builder: (_) =>
          _VerFotoDialogContent(titulo: titulo, url: url, rutaLocal: rutaLocal),
    );
  }
}

class _VerFotoDialogContent extends StatelessWidget {
  const _VerFotoDialogContent({required this.titulo, this.url, this.rutaLocal});

  final String titulo;
  final String? url;
  final String? rutaLocal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AppDialogShell(
      maxWidth: 480,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(titulo, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: AppRadii.cardRadius,
            child: url != null
                ? Image.network(
                    url!,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _ErrorFoto(colors: colors),
                    loadingBuilder: (context, child, progreso) =>
                        progreso == null
                        ? child
                        : const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                  )
                : Image.file(
                    File(rutaLocal!),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        _ErrorFoto(colors: colors),
                  ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}

class _ErrorFoto extends StatelessWidget {
  const _ErrorFoto({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      color: colors.surfaceAlt,
      alignment: Alignment.center,
      child: Icon(Icons.broken_image_outlined, color: colors.textMuted),
    );
  }
}
