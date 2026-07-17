import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/session_provider.dart';
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
              _SidebarAdmin(
                indiceSeleccionado: indiceSeleccionado,
                onSeleccionar: (i) => setState(() => _seccion = _destinos[i].seccion),
              ),
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

/// Sidebar oscuro del panel administrativo (escritorio/tablet) — marca +
/// navegación + el admin en sesión, en vez del `NavigationRail` claro por
/// defecto de Material.
class _SidebarAdmin extends ConsumerWidget {
  const _SidebarAdmin({required this.indiceSeleccionado, required this.onSeleccionar});

  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final admin = ref.watch(sessionProvider);

    return Container(
      width: 240,
      color: colors.sidebarBackground,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [colors.info, colors.primary]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.local_gas_station, color: colors.primaryOn, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'INDI Combustible',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: colors.sidebarText),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < _destinos.length; i++)
            _ItemSidebar(
              destino: _destinos[i],
              seleccionado: i == indiceSeleccionado,
              onTap: () => onSeleccionar(i),
            ),
          const Spacer(),
          if (admin != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.sidebarSurfaceAlt,
                    child: Text(
                      admin.nombreCompleto.isNotEmpty ? admin.nombreCompleto[0] : '?',
                      style: TextStyle(color: colors.sidebarText, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      admin.nombreCompleto,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: colors.sidebarTextMuted),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ItemSidebar extends StatelessWidget {
  const _ItemSidebar({required this.destino, required this.seleccionado, required this.onTap});

  final _Destino destino;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: seleccionado ? colors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(
                  destino.icono,
                  size: 20,
                  color: seleccionado ? colors.primaryOn : colors.sidebarTextMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destino.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: seleccionado ? colors.primaryOn : colors.sidebarText,
                          fontWeight: seleccionado ? FontWeight.w700 : FontWeight.w500,
                        ),
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
