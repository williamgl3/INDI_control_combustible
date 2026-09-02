import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';

/// Envoltura de las pantallas de chofer en ventanas anchas (laptop/
/// desktop). Antes forzaba un ancho de teléfono (480px) sin importar la
/// ventana — se quitó esa restricción para que el flujo de chofer se
/// sienta como una app de escritorio real (igual que el panel
/// administrativo, con su sidebar) en vez de una app móvil estirada.
///
/// Estas pantallas (Solicitar, Comprobar, Cerrar día, etc.) son rutas
/// empujadas por separado (`context.push`, ver `app_router.dart`), no
/// tabs dentro de un shell — no pueden traer su propio sidebar sin
/// restructurar la navegación a rutas anidadas. Por eso, en vez de un
/// sidebar propio, usan un ancho generoso (`maxWidth`) centrado: se
/// aprovecha mucho más espacio que antes, sin estirar un formulario de
/// una sola columna a todo el ancho de un monitor, que se vería mal.
class ChoferMobileWrapper extends StatelessWidget {
  const ChoferMobileWrapper({super.key, required this.child});

  final Widget child;

  static const double maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (!AppBreakpoints.isTabletOrDesktop(width)) return child;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
