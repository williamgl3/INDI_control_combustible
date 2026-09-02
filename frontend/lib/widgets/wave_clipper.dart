import 'package:flutter/material.dart';

/// Silueta orgánica compartida por todos los encabezados de autenticación.
/// Tiene tres movimientos amplios, deliberadamente asimétricos: una entrada
/// baja y corta, un ascenso central largo y una salida más progresiva.
///
/// `leftHeightFactor` y `rightHeightFactor` son fracciones del alto del
/// contenedor (`size.height`), no píxeles fijos, para que la diagonal se
/// vea proporcional en móvil, tablet y web.
///
/// Sobre el fix del "hueco negro": a diferencia de la onda anterior, este
/// trazo NO necesita tocar `size.height` en los extremos. Esa corrección
/// ya no depende de la geometría de la curva — depende de que el color
/// detrás de este header (`Scaffold.backgroundColor` en el flujo móvil, o
/// el `Container` de la tarjeta en escritorio, ambos en
/// `auth_screen_shell.dart`) sea exactamente `colors.surface`, el mismo
/// que usa el área debajo del header. Por eso cualquier zona entre esta
/// curva y el borde inferior real, que el degradado no llega a cubrir, se
/// funde con ese fondo en vez de dejar ver un color distinto. Ese archivo
/// no se toca aquí.
class SShapeHeaderClipper extends CustomClipper<Path> {
  const SShapeHeaderClipper({
    this.leftHeightFactor = 0.94,
    this.rightHeightFactor = 0.80,
  });

  /// Fracción del alto donde la curva llega al borde izquierdo (x = 0).
  final double leftHeightFactor;

  /// Fracción del alto donde la curva llega al borde derecho (x = w).
  final double rightHeightFactor;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final yLeft = h * leftHeightFactor;
    final yRight = h * rightHeightFactor;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, yLeft)
      ..cubicTo(w * 0.10, yLeft, w * 0.18, h * 0.87, w * 0.34, h * 0.84)
      ..cubicTo(w * 0.47, h * 0.86, w * 0.57, h * 0.86, w * 0.67, h * 0.80)
      ..cubicTo(w * 0.78, h * 0.72, w * 0.88, yRight, w, yRight)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant SShapeHeaderClipper oldClipper) =>
      oldClipper.leftHeightFactor != leftHeightFactor ||
      oldClipper.rightHeightFactor != rightHeightFactor;
}

/// Onda horizontal exclusiva del login. Mantiene dos ondulaciones amplias,
/// discretas y casi niveladas sin reutilizar la diagonal de las pantallas
/// secundarias de autenticación.
class LoginWaveClipper extends CustomClipper<Path> {
  const LoginWaveClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, h * 0.82)
      ..cubicTo(w * 0.14, h * 0.92, w * 0.27, h * 0.70, w * 0.43, h * 0.73)
      ..cubicTo(w * 0.59, h * 0.73, w * 0.74, h * 0.96, w * 0.88, h * 0.87)
      ..cubicTo(w * 0.94, h * 0.86, w * 0.98, h * 0.80, w, h * 0.82)
      ..lineTo(w, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant LoginWaveClipper oldClipper) => false;
}
