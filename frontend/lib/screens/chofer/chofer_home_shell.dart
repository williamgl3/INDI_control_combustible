import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../router/route_paths.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chofer_mobile_wrapper.dart';
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
      context.push(RoutePaths.choferSolicitar);
      return;
    }
    setState(() => _indice = index);
  }

  @override
  Widget build(BuildContext context) {
    final visibleIndex = _indice >= 1 ? _indice : _indice;

    return Scaffold(
      body: SafeArea(
        child: ChoferMobileWrapper(
          child: IndexedStack(
            index: visibleIndex,
            children: _paginas,
          ),
        ),
      ),
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
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home_rounded),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.local_gas_station_outlined),
          selectedIcon: Icon(Icons.local_gas_station_rounded),
          label: 'Solicitar',
        ),
        NavigationDestination(
          icon: Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history_rounded),
          label: 'Historial',
        ),
        NavigationDestination(
          icon: Icon(Icons.camera_alt_outlined),
          selectedIcon: Icon(Icons.camera_alt_rounded),
          label: 'Evidencias',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person_rounded),
          label: 'Perfil',
        ),
      ],
    );
  }
}
