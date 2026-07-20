import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Familias tipográficas de la app.
///
/// Dirección "iOS": San Francisco (la fuente de sistema de Apple) no está
/// disponible en Google Fonts, así que se usa **Inter** como sustituto —
/// misma familia humanista de un solo peso variable, usada por todo el
/// sistema (títulos, cuerpo, labels) en vez de mezclar 2-3 familias
/// distintas por jerarquía, como hacía la dirección "corporativa" anterior.
/// IBM Plex Mono se mantiene para datos monoespaciados (folios, montos).
class AppTypography {
  const AppTypography._();

  static TextStyle inter({
    required double fontSize,
    required FontWeight fontWeight,
    Color? color,
    double? letterSpacing,
    double? height,
  }) {
    return GoogleFonts.inter(
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

  /// TextTheme base. `displayLarge` está calibrado al tamaño del
  /// "large title" de iOS (34px, bold) — ver `IosLargeTitleHeader`.
  static TextTheme textTheme(Color baseColor) {
    return TextTheme(
      displayLarge: inter(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      displayMedium: inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineLarge: inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineMedium: inter(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      headlineSmall: inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      titleLarge: inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      titleMedium: inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      titleSmall: inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      bodyLarge: inter(
        fontSize: 17,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodyMedium: inter(
        fontSize: 15,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      bodySmall: inter(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: baseColor,
      ),
      labelLarge: inter(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
      labelMedium: inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: baseColor,
      ),
      labelSmall: inter(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: baseColor,
      ),
    );
  }
}
