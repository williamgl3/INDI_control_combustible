import 'package:flutter/material.dart';

/// Radios de borde reutilizados en toda la app.
///
/// Dirección "iOS": contenedores de lista agrupada y hojas/diálogos con el
/// radio "continuo" típico de Ajustes de iOS (~14), botones rellenos con
/// el radio moderado de `UIButton` (no píldora completa), y badges/pills en
/// cápsula como los indicadores de estado del sistema.
class AppRadii {
  const AppRadii._();

  static const double card = 14;
  static const double input = 10;
  static const double badge = 999; // pill/cápsula
  // Botones rellenos estilo iOS — radio moderado, no píldora completa.
  static const double button = 12;
  // Ítems de sidebar y botones de diálogo — mismo radio que los inputs.
  static const double navButton = 10;

  static const BorderRadius cardRadius = BorderRadius.all(
    Radius.circular(card),
  );
  static const BorderRadius inputRadius = BorderRadius.all(
    Radius.circular(input),
  );
  static const BorderRadius badgeRadius = BorderRadius.all(
    Radius.circular(badge),
  );
  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(button),
  );
  static const BorderRadius navButtonRadius = BorderRadius.all(
    Radius.circular(navButton),
  );
}
