import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Botón para tomar una foto con la cámara (tablero, ticket, etc.) que
/// muestra una miniatura una vez capturada. `onTomarFoto` delega la
/// captura real al [FotoPicker] inyectado por la pantalla — este widget
/// solo se encarga de la presentación.
class CapturaFotoField extends StatelessWidget {
  const CapturaFotoField({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.rutaFoto,
    required this.onTomarFoto,
    this.cargando = false,
  });

  final String etiqueta;
  final IconData icono;
  final String? rutaFoto;
  final VoidCallback onTomarFoto;
  final bool cargando;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tieneFoto = rutaFoto != null;

    return Material(
      color: tieneFoto
          ? colors.success.withValues(alpha: 0.06)
          : colors.surfaceAlt,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: cargando ? null : onTomarFoto,
        borderRadius: AppRadii.cardRadius,
        hoverColor: colors.primary.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.tile),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(
              color: tieneFoto
                  ? colors.success.withValues(alpha: 0.4)
                  : colors.border,
            ),
          ),
          child: Row(
            children: [
              if (tieneFoto)
                ClipRRect(
                  borderRadius: AppRadii.inputRadius,
                  child: Image.file(
                    File(rutaFoto!),
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 44,
                      height: 44,
                      color: colors.success.withValues(alpha: 0.15),
                      child: Icon(icono, color: colors.success, size: 20),
                    ),
                  ),
                )
              else
                CircleAvatar(
                  backgroundColor: colors.primary.withValues(alpha: 0.12),
                  child: Icon(icono, color: colors.primary),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tieneFoto ? '$etiqueta · lista' : etiqueta,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: tieneFoto ? colors.success : colors.textPrimary,
                  ),
                ),
              ),
              if (cargando)
                const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(
                  tieneFoto ? Icons.refresh : Icons.camera_alt_outlined,
                  color: colors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
