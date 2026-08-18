import 'package:flutter/material.dart';

/// Paleta de colores de la app como [ThemeExtension].
///
/// Dirección "iOS" (Ajustes/Apps del sistema): fondo agrupado gris claro,
/// contenedores de lista blancos con separadores finos (no cards con
/// sombra por fila), un solo azul de acento (el de la marca INDI, muy
/// cercano al azul de sistema de iOS), y los colores semánticos
/// (success/warning/error) tomados de la paleta de sistema de Apple
/// (systemGreen/systemOrange/systemRed) en un tono ligeramente más oscuro
/// para que el texto pase contraste AA sobre blanco.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.primary,
    required this.primaryHover,
    required this.primaryOn,
    required this.headerBackground,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.sidebarBackground,
    required this.sidebarSurfaceAlt,
    required this.sidebarText,
    required this.sidebarTextMuted,
    required this.brandHeaderStart,
    required this.brandHeaderEnd,
    required this.brandHeaderDot,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primaryHover;
  final Color primaryOn;
  // Fondo del header de "large title" — igual al fondo de la pantalla (sin
  // banda de color), como en Ajustes de iOS: el título grande vive sobre
  // el mismo fondo que el contenido, no sobre un banner.
  final Color headerBackground;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  // El sidebar del panel administrativo (compromiso de escritorio/web,
  // iOS no tiene este patrón fuera de iPad) usa el mismo tratamiento claro
  // que el sidebar de Ajustes en iPad: fondo gris clarito, fila
  // seleccionada con un azul suave, texto oscuro — no un panel oscuro.
  final Color sidebarBackground;
  final Color sidebarSurfaceAlt;
  final Color sidebarText;
  final Color sidebarTextMuted;
  // Azul "de sello" de la marca — tomado del banner corporativo real
  // (fondo degradado + textura de puntos tipo halftone), distinto del
  // azul vívido de [primary] (que viene del isotipo/logo y se reserva
  // para botones/acentos interactivos). Fijo en ambos temas: es chrome
  // de marca, no una superficie que deba adaptarse a claro/oscuro.
  final Color brandHeaderStart;
  final Color brandHeaderEnd;
  final Color brandHeaderDot;

  static const light = AppColors(
    // systemGroupedBackground de iOS.
    background: Color(0xFFF2F2F7),
    // secondarySystemGroupedBackground — el blanco de los contenedores de
    // lista agrupada.
    surface: Color(0xFFFFFFFF),
    // systemGray6 — relleno de inputs y filas inactivas.
    surfaceAlt: Color(0xFFF2F2F7),
    // separator de iOS.
    border: Color(0xFFC6C6C8),
    // label.
    textPrimary: Color(0xFF000000),
    // secondaryLabel (aprox. sólido de #3C3C43 al 60%).
    textSecondary: Color(0xFF6C6C70),
    // tertiaryLabel / systemGray — placeholders, captions.
    textMuted: Color(0xFF8E8E93),
    // Azul de marca INDI (#1463FF) — único en toda la app: botones, acentos,
    // header y sidebar usan el mismo tono.
    primary: Color(0xFF1463FF),
    primaryHover: Color(0xFF0D4FCC),
    primaryOn: Color(0xFFFFFFFF),
    headerBackground: Color(0xFFF2F2F7),
    // systemGreen/systemOrange/systemRed de iOS, oscurecidos lo justo para
    // pasar WCAG AA como texto sobre blanco (el tono de sistema puro falla
    // contraste en texto pequeño).
    success: Color(0xFF1F8A3D),
    warning: Color(0xFFC26A00),
    error: Color(0xFFD70015),
    info: Color(0xFF0A84FF),
    sidebarBackground: Color(0xFF0B1F3A),
    // Azul suave (systemBlue al ~12% sobre blanco) — misma fila
    // seleccionada que usa el sidebar de Ajustes en iPad.
    sidebarSurfaceAlt: Color(0xFF173A67),
    sidebarText: Color(0xFFFFFFFF),
    sidebarTextMuted: Color(0xFFC4D2E5),
    brandHeaderStart: Color(0xFF0A2A54),
    brandHeaderEnd: Color(0xFF1463FF),
    brandHeaderDot: Color(0xFF5B8AFF),
  );

  /// Paleta oscura — 3 niveles de superficie con separación clara en vez
  /// de negro puro plano: [background] (fondo general, negro suave tipo
  /// Material `#121212`), [surface] (cards contenedoras, p. ej. la tarjeta
  /// de accesos rápidos del login) y [surfaceAlt] (elementos anidados
  /// dentro de una card, p. ej. el relleno de los inputs) — cada nivel
  /// sensiblemente más claro que el anterior para que la jerarquía se
  /// note sin depender solo del borde.
  static const dark = AppColors(
    // Fondo "profundo" — más oscuro que el Material #121212 para que las
    // cards flotantes tengan contraste claro de elevación.
    background: Color(0xFF0D0F12),
    // Superficie de cards flotantes — tono azulado frío, no gris neutro.
    surface: Color(0xFF1B202A),
    // Elementos anidados dentro de una card (inputs, barras de progreso).
    surfaceAlt: Color(0xFF232D3A),
    // Borde sutil de cards flotantes — blanco al 6%, solo visible en oscuro.
    border: Color(0x0FFFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    // >= 4.5:1 contra surface/surfaceAlt (WCAG AA para texto normal).
    textSecondary: Color(0xFFB0B0B0),
    textMuted: Color(0xFF9E9E9E),
    // Mismo azul que en el tema claro (`brandHeaderEnd` es fijo en ambos
    // temas) — ya tiene suficiente contraste sobre las superficies oscuras
    // de arriba, no necesita un tono más claro aparte.
    primary: Color(0xFF1463FF),
    primaryHover: Color(0xFF5B8AFF),
    primaryOn: Color(0xFFFFFFFF),
    headerBackground: Color(0xFF000000),
    success: Color(0xFF32D74B),
    warning: Color(0xFFFF9F0A),
    error: Color(0xFFFF453A),
    info: Color(0xFF0A84FF),
    sidebarBackground: Color(0xFF1C1C1E),
    sidebarSurfaceAlt: Color(0xFF0A3A75),
    sidebarText: Color(0xFFFFFFFF),
    sidebarTextMuted: Color(0xFFAEAEB2),
    brandHeaderStart: Color(0xFF0A2A54),
    brandHeaderEnd: Color(0xFF1463FF),
    brandHeaderDot: Color(0xFF5B8AFF),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? primary,
    Color? primaryHover,
    Color? primaryOn,
    Color? headerBackground,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? sidebarBackground,
    Color? sidebarSurfaceAlt,
    Color? sidebarText,
    Color? sidebarTextMuted,
    Color? brandHeaderStart,
    Color? brandHeaderEnd,
    Color? brandHeaderDot,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted: textMuted ?? this.textMuted,
      primary: primary ?? this.primary,
      primaryHover: primaryHover ?? this.primaryHover,
      primaryOn: primaryOn ?? this.primaryOn,
      headerBackground: headerBackground ?? this.headerBackground,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarSurfaceAlt: sidebarSurfaceAlt ?? this.sidebarSurfaceAlt,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarTextMuted: sidebarTextMuted ?? this.sidebarTextMuted,
      brandHeaderStart: brandHeaderStart ?? this.brandHeaderStart,
      brandHeaderEnd: brandHeaderEnd ?? this.brandHeaderEnd,
      brandHeaderDot: brandHeaderDot ?? this.brandHeaderDot,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      border: Color.lerp(border, other.border, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      primary: Color.lerp(primary, other.primary, t)!,
      primaryHover: Color.lerp(primaryHover, other.primaryHover, t)!,
      primaryOn: Color.lerp(primaryOn, other.primaryOn, t)!,
      headerBackground: Color.lerp(
        headerBackground,
        other.headerBackground,
        t,
      )!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      sidebarBackground: Color.lerp(
        sidebarBackground,
        other.sidebarBackground,
        t,
      )!,
      sidebarSurfaceAlt: Color.lerp(
        sidebarSurfaceAlt,
        other.sidebarSurfaceAlt,
        t,
      )!,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t)!,
      sidebarTextMuted: Color.lerp(
        sidebarTextMuted,
        other.sidebarTextMuted,
        t,
      )!,
      brandHeaderStart: Color.lerp(
        brandHeaderStart,
        other.brandHeaderStart,
        t,
      )!,
      brandHeaderEnd: Color.lerp(brandHeaderEnd, other.brandHeaderEnd, t)!,
      brandHeaderDot: Color.lerp(brandHeaderDot, other.brandHeaderDot, t)!,
    );
  }
}
