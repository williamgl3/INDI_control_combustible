import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'icon_badge.dart';
import 'pressable_scale.dart';

/// Tarjeta compacta de una métrica (ícono + valor + etiqueta), reutilizada
/// en las pestañas del panel administrativo. El valor hace una transición
/// de fundido al cambiar (ej. al aprobar una solicitud) en vez de saltar
/// de golpe al nuevo número.
///
/// [color] tiñe la insignia del ícono (por defecto el azul de marca) —
/// úsalo para distinguir tarjetas de distintas secciones a simple vista.
///
/// Si se pasa [onTap], la tarjeta se vuelve interactiva (hover/ripple +
/// encogimiento sutil al presionar + pequeño ícono de flecha) — pensado
/// para que un número accione algo concreto (ej. tocar "Por revisar"
/// filtra la lista de abajo a pendientes), en vez de ser solo decorativo.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icono,
    required this.valor,
    required this.etiqueta,
    this.color,
    this.onTap,
  });

  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final interactiva = onTap != null;
    final colorInsignia = color ?? colors.primary;

    return PressableScale(
      onTap: onTap,
      child: Material(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.cardRadius,
          hoverColor: colorInsignia.withValues(alpha: 0.06),
          splashColor: colorInsignia.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 18,
              horizontal: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: AppRadii.cardRadius,
              boxShadow: context.shadows.card,
            ),
            child: Stack(
              children: [
                Column(
                  children: [
                    IconBadge(icono: icono, color: colorInsignia),
                    const SizedBox(height: AppSpacing.sm),
                    AnimatedSwitcher(
                      duration: AppMotion.fast,
                      switchInCurve: AppMotion.curve,
                      switchOutCurve: AppMotion.curve,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: Text(
                        valor,
                        key: ValueKey(valor),
                        style: Theme.of(context).textTheme.headlineSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      etiqueta,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (interactiva)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: colors.textMuted,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
