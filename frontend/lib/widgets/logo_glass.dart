import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Marca sobre un header con degradado — sin contenedor "glass" detrás
/// (el recuadro con tinte blanco se veía como un cuadro de otro color
/// pegado encima del degradado). Solo el isotipo, ya blanco en el propio
/// asset, flotando directo sobre el fondo.
///
/// Compartido por [BrandHeader] (home de chofer/administrativo) y
/// `AuthScreenShell` (login/registro/recuperar contraseña) para que el
/// tratamiento del logo sea consistente en toda la app.
enum IndiLogoSize { small, medium, large }

enum IndiLogoColor { primary, white }

double authLogoWidth(double screenWidth, {bool compact = false}) {
  if (compact) {
    if (screenWidth < 360) return 70;
    if (screenWidth < 430) return 78;
    return 84;
  }
  if (screenWidth < 360) return 90;
  if (screenWidth < 400) return 100;
  if (screenWidth < 430) return 110;
  return 118;
}

double internalHeaderLogoWidth(double screenWidth) {
  if (screenWidth >= 1200) return 64;
  if (screenWidth >= 700) return 56;
  if (screenWidth >= 400) return 46;
  return 42;
}

double internalHeaderLogoGap(double screenWidth) {
  if (screenWidth >= 1200) return 18;
  if (screenWidth >= 700) return 16;
  if (screenWidth >= 400) return 14;
  return 11;
}

/// Logo oficial de INDI. El asset es blanco y transparente, por lo que está
/// pensado para superficies navy/azules. Solo se fija el ancho; la altura la
/// determina el aspect ratio real del archivo.
class IndiLogo extends StatelessWidget {
  const IndiLogo({
    super.key,
    this.size = IndiLogoSize.medium,
    this.width,
    this.colorVariant = IndiLogoColor.white,
    this.semanticLabel = 'INDI Combustible',
  });

  final IndiLogoSize size;
  final double? width;
  final IndiLogoColor colorVariant;
  final String? semanticLabel;

  double _responsiveWidth(BuildContext context) {
    if (width != null) return width!;
    final viewport = MediaQuery.sizeOf(context).width;
    switch (size) {
      case IndiLogoSize.small:
        return 32;
      case IndiLogoSize.medium:
        return 64;
      case IndiLogoSize.large:
        if (viewport < 360) return 72;
        if (viewport < 430) return 84;
        return 94;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/logo_indi_mark.png',
      width: _responsiveWidth(context),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
    final content = colorVariant == IndiLogoColor.white
        ? image
        : ColorFiltered(
            colorFilter: ColorFilter.mode(
              context.colors.primary,
              BlendMode.srcIn,
            ),
            child: image,
          );
    return Semantics(image: true, label: semanticLabel, child: content);
  }
}

/// Alias histórico usado por headers existentes.
class LogoGlass extends StatelessWidget {
  const LogoGlass({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IndiLogo(width: size);
  }
}
