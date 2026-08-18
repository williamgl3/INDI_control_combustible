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
class SShapeHeaderClipper extends CustomClipper<Path> {
  const SShapeHeaderClipper({
    this.leftHeightFactor = 0.88,
    this.rightHeightFactor = 0.48,
  });

  /// Fracción del alto donde la curva llega al borde izquierdo (x = 0).
  final double leftHeightFactor;

  /// Fracción del alto donde la curva llega al borde derecho (x = w).
  final double rightHeightFactor;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, size.height * leftHeightFactor)
      ..addSShapeBoundary(
        size,
        leftHeightFactor: leftHeightFactor,
        rightHeightFactor: rightHeightFactor,
      )
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
  }

  @override
  bool shouldReclip(covariant SShapeHeaderClipper oldClipper) =>
      oldClipper.leftHeightFactor != leftHeightFactor ||
      oldClipper.rightHeightFactor != rightHeightFactor;
}

/// Recorta la superficie inferior usando exactamente el mismo límite que la
/// capa azul. Así ambas piezas son complementarias y no se genera un hueco
/// entre ellas por diferencias de geometría.
class SShapeSurfaceClipper extends CustomClipper<Path> {
  const SShapeSurfaceClipper({
    this.leftHeightFactor = 0.88,
    this.rightHeightFactor = 0.48,
  });

  final double leftHeightFactor;
  final double rightHeightFactor;

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height * leftHeightFactor)
      ..addSShapeBoundary(
        size,
        leftHeightFactor: leftHeightFactor,
        rightHeightFactor: rightHeightFactor,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant SShapeSurfaceClipper oldClipper) =>
      oldClipper.leftHeightFactor != leftHeightFactor ||
      oldClipper.rightHeightFactor != rightHeightFactor;
}

extension on Path {
  void addSShapeBoundary(
    Size size, {
    required double leftHeightFactor,
    required double rightHeightFactor,
  }) {
    final width = size.width;
    final height = size.height;
    final yLeft = height * leftHeightFactor;
    final yRight = height * rightHeightFactor;
    final yMiddle = (yLeft + yRight) / 2;

    // El primer lóbulo baja antes de subir hacia la inflexión central.
    cubicTo(
      width * 0.18,
      (yLeft + height * 0.08).clamp(0, height),
      width * 0.31,
      (yMiddle - height * 0.10).clamp(0, height),
      width * 0.50,
      yMiddle,
    );
    // El segundo empieza con la misma dirección visual, baja suavemente y
    // vuelve a subir hacia la derecha. La inflexión queda exactamente al 50%.
    cubicTo(
      width * 0.69,
      (yMiddle + height * 0.10).clamp(0, height),
      width * 0.82,
      (yRight - height * 0.08).clamp(0, height),
      width,
      yRight,
    );
  }
}
