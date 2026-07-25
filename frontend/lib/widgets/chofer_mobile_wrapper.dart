import 'package:flutter/material.dart';

/// Envoltura que simula una experiencia de app móvil nativa incluso en
/// pantallas anchas (laptop/desktop). En teléfonos (width <= 500px)
/// simplemente pasa el [child] sin modificaciones.
///
/// En ventanas anchas, restringe el contenido a un ancho máximo de 480px
/// centrado horizontalmente — igual que el patrón de login
/// ([AuthScreenShell]), para que todas las pantallas del flujo del chofer
/// se vean y se sientan como en un teléfono real sin importar el tamaño
/// de la ventana del navegador.
class ChoferMobileWrapper extends StatelessWidget {
  const ChoferMobileWrapper({super.key, required this.child});

  final Widget child;

  static const double maxWidth = 480;
  static const double _breakpoint = 500;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width <= _breakpoint) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
