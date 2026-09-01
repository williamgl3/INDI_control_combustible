import 'package:flutter/material.dart';

import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import 'logo_glass.dart';

/// Cabecera sobria y compartida por todas las pantallas de autenticación.
/// La marca se construye con una superficie navy, tipografía y proporción;
/// no usa ondas, blobs ni gradientes decorativos.
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
    this.compactLogoSize = 70,
    this.title,
    this.subtitle,
    this.onBack,
    this.clipper,
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

  /// Se conserva por compatibilidad con llamadas antiguas; la cabecera ya no
  /// dibuja una ola ni acepta un clipper decorativo.
  final CustomClipper<Path>? clipper;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final defaultLogoSize = compact ? 70.0 : AppSizes.logoHeaderSize;
        final requestedLogoSize = compact ? compactLogoSize : logoSize;
        final logoWidth = requestedLogoSize == defaultLogoSize
            ? authLogoWidth(availableWidth, compact: compact)
            : requestedLogoSize;

        return Container(
          key: const Key('auth-s-shape-header'),
          width: double.infinity,
          height: height,
          color: colors.primary,
          child: Stack(
            alignment: AlignmentDirectional.topCenter,
            children: [
              if (showLogo)
                Positioned.fill(
                  key: const Key('auth-header-content-zone'),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: availableWidth,
                        child: _AuthBrand(
                          title: title,
                          subtitle: subtitle,
                          compact: compact,
                          showBrand: showBrand,
                          logoSize: logoWidth,
                          compactLogoSize: logoWidth,
                        ),
                      ),
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
      },
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
        // La zona visible del encabezado puede ser menor que [height] en el
        // layout partido de tablet/escritorio. Este margen compacto evita
        // que logo y textos desborden por pocos píxeles a 1024 px y con
        // escalado de texto, sin recortar contenido.
        padding: EdgeInsets.fromLTRB(24, compact ? 8 : 12, 24, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              label: 'Logo de INDI',
              image: true,
              child: IndiLogo(width: compact ? compactLogoSize : logoSize),
            ),
            SizedBox(height: showBrand ? (compact ? 8 : 12) : 12),
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
                const SizedBox(height: 4),
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
              if (showBrand) SizedBox(height: compact ? 8 : 12),
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
              const SizedBox(height: 6),
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
