import 'package:flutter/material.dart';

/// Fondo de degradado de marca — mismo tratamiento tonal que [BrandHeader]
/// (home de chofer/administrativo), para que el header del login/registro
/// combine con el resto de la app en vez de verse plano.
class BlobBackground extends StatelessWidget {
  const BlobBackground({super.key, required this.gradient});

  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(decoration: BoxDecoration(gradient: gradient));
  }
}
