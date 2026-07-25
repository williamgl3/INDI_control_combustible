import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import 'brand_header.dart';
import 'logo_glass.dart';

/// Header de marca para pantallas de chofer que no son el Home (Solicitar
/// carga, Mis solicitudes, Mi consumo): mismo degradado/logo que
/// [BrandHeader], con el bloque logo+título centrado (a diferencia del
/// Home, que va en fila con "Hola, {nombre}" + menú) y un botón de volver
/// opcional — para pantallas empujadas como ruta independiente en vez de
/// vivir como pestaña de `ChoferHomeShell`.
class BrandSubHeader extends StatelessWidget {
  const BrandSubHeader({super.key, required this.titulo, this.onBack});

  final String titulo;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BrandHeader(
          padding: const EdgeInsets.fromLTRB(24, 44, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoGlass(size: AppSizes.logoHeaderSize),
              const SizedBox(height: 10),
              Text(
                titulo,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: BrandHeader.onColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        if (onBack != null)
          Positioned(
            top: 4,
            left: 4,
            child: SafeArea(
              bottom: false,
              child: IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
