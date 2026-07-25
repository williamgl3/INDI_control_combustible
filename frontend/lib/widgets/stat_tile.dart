import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';
import 'app_card.dart';
import 'icon_badge.dart';

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
    this.destacado = false,
  });

  final IconData icono;
  final String valor;
  final String etiqueta;
  final Color? color;
  final VoidCallback? onTap;

  /// `true` cuando esta tarjeta necesita ACCIÓN del usuario (ej. hay
  /// solicitudes por revisar) — le da un borde de color para que el ojo
  /// vaya ahí primero, en vez de pesar lo mismo que una tarjeta puramente
  /// informativa.
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final interactiva = onTap != null;
    final colorInsignia = color ?? colors.primary;

    return AppCard(
      onTap: onTap,
      rippleColor: colorInsignia,
      border: destacado ? Border.all(color: colorInsignia, width: 1.5) : null,
      child: Stack(
        children: [
          Column(
            children: [
              IconBadge(icono: icono, color: colorInsignia),
              const SizedBox(height: AppSpacing.md),
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
    );
  }
}
