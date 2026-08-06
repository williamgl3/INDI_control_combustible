import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';

/// Contenedor de ancho responsivo estándar para el panel de chofer — mismo
/// patrón que ya usaba `TipoOperacionScreen` (el de referencia), extraído
/// aquí para que todas las pantallas del panel lo compartan y no puedan
/// quedarse con un `maxWidth` distinto por accidente.
///
/// Distinto de [ResponsiveScrollView] (usado en el panel administrativo):
/// aquí el padding lateral se calcula solo a partir del ancho de pantalla
/// (móvil/tablet/desktop, vía [MediaQuery]) en vez de ser un valor fijo por
/// pantalla — no se modifica `ResponsiveScrollView` directamente porque
/// también lo usan varias pantallas de administrativo fuera de este alcance.
class ContenidoResponsivo extends StatelessWidget {
  const ContenidoResponsivo({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.wideContentMaxWidth,
    this.paddingSuperior = 20,
    this.paddingInferior = 20,
    this.scrollable = true,
    this.physics,
    this.primary,
  });

  final Widget child;
  final double maxWidth;

  /// Espacio vertical arriba/abajo del contenido — sigue siendo explícito
  /// porque varias pantallas lo usan para dejar hueco a un FAB o a la barra
  /// de navegación inferior, no por motivos de responsividad.
  final double paddingSuperior;
  final double paddingInferior;

  /// `false` para el caso de una tarjeta centrada sin scroll (ej. pantallas
  /// de éxito/confirmación).
  final bool scrollable;
  final ScrollPhysics? physics;
  final bool? primary;

  /// Mismo padding lateral que aplica este widget, expuesto para widgets
  /// que necesitan alinearse con el contenido pero no pueden usar
  /// `ContenidoResponsivo` directamente (ej. `Scaffold.floatingActionButton`,
  /// que necesita poder medir el tamaño intrínseco de su hijo para su
  /// animación de entrada — algo que `LayoutBuilder` no soporta bien).
  static double paddingHorizontalPara(double anchoPantalla) {
    if (anchoPantalla < AppBreakpoints.tablet) return 16; // <700: móvil
    if (anchoPantalla < AppBreakpoints.desktop) return 24; // 700-1000: tablet
    return 32; // >=1000: desktop
  }

  @override
  Widget build(BuildContext context) {
    final horizontal = paddingHorizontalPara(MediaQuery.sizeOf(context).width);
    final padding = EdgeInsets.fromLTRB(
      horizontal,
      paddingSuperior,
      horizontal,
      paddingInferior,
    );

    // `LayoutBuilder` + `SizedBox` en vez de `Center` + `ConstrainedBox`:
    // este último le da al hijo un ancho *suelto* (0..maxWidth), y un
    // `Column(crossAxisAlignment: stretch)` interno puede colapsar a su
    // ancho intrínseco en vez de expandirse — corriendo de lugar cualquier
    // widget interactivo (visto en pruebas de widget con
    // `DropdownButtonFormField`). `SizedBox` fuerza un ancho exacto, sin
    // ambigüedad.
    final contenido = LayoutBuilder(
      builder: (context, constraints) {
        final anchoDisponible = constraints.maxWidth;
        final anchoContenido = anchoDisponible.isFinite
            ? (anchoDisponible < maxWidth ? anchoDisponible : maxWidth)
            : maxWidth;
        return Center(
          child: SizedBox(
            width: anchoContenido,
            child: Padding(padding: padding, child: child),
          ),
        );
      },
    );

    if (!scrollable) return contenido;

    return SingleChildScrollView(
      primary: primary,
      physics: physics,
      child: contenido,
    );
  }
}
