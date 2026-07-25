/// Tamaños puntuales que se repiten entre pantallas y no encajan en
/// ninguna otra escala del theme (espaciado, radios, tipografía) — hoy
/// solo el logo de marca sobre un header, para que login/registro/
/// recuperar-contraseña (todas comparten `AuthScreenShell`) usen
/// exactamente el mismo tamaño en vez de un número suelto repetido.
class AppSizes {
  const AppSizes._();

  /// Antes 56, luego 64 — se sube para que la marca tenga más presencia en
  /// el header. Usado también por el home de chofer (`LogoGlass` en su
  /// `BrandHeader`), para que el logo se vea igual de grande en todas las
  /// pantallas de la app de chofer.
  static const double logoHeaderSize = 76;
}
