import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chofer_mobile_wrapper.dart';
import '../../widgets/sidebar_chofer.dart';
import 'chofer_home_screen.dart';
import 'mi_perfil_screen.dart';
import 'mis_solicitudes_screen.dart';
import 'subir_evidencias_screen.dart';

class ChoferHomeShell extends ConsumerStatefulWidget {
  const ChoferHomeShell({super.key});

  @override
  ConsumerState<ChoferHomeShell> createState() => _ChoferHomeShellState();
}

class _ChoferHomeShellState extends ConsumerState<ChoferHomeShell> {
  int _indice = 0;

  /// Las 4 páginas del IndexedStack — "Solicitar" no es una página,
  /// navega directamente a la ruta.
  static const _paginas = [
    ChoferHomeScreen(),
    SizedBox.shrink(), // Placeholder para índice 1 (Solicitar, nunca visible)
    MisSolicitudesScreen(mostrarComoTab: true),
    SubirEvidenciasScreen(mostrarComoTab: true),
    MiPerfilScreen(mostrarComoTab: true),
  ];

  void _onDestinationSelected(int index) {
    if (index == 1) {
      // "Solicitar" es navegación directa, no cambia el tab seleccionado.
      context.push(RoutePaths.choferTipoOperacion);
      return;
    }
    setState(() => _indice = index);
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esAncho = AppBreakpoints.isTabletOrDesktop(ancho);

    final paginas = IndexedStack(index: _indice, children: _paginas);

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
                indiceSeleccionado: _indice,
                onSeleccionar: _onDestinationSelected,
              ),
              Expanded(child: paginas),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: ChoferMobileWrapper(child: paginas)),
      bottomNavigationBar: _BottomNavChofer(
        indiceSeleccionado: _indice,
        onSeleccionar: _onDestinationSelected,
      ),
    );
  }
}

class _BottomNavChofer extends StatelessWidget {
  const _BottomNavChofer({
    required this.indiceSeleccionado,
    required this.onSeleccionar,
  });

  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return NavigationBar(
      selectedIndex: indiceSeleccionado,
      onDestinationSelected: onSeleccionar,
      backgroundColor: colors.surface,
      indicatorColor: colors.primary.withValues(alpha: 0.12),
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
    );
  }
}
