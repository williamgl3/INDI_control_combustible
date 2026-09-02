/// Escala de espaciado de la app — antes cada pantalla usaba sus propios
/// números sueltos (aunque en la práctica ya convergían casi todos a esta
/// misma escala). `tile` se formaliza aparte porque es un valor real e
/// intencional (padding de los tiles de lista en toda la app), no un
/// outlier a eliminar.
class AppSpacing {
  const AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;

  /// Padding estándar de los tiles de lista (`_SolicitudTile`,
  /// `_ChoferTile`, `_VehiculoTile`, etc.) en toda la app.
  static const double tile = 14;

  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
  static const double xxxl = 32;
  static const double huge = 40;
}
