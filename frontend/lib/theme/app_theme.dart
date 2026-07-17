import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_gradients.dart';
import 'app_radii.dart';
import 'app_shadows.dart';
import 'app_typography.dart';

/// ThemeData completo de la app, construido a partir de los tokens de
/// [AppColors], [AppShadows], [AppRadii] y [AppTypography].
///
/// TODO-SPEC: la coherencia visual (radios de botón/input, elevaciones)
/// se basa en los valores placeholder de cada token file hasta tener
/// SPEC.md.
class AppTheme {
  const AppTheme._();

  static ThemeData light() => _build(AppColors.light, AppShadows.light, Brightness.light);

  static ThemeData dark() => _build(AppColors.dark, AppShadows.dark, Brightness.dark);

  static ThemeData _build(
    AppColors colors,
    AppShadows shadows,
    Brightness brightness,
  ) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: colors.primary,
      onPrimary: colors.primaryOn,
      secondary: colors.info,
      onSecondary: colors.primaryOn,
      error: colors.error,
      onError: colors.primaryOn,
      surface: colors.surface,
      onSurface: colors.textPrimary,
    );

    final textTheme = AppTypography.textTheme(colors.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colors.background,
      textTheme: textTheme,
      extensions: [colors, shadows],
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(color: colors.error),
        ),
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: colors.primaryOn,
          disabledBackgroundColor: colors.border,
          shadowColor: colors.primary.withValues(alpha: 0.35),
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.navButtonRadius),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          textStyle: textTheme.labelLarge,
        ).copyWith(
          // Pinta un gradiente de marca detrás de TODO ElevatedButton de la
          // app (en vez de un color plano) sin tener que tocar cada pantalla
          // — backgroundBuilder respeta el shape/estado (disabled/pressed)
          // del botón y solo cambia cómo se pinta el fondo.
          backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
          backgroundBuilder: (context, states, child) {
            if (states.contains(WidgetState.disabled)) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.border,
                  borderRadius: AppRadii.navButtonRadius,
                ),
                child: child,
              );
            }
            return Ink(
              decoration: BoxDecoration(
                gradient: AppGradients.primary(colors),
                borderRadius: AppRadii.navButtonRadius,
              ),
              child: child,
            );
          },
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.border, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: AppRadii.navButtonRadius),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          textStyle: textTheme.labelLarge,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      ),
    );
  }
}

/// Extensiones de acceso rápido a los tokens desde un [BuildContext].
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  AppShadows get shadows => Theme.of(this).extension<AppShadows>()!;
}
