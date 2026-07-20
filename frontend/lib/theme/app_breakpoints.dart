/// Breakpoints responsivos de la app — cubren desde teléfonos chicos
/// (~320px, Android/iPhone SE) hasta monitores anchos de escritorio/web
/// (2000px+).
///
/// Confirmado por el usuario (no placeholder): el panel administrativo
/// usa sidebar en escritorio/tablet (>= [tablet]) y bottom nav en móvil
/// (< [tablet]).
class AppBreakpoints {
  const AppBreakpoints._();

  static const double mobile = 0;
  static const double tablet = 700;

  /// Escritorio "grande" — a partir de aquí conviene aprovechar el ancho
  /// extra con más columnas en vez de solo centrar contenido angosto.
  static const double desktop = 1000;

  /// Ancho máximo de contenido para pantallas de formulario/flujo tipo
  /// teléfono (login, registro, solicitar/comprobar carga, cerrar día)
  /// cuando se ven en una ventana ancha de escritorio/web — evita que el
  /// contenido se estire feo a todo lo ancho de un monitor grande.
  static const double contentMaxWidth = 480;

  static bool isMobile(double width) => width < tablet;

  static bool isTabletOrDesktop(double width) => width >= tablet;

  static bool isDesktop(double width) => width >= desktop;
}
