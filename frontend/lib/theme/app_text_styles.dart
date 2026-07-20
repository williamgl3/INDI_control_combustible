import 'package:flutter/material.dart';

import 'app_typography.dart';

/// Estilos de texto compuestos reutilizados por varias pantallas, para no
/// reconstruirlos formulario por formulario.
///
/// TODO-SPEC: `formLabel` refleja el patrón "label superior en mayúsculas,
/// 13px, w800" mencionado por el usuario; falta confirmar letterSpacing y
/// color exactos contra SPEC.md.
class AppTextStyles {
  const AppTextStyles._();

  /// Label de formulario en mayúsculas (ej. encabezados de campo en
  /// Login / Registro de chofer / EditarChoferDialog).
  static TextStyle formLabel(Color color) {
    return AppTypography.inter(
      fontSize: 13,
      fontWeight: FontWeight.w800,
      color: color,
      letterSpacing: 0.6,
    );
  }

  /// Texto de dato numérico/monoespaciado (ej. placa, folio, montos).
  static TextStyle monoData(Color color) {
    return AppTypography.ibmPlexMono(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: color,
    );
  }
}
