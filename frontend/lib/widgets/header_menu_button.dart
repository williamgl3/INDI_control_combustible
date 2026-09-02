import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_theme.dart';
import 'brand_header.dart';
import 'header_glass_button.dart';

/// Una opción del menú desplegable de [HeaderMenuButton].
class HeaderMenuItem {
  const HeaderMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  /// Pinta el ítem en `colors.error` (ej. "Cerrar sesión").
  final bool destructive;
}

/// Botón de "más opciones" (kebab) que despliega un menú tipo card sobre
/// [BrandHeader] — antes era un `PopupMenuButton` genérico sin tratamiento
/// visual propio. Fondo blanco, sombra elevada, ítems con ícono + texto y
/// hover, animación de entrada fade + slide, y se cierra solo al tocar
/// fuera (barrera translúcida en el overlay).
class HeaderMenuButton extends StatefulWidget {
  const HeaderMenuButton({
    super.key,
    required this.items,
    this.tooltip = 'Más opciones',
  });

  final List<HeaderMenuItem> items;
  final String tooltip;

  @override
  State<HeaderMenuButton> createState() => _HeaderMenuButtonState();
}

class _HeaderMenuButtonState extends State<HeaderMenuButton>
    with SingleTickerProviderStateMixin {
  final _link = LayerLink();
  final _overlayController = OverlayPortalController();
  late final AnimationController _animController;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // Creados aquí (no como inicializadores `late` perezosos): si el widget
    // llega a desmontarse antes de que `build()` los toque, un `late final`
    // los crearía recién en `dispose()`, y armar un ticker con `vsync: this`
    // ahí es inválido (el context ya está inactivo).
    _animController = AnimationController(
      vsync: this,
      duration: AppMotion.base,
    );
    _fade = CurvedAnimation(parent: _animController, curve: AppMotion.curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.06),
      end: Offset.zero,
    ).animate(_fade);
  }

  void _abrir() {
    _overlayController.show();
    _animController.forward(from: 0);
  }

  Future<void> _cerrar() async {
    await _animController.reverse();
    if (mounted) _overlayController.hide();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return CompositedTransformTarget(
      link: _link,
      child: OverlayPortal(
        controller: _overlayController,
        overlayChildBuilder: (context) {
          return CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.escape): () => _cerrar(),
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                children: [
                  // Barrera invisible: cierra el menú al tocar fuera de él.
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _cerrar,
                    ),
                  ),
                  CompositedTransformFollower(
                    link: _link,
                    targetAnchor: Alignment.bottomRight,
                    followerAnchor: Alignment.topRight,
                    offset: const Offset(0, 10),
                    child: FadeTransition(
                      opacity: _fade,
                      child: SlideTransition(
                        position: _slide,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Material(
                            color: Colors.transparent,
                            child: ConstrainedBox(
                              // 220 es el ancho mínimo (el que se ve bien con
                              // etiquetas cortas como "Tema"); `IntrinsicWidth`
                              // deja crecer la tarjeta si algún ítem trae una
                              // etiqueta más larga, en vez de partir de un
                              // ancho fijo que esa etiqueta pueda desbordar.
                              constraints: const BoxConstraints(minWidth: 220),
                              child: IntrinsicWidth(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: colors.surface,
                                    borderRadius: AppRadii.cardRadius,
                                    boxShadow: context.shadows.raised,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final item in widget.items)
                                        _MenuTile(
                                          item: item,
                                          onCerrar: _cerrar,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: HeaderGlassButton(
          icon: const Icon(Icons.menu, color: BrandHeader.onColor),
          tooltip: widget.tooltip,
          onPressed: _abrir,
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.item, required this.onCerrar});

  final HeaderMenuItem item;
  final Future<void> Function() onCerrar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = item.destructive ? colors.error : colors.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        hoverColor: colors.surfaceAlt,
        focusColor: colors.primary.withValues(alpha: 0.1),
        onTap: () async {
          await onCerrar();
          item.onTap();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(item.icon, size: 20, color: color),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
