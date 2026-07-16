import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Familias tipográficas de la app: Manrope (texto general), Sora
/// (títulos/branding) e IBM Plex Mono (datos numéricos/monoespaciados).
///
/// TODO-SPEC: la tabla de tamaños/pesos por estilo de texto de SPEC.md
/// no está disponible aún. Los tamaños usados en [AppTypography.textTheme]
/// son PLACEHOLDER (escala tipográfica estándar de Material).
class AppTypography {
  const AppTypography._();

  static TextStyle manrope({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.manrope(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle sora({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.sora(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  static TextStyle ibmPlexMono({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
      height: height,
    );
  }

  /// TextTheme base. TODO-SPEC: mapear a la tabla exacta de SPEC.md.
  static TextTheme textTheme(Color baseColor) {
    return TextTheme(
      displayLarge: sora(fontSize: 40, fontWeight: FontWeight.w700, color: baseColor),
      displayMedium: sora(fontSize: 32, fontWeight: FontWeight.w700, color: baseColor),
      headlineLarge: sora(fontSize: 28, fontWeight: FontWeight.w700, color: baseColor),
      headlineMedium: sora(fontSize: 24, fontWeight: FontWeight.w600, color: baseColor),
      headlineSmall: sora(fontSize: 20, fontWeight: FontWeight.w600, color: baseColor),
      titleLarge: manrope(fontSize: 18, fontWeight: FontWeight.w700, color: baseColor),
      titleMedium: manrope(fontSize: 16, fontWeight: FontWeight.w700, color: baseColor),
      titleSmall: manrope(fontSize: 14, fontWeight: FontWeight.w700, color: baseColor),
      bodyLarge: manrope(fontSize: 16, fontWeight: FontWeight.w400, color: baseColor),
      bodyMedium: manrope(fontSize: 14, fontWeight: FontWeight.w400, color: baseColor),
      bodySmall: manrope(fontSize: 12, fontWeight: FontWeight.w400, color: baseColor),
      labelLarge: manrope(fontSize: 14, fontWeight: FontWeight.w600, color: baseColor),
      labelMedium: manrope(fontSize: 13, fontWeight: FontWeight.w800, color: baseColor),
      labelSmall: manrope(fontSize: 11, fontWeight: FontWeight.w600, color: baseColor),
    );
  }
}
