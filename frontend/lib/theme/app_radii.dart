import 'package:flutter/material.dart';

/// Radios de borde reutilizados en toda la app.
///
/// TODO-SPEC: valores PLACEHOLDER. SPEC.md define radios exactos para
/// card, input, badge y navButton — reemplazar en cuanto esté disponible.
class AppRadii {
  const AppRadii._();

  static const double card = 16;
  static const double input = 12;
  static const double badge = 999; // pill
  static const double navButton = 12;

  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(card));
  static const BorderRadius inputRadius = BorderRadius.all(Radius.circular(input));
  static const BorderRadius badgeRadius = BorderRadius.all(Radius.circular(badge));
  static const BorderRadius navButtonRadius =
      BorderRadius.all(Radius.circular(navButton));
}
