import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'pressable_scale.dart';

/// Contenedor "flotante" reutilizable — fondo + esquinas redondeadas +
/// sombra sutil (`context.shadows.card`), con encogimiento al presionar
/// (vía [PressableScale]) y, en web/desktop, una sombra/escala más
/// marcadas al pasar el mouse. Antes cada tarjeta (`StatTile`,
/// `TarjetaAccionSugerida`, `TarjetaTopeSemanal`) repetía a mano el mismo
/// `BoxDecoration`+`Material`+`InkWell` — todas se construyen ahora sobre
/// este único primitivo, así que un ajuste de estilo futuro (radio,
/// sombra, animación) se hace en un solo lugar.
///
/// Sin [onTap] la tarjeta es puramente decorativa (sin ripple, hover ni
/// encogimiento) — para contenido informativo como [TarjetaTopeSemanal].
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.border,
    this.rippleColor,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final BoxBorder? border;

  /// Tiñe el splash/highlight del ripple al tocar — por defecto el azul
  /// de marca (`colors.primary`), como ya hacían `StatTile` y
  /// `TarjetaAccionSugerida` antes de este widget.
  final Color? rippleColor;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard> {
  bool _hover = false;

  void _setHover(bool valor) {
    if (widget.onTap == null) return;
    setState(() => _hover = valor);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final interactiva = widget.onTap != null;
    final rippleColor = widget.rippleColor ?? colors.primary;

    final tarjeta = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: widget.border,
        boxShadow: _hover ? context.shadows.raised : context.shadows.card,
      ),
      child: widget.child,
    );

    if (!interactiva) return tarjeta;

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: PressableScale(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hover ? 1.02 : 1.0,
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          child: Material(
            color: Colors.transparent,
            borderRadius: AppRadii.cardRadius,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: AppRadii.cardRadius,
              splashColor: rippleColor.withValues(alpha: 0.1),
              highlightColor: rippleColor.withValues(alpha: 0.06),
              child: tarjeta,
            ),
          ),
        ),
      ),
    );
  }
}
