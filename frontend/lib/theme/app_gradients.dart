import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Gradientes de marca reutilizados en headers y botones primarios.
///
/// TODO-SPEC: valores PLACEHOLDER hasta tener SPEC.md.
class AppGradients {
  const AppGradients._();

  /// Azul de marca — usado para el flujo de chofer (headers, CTA principal).
  static LinearGradient primary(AppColors colors) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.info, colors.primary],
      );

  /// Morado/índigo — reservado para lo relacionado con el administrador
  /// (modal de acceso, sidebar del panel), para distinguirlo del azul de
  /// chofer.
  static LinearGradient admin(AppColors colors) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [colors.accentAdmin, colors.accentAdminDark],
      );
}
