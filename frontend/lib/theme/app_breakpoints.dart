/// Breakpoints responsivos de la app.
///
/// Confirmado por el usuario (no placeholder): el panel administrativo
/// usa sidebar en escritorio/tablet (>= [tablet]) y bottom nav en móvil
/// (< [tablet]).
class AppBreakpoints {
  const AppBreakpoints._();

  static const double mobile = 0;
  static const double tablet = 700;

  /// TODO-SPEC: no hay breakpoint de escritorio grande definido en el
  /// spec todavía; se deja igual a [tablet] hasta tener el valor real.
  static const double desktop = 700;

  static bool isMobile(double width) => width < tablet;

  static bool isTabletOrDesktop(double width) => width >= tablet;
}
