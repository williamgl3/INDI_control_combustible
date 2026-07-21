import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/session_provider.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_section_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/selector_tema_dialog.dart';
import 'tabs/auditoria_tab.dart';
import 'tabs/autorizaciones_tab.dart';
import 'tabs/choferes_tab.dart';
import 'tabs/concentrado_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/finanzas_tab.dart';
import 'tabs/mantenimiento_tab.dart';
import 'tabs/vehiculos_tab.dart';

enum _SeccionAdmin {
  dashboard,
  autorizaciones,
  concentrado,
  finanzas,
  vehiculos,
  mantenimiento,
  choferes,
  auditoria,
}

class _Destino {
  const _Destino(this.seccion, this.icono, this.etiqueta, this.color);
  final _SeccionAdmin seccion;
  final IconData icono;
  final String etiqueta;
  final Color color;
}

const _destinos = [
  _Destino(
    _SeccionAdmin.dashboard,
    Icons.insights_outlined,
    'Dashboard',
    AppSectionColors.dashboard,
  ),
  _Destino(
    _SeccionAdmin.autorizaciones,
    Icons.assignment_outlined,
    'Autorizaciones',
    AppSectionColors.autorizaciones,
  ),
  _Destino(
    _SeccionAdmin.concentrado,
    Icons.table_chart_outlined,
    'Concentrado',
    AppSectionColors.concentrado,
  ),
  _Destino(
    _SeccionAdmin.finanzas,
    Icons.payments_outlined,
    'Finanzas',
    AppSectionColors.finanzas,
  ),
  _Destino(
    _SeccionAdmin.vehiculos,
    Icons.local_shipping_outlined,
    'Vehículos',
    AppSectionColors.vehiculos,
  ),
  _Destino(
    _SeccionAdmin.mantenimiento,
    Icons.build_outlined,
    'Mantenimiento',
    AppSectionColors.mantenimiento,
  ),
  _Destino(
    _SeccionAdmin.choferes,
    Icons.groups_outlined,
    'Choferes',
    AppSectionColors.choferes,
  ),
  _Destino(
    _SeccionAdmin.auditoria,
    Icons.history_outlined,
    'Auditoría',
    AppSectionColors.auditoria,
  ),
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

class _AdministrativoHomeScreenState
    extends ConsumerState<AdministrativoHomeScreen> {
  _SeccionAdmin _seccion = _SeccionAdmin.autorizaciones;

  Widget _cuerpoDe(_SeccionAdmin seccion) {
    switch (seccion) {
      case _SeccionAdmin.dashboard:
        return const DashboardTab();
      case _SeccionAdmin.autorizaciones:
        return const AutorizacionesTab();
      case _SeccionAdmin.concentrado:
        return const ConcentradoTab();
      case _SeccionAdmin.finanzas:
        return const FinanzasTab();
      case _SeccionAdmin.vehiculos:
        return const VehiculosTab();
      case _SeccionAdmin.mantenimiento:
        return const MantenimientoTab();
      case _SeccionAdmin.choferes:
        return const ChoferesTab();
      case _SeccionAdmin.auditoria:
        return const AuditoriaTab();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final esAncho = AppBreakpoints.isTabletOrDesktop(ancho);
    final indiceSeleccionado = _destinos.indexWhere(
      (d) => d.seccion == _seccion,
    );

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrandHeader(
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
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: BrandHeader.onColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'INDI Combustible · Control de combustible en obra',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BrandHeader.onColorMuted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Tema',
                onPressed: () => SelectorTemaDialog.show(context),
                icon: const Icon(
                  Icons.brightness_6_outlined,
                  color: BrandHeader.onColor,
                ),
              ),
              IconButton(
                tooltip: 'Cerrar sesión',
                onPressed: () => ref.read(authControllerProvider).logout(),
                icon: const Icon(Icons.logout, color: BrandHeader.onColor),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.02),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: KeyedSubtree(
              key: ValueKey(_seccion),
              child: _cuerpoDe(_seccion),
            ),
          ),
        ),
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
                onSeleccionar: (i) =>
                    setState(() => _seccion = _destinos[i].seccion),
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
        // Con 7 secciones, mostrar las 7 etiquetas a la vez no cabe en un
        // teléfono angosto (se cortan/superponen) — solo la sección activa
        // muestra su etiqueta, el resto queda solo con el ícono.
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        onDestinationSelected: (i) =>
            setState(() => _seccion = _destinos[i].seccion),
        destinations: _destinos
            .map(
              (d) =>
                  NavigationDestination(icon: Icon(d.icono), label: d.etiqueta),
            )
            .toList(),
      ),
    );
  }
}

/// Sidebar claro del panel administrativo (escritorio/tablet), estilo el
/// panel maestro de Ajustes en iPad — marca + navegación + el admin en
/// sesión, en vez del `NavigationRail` por defecto de Material.
class _SidebarAdmin extends ConsumerWidget {
  const _SidebarAdmin({
    required this.indiceSeleccionado,
    required this.onSeleccionar,
  });

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
                ClipRRect(
                  borderRadius: AppRadii.inputRadius,
                  child: Image.asset(
                    'assets/images/logo_indi.jpeg',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'INDI Combustible',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colors.sidebarText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          // `Expanded` + `ListView` en vez de una lista fija: con 8
          // secciones, una ventana baja (o el viewport chico de los
          // tests de widgets) ya no alcanza a mostrarlas todas sin
          // hacer scroll — antes, con menos secciones, cabían siempre.
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < _destinos.length; i++)
                  _ItemSidebar(
                    destino: _destinos[i],
                    seleccionado: i == indiceSeleccionado,
                    onTap: () => onSeleccionar(i),
                  ),
              ],
            ),
          ),
          if (admin != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.sidebarSurfaceAlt,
                    child: Text(
                      admin.nombreCompleto.isNotEmpty
                          ? admin.nombreCompleto[0]
                          : '?',
                      style: TextStyle(
                        color: colors.sidebarText,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      admin.nombreCompleto,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.sidebarTextMuted,
                      ),
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
  const _ItemSidebar({
    required this.destino,
    required this.seleccionado,
    required this.onTap,
  });

  final _Destino destino;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: seleccionado
            ? destino.color.withValues(alpha: 0.12)
            : Colors.transparent,
        borderRadius: AppRadii.navButtonRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.navButtonRadius,
          hoverColor: colors.sidebarSurfaceAlt.withValues(alpha: 0.6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                IconBadge(
                  icono: destino.icono,
                  color: destino.color,
                  size: 30,
                  iconSize: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destino.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: seleccionado
                          ? destino.color
                          : colors.sidebarTextMuted,
                      fontWeight: seleccionado
                          ? FontWeight.w700
                          : FontWeight.w500,
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
