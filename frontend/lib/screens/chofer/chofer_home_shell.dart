import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_sizes.dart';
import '../../widgets/chofer_mobile_wrapper.dart';
import '../../widgets/sidebar_chofer.dart';

class ChoferHomeShell extends ConsumerStatefulWidget {
  const ChoferHomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  ConsumerState<ChoferHomeShell> createState() => _ChoferHomeShellState();
}

class _ChoferHomeShellState extends ConsumerState<ChoferHomeShell> {
  bool _sidebarExpanded = false;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esAncho = AppBreakpoints.isTabletOrDesktop(ancho);
    final puedeExpandir = ancho >= AppBreakpoints.desktop;
    final sidebarExpandido = puedeExpandir && _sidebarExpanded;
    final indice = esAncho
        ? switch (widget.navigationShell.currentIndex) {
            0 => 0,
            1 => 2,
            2 => 3,
            3 => 4,
            _ => 0,
          }
        : widget.navigationShell.currentIndex;
    void seleccionar(int destino) {
      if (esAncho) {
        if (destino == 1) {
          context.push(RoutePaths.choferTipoOperacion);
          return;
        }
        final indiceRama = switch (destino) {
          0 => 0,
          2 => 1,
          3 => 2,
          4 => 3,
          _ => 0,
        };
        widget.navigationShell.goBranch(
          indiceRama,
          initialLocation: indiceRama == widget.navigationShell.currentIndex,
        );
      } else {
        widget.navigationShell.goBranch(
          destino,
          initialLocation: destino == widget.navigationShell.currentIndex,
        );
      }
    }

    if (esAncho) {
      // Sin `ChoferMobileWrapper` aquí: con el sidebar ya dando la
      // experiencia de escritorio, envolver el contenido en el simulador
      // de "ancho de teléfono" (480px) lo apretaba a todos por igual
      // -incluido Inicio-, solo que se notaba menos ahí que en
      // Historial/Evidencias. Cada pantalla controla su propio ancho
      // máximo con `ResponsiveScrollView` (mismo criterio en las 4).
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(
                        milliseconds: AppSizes.choferSidebarAnimationMs,
                      ),
                curve: Curves.easeOutCubic,
                width: sidebarExpandido
                    ? AppSizes.choferSidebarExpanded
                    : AppSizes.choferSidebarCollapsed,
                child: SidebarChofer(
                  indiceSeleccionado: indice,
                  onSeleccionar: seleccionar,
                  compacto: !sidebarExpandido,
                  onToggle: puedeExpandir
                      ? () =>
                            setState(() => _sidebarExpanded = !_sidebarExpanded)
                      : null,
                ),
              ),
              Expanded(child: widget.navigationShell),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: ChoferMobileWrapper(child: widget.navigationShell)),
      bottomNavigationBar: NavegacionInferiorChofer(
        indiceSeleccionado: indice,
        onSeleccionar: seleccionar,
      ),
    );
  }
}

class NavegacionInferiorChofer extends StatelessWidget {
  const NavegacionInferiorChofer({
    super.key,
    required this.indiceSeleccionado,
    required this.onSeleccionar,
  });

  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final seleccionada = states.contains(WidgetState.selected);
          return Theme.of(context).textTheme.labelMedium?.copyWith(
            color: seleccionada ? colorScheme.primary : colorScheme.onSurface,
            fontWeight: seleccionada ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return colorScheme.primary.withValues(alpha: 0.08);
          }
          return Colors.transparent;
        }),
      ),
      child: NavigationBar(
        selectedIndex: indiceSeleccionado,
        onDestinationSelected: onSeleccionar,
        backgroundColor: colorScheme.surface,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          for (final d in destinosNavegacionInferiorChofer)
            NavigationDestination(
              icon: Icon(d.icono),
              selectedIcon: Icon(d.iconoSeleccionado),
              label: d.etiqueta,
            ),
        ],
      ),
    );
  }
}
