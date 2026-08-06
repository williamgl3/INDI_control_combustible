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
/// La coherencia visual (radios de botón/input, elevaciones) se define aquí
/// usando los valores de cada token file, según SPEC.md.
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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        // minWidth un poco mayor que el ícono (24px) + su padding visual
        // por defecto — antes quedaba pegado al borde izquierdo del campo.
        prefixIconConstraints: const BoxConstraints(
          minWidth: 52,
          minHeight: 44,
        ),
        suffixIconColor: colors.textMuted,
        hintStyle: textTheme.bodyMedium?.copyWith(color: colors.textMuted),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        // En claro: sin contorno duro en reposo — el relleno (más oscuro
        // que el fondo) ya define el campo, como en la referencia del
        // usuario. En oscuro: el relleno de un input dentro de una card
        // (surfaceAlt sobre surface) se distingue menos a simple vista que
        // en claro, así que se agrega un trazo blanco muy sutil en reposo
        // para que el campo no se confunda con la card que lo contiene.
        // El contorno de foco/error se mantiene igual en ambos temas.
        border: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: brightness == Brightness.dark
              ? BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: AppBorders.hairline,
                )
              : BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.inputRadius,
          borderSide: brightness == Brightness.dark
              ? BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: AppBorders.hairline,
                )
              : BorderSide.none,
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
        // Sin esto, Flutter escala el mismo `labelStyle` (bodyMedium, 14px)
        // hacia abajo un factor fijo al flotar — un tamaño "de compromiso",
        // ni el de reposo ni uno pensado a propósito para flotar. Un
        // estilo explícito, más chico y con un poco de tracking, hace que
        // la etiqueta se lea como una etiqueta integrada al campo (no como
        // el mismo texto solo encogido) sin necesidad de un borde visible
        // en reposo (esa decisión de diseño no se toca aquí).
        floatingLabelStyle: textTheme.labelSmall?.copyWith(
          color: colors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              backgroundColor: colors.primary,
              foregroundColor: colors.primaryOn,
              disabledBackgroundColor: colors.border,
              disabledForegroundColor: colors.textMuted,
              // Mismo lenguaje de sombra "flotante" que `AppShadows.floating`
              // (suave, difusa, opacidad baja) — Material calcula la sombra
              // de un botón a partir de `elevation`/`shadowColor`, no acepta
              // una lista de `BoxShadow`, así que se traduce el mismo
              // criterio en vez de reutilizar el token literal. Antes era
              // negro al 35% con poca elevación (más dura/marcada que el
              // resto de la app).
              elevation: 6,
              shadowColor: Colors.black.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.buttonRadius,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                colors.primaryHover.withValues(alpha: 0.16),
              ),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              foregroundColor: colors.textPrimary,
              backgroundColor: colors.surface,
              disabledForegroundColor: colors.textMuted,
              side: BorderSide(
                color: colors.border,
                width: AppBorders.standard,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: AppRadii.navButtonRadius,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                colors.surfaceAlt.withValues(alpha: 0.7),
              ),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              foregroundColor: colors.primary,
              disabledForegroundColor: colors.textMuted,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              textStyle: textTheme.labelLarge,
            ).copyWith(
              overlayColor: WidgetStatePropertyAll(
                colors.primary.withValues(alpha: 0.08),
              ),
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
