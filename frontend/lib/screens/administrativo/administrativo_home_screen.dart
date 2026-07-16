import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_header.dart';
import 'tabs/autorizaciones_tab.dart';
import 'tabs/choferes_tab.dart';
import 'tabs/concentrado_tab.dart';
import 'tabs/finanzas_tab.dart';
import 'tabs/vehiculos_tab.dart';

enum _SeccionAdmin { autorizaciones, concentrado, finanzas, vehiculos, choferes }

class _Destino {
  const _Destino(this.seccion, this.icono, this.etiqueta);
  final _SeccionAdmin seccion;
  final IconData icono;
  final String etiqueta;
}

const _destinos = [
  _Destino(_SeccionAdmin.autorizaciones, Icons.assignment_outlined, 'Autorizaciones'),
  _Destino(_SeccionAdmin.concentrado, Icons.table_chart_outlined, 'Concentrado'),
  _Destino(_SeccionAdmin.finanzas, Icons.payments_outlined, 'Finanzas'),
  _Destino(_SeccionAdmin.vehiculos, Icons.local_shipping_outlined, 'Vehículos'),
  _Destino(_SeccionAdmin.choferes, Icons.groups_outlined, 'Choferes'),
];

/// Shell del panel administrativo: sidebar en escritorio/tablet
/// (≥ [AppBreakpoints.tablet]) y bottom nav en móvil, con 5 secciones —
/// decisión de arquitectura confirmada por el usuario.
class AdministrativoHomeScreen extends ConsumerStatefulWidget {
  const AdministrativoHomeScreen({super.key});

  @override
  ConsumerState<AdministrativoHomeScreen> createState() =>
      _AdministrativoHomeScreenState();
}

class _AdministrativoHomeScreenState extends ConsumerState<AdministrativoHomeScreen> {
  _SeccionAdmin _seccion = _SeccionAdmin.autorizaciones;

  Widget _cuerpoDe(_SeccionAdmin seccion) {
    switch (seccion) {
      case _SeccionAdmin.autorizaciones:
        return const AutorizacionesTab();
      case _SeccionAdmin.concentrado:
        return const ConcentradoTab();
      case _SeccionAdmin.finanzas:
        return const FinanzasTab();
      case _SeccionAdmin.vehiculos:
        return const VehiculosTab();
      case _SeccionAdmin.choferes:
        return const ChoferesTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ancho = MediaQuery.sizeOf(context).width;
    final esAncho = AppBreakpoints.isTabletOrDesktop(ancho);
    final indiceSeleccionado = _destinos.indexWhere((d) => d.seccion == _seccion);

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GradientHeader(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panel administrativo',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(color: colors.primaryOn),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'INDI Combustible · Control de combustible en obra',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colors.primaryOn.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: () => ref.read(authControllerProvider).logout(),
                icon: Icon(Icons.logout, color: colors.primaryOn),
              ),
            ],
          ),
        ),
        Expanded(child: _cuerpoDe(_seccion)),
      ],
    );

    if (esAncho) {
      return Scaffold(
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              NavigationRail(
                selectedIndex: indiceSeleccionado,
                onDestinationSelected: (i) => setState(() => _seccion = _destinos[i].seccion),
                labelType: NavigationRailLabelType.all,
                backgroundColor: colors.surface,
                destinations: _destinos
                    .map((d) => NavigationRailDestination(
                          icon: Icon(d.icono),
                          label: Text(d.etiqueta),
                        ))
                    .toList(),
              ),
              VerticalDivider(width: 1, color: colors.border),
              Expanded(child: contenido),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: contenido),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceSeleccionado,
        onDestinationSelected: (i) => setState(() => _seccion = _destinos[i].seccion),
        destinations: _destinos
            .map((d) => NavigationDestination(icon: Icon(d.icono), label: d.etiqueta))
            .toList(),
      ),
    );
  }
}
