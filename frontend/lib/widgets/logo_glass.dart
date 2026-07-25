import 'package:flutter/material.dart';

/// Marca sobre un header con degradado — sin contenedor "glass" detrás
/// (el recuadro con tinte blanco se veía como un cuadro de otro color
/// pegado encima del degradado). Solo el isotipo, ya blanco en el propio
/// asset, flotando directo sobre el fondo.
///
/// Compartido por [BrandHeader] (home de chofer/administrativo) y
/// `AuthScreenShell` (login/registro/recuperar contraseña) para que el
/// tratamiento del logo sea consistente en toda la app.
class LogoGlass extends StatelessWidget {
  const LogoGlass({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Image.asset('assets/images/logo_indi_mark.png', fit: BoxFit.contain),
    );
  }
}
