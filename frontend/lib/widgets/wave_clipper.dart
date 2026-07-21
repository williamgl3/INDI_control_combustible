import 'package:flutter/material.dart';

/// Corte ondulado ("wave") para el borde inferior del header de las
/// pantallas de autenticación — el header azul termina en una curva de
/// dos vientres en vez de una línea recta. Se aplica directamente sobre
/// el propio header (no como una capa superpuesta al contenido), así que
/// la división queda fija y no puede interferir con el scroll del
/// formulario de abajo.
class WaveBottomClipper extends CustomClipper<Path> {
  const WaveBottomClipper({this.amplitude = 28});

  final double amplitude;

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()..moveTo(0, h - amplitude);
    path.cubicTo(
      w * 0.22,
      h,
      w * 0.30,
      h - amplitude * 2,
      w * 0.52,
      h - amplitude * 1.15,
    );
    path.cubicTo(
      w * 0.72,
      h - amplitude * 0.35,
      w * 0.82,
      h + amplitude * 0.4,
      w,
      h - amplitude * 0.55,
    );
    path.lineTo(w, 0);
    path.lineTo(0, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant WaveBottomClipper oldClipper) =>
      oldClipper.amplitude != amplitude;
}
