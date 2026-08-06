import 'package:flutter/material.dart';

/// Recorte que divide el header en una diagonal fluida tipo "S" —el lado
/// izquierdo del header baja más (más área azul) y el lado derecho sube
/// más (menos área azul), en vez de una onda centrada y simétrica.
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
class WaveBottomClipper extends CustomClipper<Path> {
  const WaveBottomClipper({
    this.leftHeightFactor = 0.68,
    this.rightHeightFactor = 0.45,
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
    final yMid = (yLeft + yRight) / 2;

    return Path()
      ..moveTo(0, yLeft)
      // Primer tramo: de la altura izquierda a la altura media, con
      // salida y llegada horizontales (mismo `y` que el punto vecino) —
      // así la curva es un solo trazo fluido, sin quiebres.
      ..cubicTo(w * 0.25, yLeft, w * 0.25, yMid, w * 0.5, yMid)
      // Segundo tramo: de la altura media a la altura derecha, con la
      // inflexión opuesta al primer tramo — esto forma la "S".
      ..cubicTo(w * 0.75, yMid, w * 0.75, yRight, w, yRight)
      ..lineTo(w, 0)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant WaveBottomClipper oldClipper) =>
      oldClipper.leftHeightFactor != leftHeightFactor ||
      oldClipper.rightHeightFactor != rightHeightFactor;
}
