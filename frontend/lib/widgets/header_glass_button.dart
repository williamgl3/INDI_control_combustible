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
  final VoidCallback onPressed;

  @override
  State<HeaderGlassButton> createState() => _HeaderGlassButtonState();
}

class _HeaderGlassButtonState extends State<HeaderGlassButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final escala = _pressed ? 0.92 : (_hover ? 1.06 : 1.0);
    final alphaFondo = _pressed || _hover ? 0.24 : 0.14;

    return Semantics(
      button: true,
      label: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: Tooltip(
            message: widget.tooltip,
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
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: alphaFondo),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                      ),
                    ),
                    child: widget.icon,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
