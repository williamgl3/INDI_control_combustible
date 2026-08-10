import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_breakpoints.dart';
import '../../widgets/chofer_mobile_wrapper.dart';
import '../../widgets/sidebar_chofer.dart';
import 'chofer_home_screen.dart';

class ChoferHomeShell extends ConsumerWidget {
  const ChoferHomeShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esAncho = AppBreakpoints.isTabletOrDesktop(ancho);
    final ruta = GoRouterState.of(context).uri.path;
    final indice = indiceDestinoChoferParaRuta(ruta);
    void seleccionar(int destino) =>
        navegarDesdeSidebarChofer(context, indice, destino);

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
              SidebarChofer(
                indiceSeleccionado: indice,
                onSeleccionar: seleccionar,
              ),
              const Expanded(child: ChoferHomeScreen()),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: const SafeArea(
        child: ChoferMobileWrapper(child: ChoferHomeScreen()),
      ),
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
        indicatorColor: colorScheme.primary,
        indicatorShape: const StadiumBorder(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onPrimary
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
          for (final d in destinosChofer)
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
