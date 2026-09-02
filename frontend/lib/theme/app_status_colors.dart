import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colores semánticos de operación. Siempre se acompañan con texto o icono.
@immutable
class AppStatusColors extends ThemeExtension<AppStatusColors> {
  const AppStatusColors({
    required this.pending,
    required this.approved,
    required this.rejected,
    required this.offline,
    required this.synchronizing,
    required this.unconfigured,
    required this.declared,
    required this.measured,
  });

  final Color pending;
  final Color approved;
  final Color rejected;
  final Color offline;
  final Color synchronizing;
  final Color unconfigured;
  final Color declared;
  final Color measured;

  static const light = AppStatusColors(
    pending: Color(0xFF5F6B7A),
    approved: Color(0xFF147A38),
    rejected: Color(0xFFC62828),
    offline: Color(0xFF5F6368),
    synchronizing: AppColors.brandBlue,
    unconfigured: Color(0xFF6B7280),
    declared: Color(0xFF8A4B08),
    measured: Color(0xFF087F5B),
  );

  static const dark = AppStatusColors(
    pending: Color(0xFFB8BDC5),
    approved: Color(0xFF66D48A),
    rejected: Color(0xFFFF7B72),
    offline: Color(0xFFB8BDC5),
    synchronizing: AppColors.brandBlue,
    unconfigured: Color(0xFFB8BDC5),
    declared: Color(0xFFFFB86B),
    measured: Color(0xFF63D6B3),
  );

  @override
  AppStatusColors copyWith({
    Color? pending,
    Color? approved,
    Color? rejected,
    Color? offline,
    Color? synchronizing,
    Color? unconfigured,
    Color? declared,
    Color? measured,
  }) => AppStatusColors(
    pending: pending ?? this.pending,
    approved: approved ?? this.approved,
    rejected: rejected ?? this.rejected,
    offline: offline ?? this.offline,
    synchronizing: synchronizing ?? this.synchronizing,
    unconfigured: unconfigured ?? this.unconfigured,
    declared: declared ?? this.declared,
    measured: measured ?? this.measured,
  );

  @override
  AppStatusColors lerp(
    covariant ThemeExtension<AppStatusColors>? other,
    double t,
  ) {
    if (other is! AppStatusColors) return this;
    return AppStatusColors(
      pending: Color.lerp(pending, other.pending, t)!,
      approved: Color.lerp(approved, other.approved, t)!,
      rejected: Color.lerp(rejected, other.rejected, t)!,
      offline: Color.lerp(offline, other.offline, t)!,
      synchronizing: Color.lerp(synchronizing, other.synchronizing, t)!,
      unconfigured: Color.lerp(unconfigured, other.unconfigured, t)!,
      declared: Color.lerp(declared, other.declared, t)!,
      measured: Color.lerp(measured, other.measured, t)!,
    );
  }
}

extension AppStatusThemeContext on BuildContext {
  AppStatusColors get statusColors =>
      Theme.of(this).extension<AppStatusColors>()!;
}
