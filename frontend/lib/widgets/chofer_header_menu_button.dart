import 'package:flutter/material.dart';

import '../theme/app_radii.dart';
import 'brand_header.dart';

class ChoferHeaderMenuItem {
  const ChoferHeaderMenuItem({
    required this.icon,
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onSelected;
  final bool destructive;
}

/// Menu Material 3 anclado al boton de opciones del encabezado del chofer.
/// PopupMenuButton aporta posicionamiento adaptativo, barrera, Escape,
/// boton Atras y restitucion de foco sin administrar overlays manualmente.
class ChoferHeaderMenuButton extends StatefulWidget {
  const ChoferHeaderMenuButton({super.key, required this.items});

  final List<ChoferHeaderMenuItem> items;

  @override
  State<ChoferHeaderMenuButton> createState() => _ChoferHeaderMenuButtonState();
}

class _ChoferHeaderMenuButtonState extends State<ChoferHeaderMenuButton> {
  bool _abierto = false;

  void _actualizarAbierto(bool valor) {
    if (mounted && _abierto != valor) setState(() => _abierto = valor);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reducirMovimiento = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      label: 'Abrir menú de opciones',
      button: true,
      expanded: _abierto,
      child: PopupMenuButton<ChoferHeaderMenuItem>(
        key: const ValueKey('chofer-header-menu-button'),
        tooltip: 'Más opciones',
        requestFocus: true,
        position: PopupMenuPosition.under,
        offset: const Offset(0, 8),
        constraints: const BoxConstraints(minWidth: 220, maxWidth: 260),
        menuPadding: const EdgeInsets.symmetric(vertical: 7),
        elevation: 8,
        color: scheme.surfaceContainer,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
        popUpAnimationStyle: reducirMovimiento
            ? AnimationStyle.noAnimation
            : const AnimationStyle(
                duration: Duration(milliseconds: 180),
                reverseDuration: Duration(milliseconds: 140),
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              ),
        onOpened: () => _actualizarAbierto(true),
        onCanceled: () => _actualizarAbierto(false),
        onSelected: (item) {
          _actualizarAbierto(false);
          item.onSelected();
        },
        itemBuilder: (context) {
          final entries = <PopupMenuEntry<ChoferHeaderMenuItem>>[];
          var separadorAgregado = false;
          for (final item in widget.items) {
            if (item.destructive && !separadorAgregado) {
              entries.add(
                const PopupMenuDivider(
                  key: ValueKey('chofer-menu-logout-divider'),
                  height: 9,
                ),
              );
              separadorAgregado = true;
            }
            final color = item.destructive ? scheme.error : scheme.onSurface;
            entries.add(
              PopupMenuItem<ChoferHeaderMenuItem>(
                key: ValueKey('chofer-menu-${item.label}'),
                value: item,
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(item.icon, size: 22, color: color),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodyLarge?.copyWith(color: color),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return entries;
        },
        icon: AnimatedRotation(
          turns: _abierto && !reducirMovimiento ? 0.015 : 0,
          duration: reducirMovimiento
              ? Duration.zero
              : const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: const Icon(
            Icons.more_vert_rounded,
            size: 24,
            color: BrandHeader.onColor,
          ),
        ),
        style: IconButton.styleFrom(
          fixedSize: const Size.square(48),
          minimumSize: const Size.square(48),
          padding: EdgeInsets.zero,
          backgroundColor: Colors.white.withValues(
            alpha: _abierto ? 0.24 : 0.14,
          ),
          foregroundColor: BrandHeader.onColor,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.22)),
          shape: const CircleBorder(),
          hoverColor: Colors.white.withValues(alpha: 0.12),
          focusColor: Colors.white.withValues(alpha: 0.24),
          overlayColor: Colors.white.withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
