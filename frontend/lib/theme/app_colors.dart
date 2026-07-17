import 'package:flutter/material.dart';

/// Paleta de colores de la app como [ThemeExtension].
///
/// TODO-SPEC: estos valores son PLACEHOLDER. No existe todavía
/// frontend/design/SPEC.md, así que se eligieron valores razonables
/// (paleta neutra + acento azul) para poder avanzar. Deben reemplazarse
/// por los valores EXACTOS del spec en cuanto esté disponible.
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
    required this.primaryOn,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.accentAdmin,
    required this.accentAdminDark,
    required this.sidebarBackground,
    required this.sidebarSurfaceAlt,
    required this.sidebarText,
    required this.sidebarTextMuted,
  });

  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color primary;
  final Color primaryOn;
  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  // Acento morado/índigo reservado para lo relacionado con el flujo de
  // administrador (modal de acceso, sidebar del panel) — distingue
  // visualmente ese flujo del azul de marca usado para chofer.
  final Color accentAdmin;
  final Color accentAdminDark;
  // El sidebar del panel administrativo es intencionalmente oscuro en
  // ambos temas (claro/oscuro) — es una superficie de marca fija, no una
  // superficie que siga el tema del sistema.
  final Color sidebarBackground;
  final Color sidebarSurfaceAlt;
  final Color sidebarText;
  final Color sidebarTextMuted;

  /// TODO-SPEC: paleta claro placeholder.
  static const light = AppColors(
    background: Color(0xFFF5F6F8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFEEF0F3),
    border: Color(0xFFDDE1E6),
    textPrimary: Color(0xFF1A1D21),
    textSecondary: Color(0xFF4B5563),
    textMuted: Color(0xFF8A8F98),
    primary: Color(0xFF1D4ED8),
    primaryOn: Color(0xFFFFFFFF),
    success: Color(0xFF16A34A),
    warning: Color(0xFFCA8A04),
    error: Color(0xFFDC2626),
    info: Color(0xFF3B82F6),
    accentAdmin: Color(0xFF7C3AED),
    accentAdminDark: Color(0xFF4F46E5),
    sidebarBackground: Color(0xFF0F172A),
    sidebarSurfaceAlt: Color(0xFF1E293B),
    sidebarText: Color(0xFFF8FAFC),
    sidebarTextMuted: Color(0xFF94A3B8),
  );

  /// TODO-SPEC: paleta oscuro placeholder, preparada para el futuro modo oscuro.
  static const dark = AppColors(
    background: Color(0xFF121417),
    surface: Color(0xFF1C1F23),
    surfaceAlt: Color(0xFF25282D),
    border: Color(0xFF33373D),
    textPrimary: Color(0xFFF5F6F8),
    textSecondary: Color(0xFFC2C6CC),
    textMuted: Color(0xFF8A8F98),
    primary: Color(0xFF3B82F6),
    primaryOn: Color(0xFF0A0E14),
    success: Color(0xFF22C55E),
    warning: Color(0xFFEAB308),
    error: Color(0xFFEF4444),
    info: Color(0xFF60A5FA),
    accentAdmin: Color(0xFF9333EA),
    accentAdminDark: Color(0xFF6366F1),
    sidebarBackground: Color(0xFF0F172A),
    sidebarSurfaceAlt: Color(0xFF1E293B),
    sidebarText: Color(0xFFF8FAFC),
    sidebarTextMuted: Color(0xFF94A3B8),
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
    Color? primaryOn,
    Color? success,
    Color? warning,
    Color? error,
    Color? info,
    Color? accentAdmin,
    Color? accentAdminDark,
    Color? sidebarBackground,
    Color? sidebarSurfaceAlt,
    Color? sidebarText,
    Color? sidebarTextMuted,
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
      primaryOn: primaryOn ?? this.primaryOn,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
      info: info ?? this.info,
      accentAdmin: accentAdmin ?? this.accentAdmin,
      accentAdminDark: accentAdminDark ?? this.accentAdminDark,
      sidebarBackground: sidebarBackground ?? this.sidebarBackground,
      sidebarSurfaceAlt: sidebarSurfaceAlt ?? this.sidebarSurfaceAlt,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarTextMuted: sidebarTextMuted ?? this.sidebarTextMuted,
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
      primaryOn: Color.lerp(primaryOn, other.primaryOn, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
      info: Color.lerp(info, other.info, t)!,
      accentAdmin: Color.lerp(accentAdmin, other.accentAdmin, t)!,
      accentAdminDark: Color.lerp(accentAdminDark, other.accentAdminDark, t)!,
      sidebarBackground: Color.lerp(sidebarBackground, other.sidebarBackground, t)!,
      sidebarSurfaceAlt: Color.lerp(sidebarSurfaceAlt, other.sidebarSurfaceAlt, t)!,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t)!,
      sidebarTextMuted: Color.lerp(sidebarTextMuted, other.sidebarTextMuted, t)!,
    );
  }
}
