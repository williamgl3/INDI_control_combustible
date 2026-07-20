/// Anchos de borde reutilizados en toda la app — antes había 4 valores
/// ad-hoc sin token (1.0 implícito, 1.4, 1.5, 3) decididos por archivo.
/// Consolidados a 3 con propósito explícito.
class AppBorders {
  const AppBorders._();

  /// Bordes finos de tiles de lista (`Border.all(color: colors.border)`).
  static const double hairline = 1.0;

  /// Inputs en reposo/error, y el borde de `OutlinedButton`.
  static const double standard = 1.5;

  /// Input enfocado / error enfocado — el estado que más se necesita notar.
  static const double focus = 2.0;

  /// Indicador de selección (ítem activo del sidebar).
  static const double accent = 3.0;
}
