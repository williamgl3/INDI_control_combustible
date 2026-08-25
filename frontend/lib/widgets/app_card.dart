import 'package:flutter/material.dart';

import '../theme/app_borders.dart';
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
///
/// Con [floating] se aplica el estilo "depth design": radio más amplio
/// (18), sombra más profunda (`shadows.floating`), borde blanco muy sutil
/// y la superficie flotante del tema. Diseñado para dark mode donde las
/// cards necesitan elevarse claramente del fondo profundo.
class AppCard extends StatefulWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppSpacing.lg),
    this.color,
    this.border,
    this.rippleColor,
    this.floating = false,
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

  /// Estilo "depth design" — radio 18, sombra profunda, borde blanco sutil.
  /// En dark mode las cards se elevan claramente del fondo #0D0F12.
  final bool floating;

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

    final radius = widget.floating
        ? AppRadii.floatingRadius
        : AppRadii.cardRadius;
    final shadows = widget.floating
        ? (_hover ? context.shadows.raised : context.shadows.floating)
        : (_hover ? context.shadows.raised : context.shadows.card);

    // En floating: si no se pasó un border explícito, se usa el borde
    // sutil del tema (blanco al 6% en oscuro, invisible en claro).
    final effectiveBorder =
        widget.border ??
        (widget.floating
            ? Border.all(color: colors.border, width: AppBorders.floating)
            : null);

    final tarjeta = AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? colors.surface,
        borderRadius: radius,
        border: effectiveBorder,
        boxShadow: shadows,
      ),
      child: widget.child,
    );

    if (!interactiva) return tarjeta;

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: PressableScale(
        onTap: widget.onTap,
        child: Material(
          color: Colors.transparent,
          borderRadius: radius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: radius,
            splashColor: rippleColor.withValues(alpha: 0.1),
            highlightColor: rippleColor.withValues(alpha: 0.06),
            child: tarjeta,
          ),
        ),
      ),
    );
  }
}
