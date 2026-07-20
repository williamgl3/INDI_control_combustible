import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'app_borders.dart';
import 'app_colors.dart';
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

  static ThemeData light() =>
      _build(AppColors.light, AppShadows.light, Brightness.light);

  static ThemeData dark() =>
      _build(AppColors.dark, AppShadows.dark, Brightness.dark);

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
      // Transición de plataforma consistente estilo iOS (slide desde la
      // derecha) en todas las plataformas, no solo en iOS real — decisión
      // de marca, igual que `_conTransicion` en app_router.dart para el
      // resto del motion de la app.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceAlt,
        // Sin contorno duro en reposo — el relleno (más oscuro que el
        // fondo) ya define el campo, como en la referencia del usuario.
        // El contorno solo aparece al enfocar o en error, para dar
        // feedback de estado.
        border: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(
            color: colors.primary,
            width: AppBorders.focus,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(
            color: colors.error,
            width: AppBorders.standard,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: BorderSide(color: colors.error, width: AppBorders.focus),
        ),
        prefixIconColor: colors.textMuted,
        labelStyle: textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryOn,
              disabledBackgroundColor: colors.border,
              disabledForegroundColor: colors.textMuted,
              // Botón relleno estilo iOS: plano, sin sombra — el contraste de
              // color ya es la señal, no la elevación.
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.buttonRadius,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                colors.primaryHover.withValues(alpha: 0.16),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          disabledForegroundColor: colors.textMuted,
          side: BorderSide(color: colors.border, width: AppBorders.standard),
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
