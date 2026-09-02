import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import 'icon_badge.dart';
import 'pressable_scale.dart';

/// Contenedor de "lista agrupada" estilo iOS (Ajustes/Apps del sistema):
/// un solo rectángulo blanco de esquinas redondeadas que agrupa varias
/// filas, separadas por una línea fina — en vez de una card independiente
/// (con margen y sombra propios) por cada fila, como en la dirección
/// visual anterior.
///
/// [header] es un texto opcional en mayúsculas sobre el grupo (ej.
/// "VEHÍCULOS"), y [footer] un texto opcional debajo, ambos en el estilo
/// discreto de las secciones de Ajustes de iOS.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
  });

  final List<Widget> children;
  final String? header;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6),
            child: Text(
              header!.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colors.textMuted,
                letterSpacing: 0.4,
              ),
            ),
          ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.cardRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Divider(
                      height: 1,
                      thickness: 0.5,
                      color: colors.border,
                    ),
                  ),
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 6),
            child: Text(
              footer!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
            ),
          ),
      ],
    );
  }
}

/// Una fila dentro de [GroupedSection] — ícono opcional, título/subtítulo,
/// accesorio a la derecha (chevron, texto, badge) y `onTap` opcional.
/// Reemplaza el patrón anterior de "card individual con borde y sombra
/// por fila".
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.icono,
    this.iconoColor,
    this.trailing,
    this.onTap,
    this.destructivo = false,
  });

  final String titulo;
  final String? subtitulo;
  final IconData? icono;
  final Color? iconoColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructivo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorTitulo = destructivo ? colors.error : colors.textPrimary;

    final contenido = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (icono != null) ...[
            IconBadge(icono: icono!, color: iconoColor ?? colors.primary),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(color: colorTitulo),
                ),
                if (subtitulo != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitulo!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (onTap != null && trailing == null) ...[
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 18, color: colors.textMuted),
          ],
        ],
      ),
    );

    if (onTap == null) return contenido;

    return PressableScale(
      onTap: onTap,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: colors.surfaceAlt,
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.06),
          child: contenido,
        ),
      ),
    );
  }
}
