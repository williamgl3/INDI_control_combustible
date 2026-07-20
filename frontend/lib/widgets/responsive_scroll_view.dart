import 'package:flutter/material.dart';

/// Envuelve el contenido con scroll de una pantalla/pestaña en un ancho
/// máximo centrado — sin esto, en una ventana de escritorio/web ancha
/// (monitores de 1920px+) el contenido se estira horrible (filas
/// larguísimas, texto perdido en el espacio). En teléfonos/tablets
/// angostos, [maxWidth] simplemente no se alcanza y no tiene efecto.
class ResponsiveScrollView extends StatelessWidget {
  const ResponsiveScrollView({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding = const EdgeInsets.all(20),
    this.primary,
    this.physics,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  final bool? primary;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      primary: primary,
      physics: physics,
      padding: padding,
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        ),
      ),
    );
  }
}
