import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_elevated_button.dart';

/// Mensaje centrado para listas/tablas sin datos, reutilizado en varias
/// pestañas del panel administrativo y pantallas de chofer.
///
/// Da más presencia visual que un ícono plano y chico: un círculo suave
/// de color de marca detrás del ícono, y opcionalmente una acción
/// sugerida ([accion]/[onAccion]) para los casos donde sí hay algo que
/// hacer (ej. "Aún no tienes solicitudes" -> "Solicitar carga"), no para
/// los casos donde de verdad no hay nada que el usuario pueda accionar
/// (ej. "Aún no hay incidencias reportadas").
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    required this.mensaje,
    this.icono,
    this.textoAccion,
    this.onAccion,
  });

  final String mensaje;
  final IconData? icono;

  /// Texto del botón de acción sugerida. Si es `null` (default), no se
  /// muestra ningún botón.
  final String? textoAccion;
  final VoidCallback? onAccion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      container: true,
      label: mensaje,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xxl,
        ),
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icono, size: 30, color: colors.primary),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: colors.textMuted),
              ),
              if (textoAccion != null && onAccion != null) ...[
                const SizedBox(height: AppSpacing.lg),
                AppElevatedButton(
                  onPressed: onAccion!,
                  cargando: false,
                  child: Text(textoAccion!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
