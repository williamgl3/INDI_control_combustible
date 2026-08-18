import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import 'blob_background.dart';
import 'logo_glass.dart';
import 'wave_clipper.dart';

/// Encabezado de marca exclusivo de las pantallas públicas de autenticación.
///
/// La curva se pinta dentro de la altura asignada por `AuthScreenShell`.
/// El formulario permanece en el siguiente elemento del layout y nunca puede
/// ser invadido por esta decoración, incluso cuando aparece el teclado.
class AuthSShapeHeader extends StatelessWidget {
  const AuthSShapeHeader({
    super.key,
    required this.height,
    required this.leftHeightFactor,
    required this.rightHeightFactor,
    this.compact = false,
    this.showLogo = true,
    this.showBrand = true,
    this.logoSize = AppSizes.logoHeaderSize,
    this.compactLogoSize = 40,
    this.title,
    this.subtitle,
    this.onBack,
  });

  final double height;
  final double leftHeightFactor;
  final double rightHeightFactor;
  final bool compact;
  final bool showLogo;
  final bool showBrand;
  final double logoSize;
  final double compactLogoSize;
  final String? title;
  final String? subtitle;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final middle = Color.lerp(
      colors.brandHeaderStart,
      colors.brandHeaderEnd,
      0.5,
    )!;
    // Texto y decoración ocupan zonas distintas. Antes ambos llenaban el
    // mismo Stack y el extremo alto de la curva podía quedar detrás del
    // título o la descripción, especialmente con SafeArea de Android.
    final waveHeight = compact ? 42.0 : 56.0;
    const safetyGap = 24.0;

    return SizedBox(
      key: const Key('auth-s-shape-header'),
      width: double.infinity,
      height: height,
      child: Stack(
        alignment: AlignmentDirectional.topCenter,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: BlobBackground(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colors.brandHeaderStart,
                  middle,
                  colors.brandHeaderEnd,
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          Positioned(
            key: const Key('auth-header-wave-zone'),
            left: 0,
            right: 0,
            bottom: 0,
            height: waveHeight,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipPath(
                  key: const Key('auth-s-shape-blue-clip'),
                  clipper: SShapeHeaderClipper(
                    leftHeightFactor: leftHeightFactor,
                    rightHeightFactor: rightHeightFactor,
                  ),
                  child: BlobBackground(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colors.brandHeaderStart,
                        middle,
                        colors.brandHeaderEnd,
                      ],
                      stops: const [0, 0.55, 1],
                    ),
                  ),
                ),
                ClipPath(
                  key: const Key('auth-s-shape-surface-clip'),
                  clipper: SShapeSurfaceClipper(
                    leftHeightFactor: leftHeightFactor,
                    rightHeightFactor: rightHeightFactor,
                  ),
                  child: ColoredBox(color: colors.surface),
                ),
              ],
            ),
          ),
          if (showLogo)
            Positioned(
              key: const Key('auth-header-content-zone'),
              top: 0,
              left: 24,
              right: 24,
              bottom: waveHeight + safetyGap,
              child: Align(
                alignment: Alignment.topCenter,
                child: _AuthBrand(
                  title: title,
                  subtitle: subtitle,
                  compact: compact,
                  showBrand: showBrand,
                  logoSize: logoSize,
                  compactLogoSize: compactLogoSize,
                ),
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
                  tooltip: 'Volver',
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand({
    this.title,
    this.subtitle,
    required this.compact,
    required this.showBrand,
    required this.logoSize,
    required this.compactLogoSize,
  });

  final String? title;
  final String? subtitle;
  final bool compact;
  final bool showBrand;
  final double logoSize;
  final double compactLogoSize;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.only(top: compact ? 4 : 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Logo de INDI',
              image: true,
              child: LogoGlass(size: compact ? compactLogoSize : logoSize),
            ),
            SizedBox(
              height: showBrand ? (compact ? 4 : 8) : (compact ? 10 : 18),
            ),
            if (showBrand) ...[
              Text(
                'INDI Combustible',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 18 : null,
                ),
              ),
              if (!compact) ...[
                const SizedBox(height: 2),
                Text(
                  'Control de combustible en obra',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ],
            if (title != null) ...[
              if (showBrand) SizedBox(height: compact ? 3 : 8),
              Text(
                title!,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 19 : 22,
                ),
              ),
            ],
            if (subtitle != null && !compact) ...[
              SizedBox(height: showBrand ? 4 : 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: showBrand ? 2 : 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
