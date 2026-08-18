import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_motion.dart';

/// Botón de acción circular tipo "glass" (fondo semi-transparente +
/// blur) para usarse sobre [BrandHeader] — antes los íconos de acción
/// (notificaciones, perfil, menú) iban sueltos sobre el azul sin
/// contenedor, lo que los dejaba planos y con poco contraste. Reemplaza
/// los `IconButton` sueltos de los headers de chofer/administrativo.
class HeaderGlassButton extends StatefulWidget {
  const HeaderGlassButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  /// El ícono (o `Badge`/`Stack` con ícono) a pintar centrado en el botón.
  final Widget icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  State<HeaderGlassButton> createState() => _HeaderGlassButtonState();
}

class _HeaderGlassButtonState extends State<HeaderGlassButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final habilitado = widget.onPressed != null;
    final escala = _hover ? 1.04 : 1.0;
    final alphaFondo = !habilitado
        ? 0.08
        : _hover
        ? 0.24
        : 0.14;

    return MouseRegion(
      cursor: habilitado ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (habilitado) setState(() => _hover = true);
      },
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        scale: escala,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: alphaFondo),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
              ),
              child: IconButton(
                tooltip: widget.tooltip,
                onPressed: widget.onPressed,
                padding: EdgeInsets.zero,
                iconSize: 24,
                style: IconButton.styleFrom(
                  minimumSize: const Size.square(48),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  disabledForegroundColor: Colors.white54,
                  focusColor: Colors.white24,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.white12,
                ),
                icon: widget.icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
