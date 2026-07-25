import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth_controller.dart';
import '../../core/notificaciones_provider.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_section_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/header_glass_button.dart';
import '../../widgets/icon_badge.dart';
import '../../widgets/notificaciones_bell.dart';
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

/// Orden de navegación móvil: las 4 secciones que más se revisan quedan
/// fijas en la barra inferior (confirmado por el usuario), el resto vive
/// detrás de "Más" — antes las 8 secciones se apretujaban como íconos
/// sueltos sin espacio para las etiquetas, ahora es el mismo patrón de
/// Instagram/Gmail (N principales + "Más").
const _seccionesPrincipalesMovil = [
  _SeccionAdmin.autorizaciones,
  _SeccionAdmin.concentrado,
  _SeccionAdmin.finanzas,
  _SeccionAdmin.dashboard,
];

/// Shell del panel administrativo: sidebar en escritorio/tablet
/// (≥ [AppBreakpoints.tablet], con las 8 secciones) y bottom nav en móvil
/// (4 principales + "Más", ver [_seccionesPrincipalesMovil]) — decisión de
/// arquitectura confirmada por el usuario.
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

    // Cuántas solicitudes esperan revisión — se muestra como badge en la
    // sección "Autorizaciones" de la navegación, para verlo sin tener que
    // entrar primero.
    ref.watch(operacionesTickProvider);
    final pendientesAutorizaciones = ref
        .watch(operacionesRepositoryProvider)
        .todasLasSolicitudes
        .where((s) => s.estado == EstadoSolicitud.pendiente)
        .length;
    final destinoActual = _destinos[indiceSeleccionado];

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
              NotificacionesBell(
                provider: notificacionesAdminProvider,
                color: BrandHeader.onColor,
              ),
              const SizedBox(width: 8),
              HeaderGlassButton(
                tooltip: 'Tema',
                onPressed: () => SelectorTemaDialog.show(context),
                icon: const Icon(
                  Icons.brightness_6_outlined,
                  color: BrandHeader.onColor,
                ),
              ),
              const SizedBox(width: 8),
              HeaderGlassButton(
                tooltip: 'Cerrar sesión',
                onPressed: () => ref.read(authControllerProvider).logout(),
                icon: const Icon(Icons.logout, color: BrandHeader.onColor),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: _ResumenSeccionAdmin(
            destino: destinoActual,
            pendientesAutorizaciones: pendientesAutorizaciones,
          ),
        ),
        const SizedBox(height: 20),
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
                pendientesAutorizaciones: pendientesAutorizaciones,
                onSeleccionar: (i) =>
                    setState(() => _seccion = _destinos[i].seccion),
              ),
              Expanded(child: contenido),
            ],
          ),
        ),
      );
    }

    // Las 4 secciones más usadas quedan fijas en la barra; el resto vive
    // en la hoja "Más" (ver `_seccionesPrincipalesMovil`).
    final destinosPrincipales = _seccionesPrincipalesMovil
        .map((s) => _destinos.firstWhere((d) => d.seccion == s))
        .toList();
    final destinosEnMas = _destinos
        .where((d) => !_seccionesPrincipalesMovil.contains(d.seccion))
        .toList();
    final estaEnSeccionDeMas = destinosEnMas.any((d) => d.seccion == _seccion);
    final indiceBarraMovil = estaEnSeccionDeMas
        ? destinosPrincipales.length
        : destinosPrincipales.indexWhere((d) => d.seccion == _seccion);

    return Scaffold(
      body: SafeArea(child: contenido),
      bottomNavigationBar: NavigationBar(
        selectedIndex: indiceBarraMovil,
        onDestinationSelected: (i) {
          if (i == destinosPrincipales.length) {
            _abrirMasMovil(context, destinosEnMas);
            return;
          }
          setState(() => _seccion = destinosPrincipales[i].seccion);
        },
        destinations: [
          for (final d in destinosPrincipales)
            NavigationDestination(
              icon:
                  d.seccion == _SeccionAdmin.autorizaciones &&
                      pendientesAutorizaciones > 0
                  ? Badge(
                      label: Text('$pendientesAutorizaciones'),
                      child: Icon(d.icono),
                    )
                  : Icon(d.icono),
              label: d.etiqueta,
            ),
          const NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Más',
          ),
        ],
      ),
    );
  }

  /// Hoja con las secciones que no caben en la barra inferior — mismo
  /// patrón que Instagram/Gmail para apps con más de ~5 destinos.
  Future<void> _abrirMasMovil(
    BuildContext context,
    List<_Destino> destinos,
  ) async {
    final seccion = await showModalBottomSheet<_SeccionAdmin>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final d in destinos)
              ListTile(
                leading: IconBadge(icono: d.icono, color: d.color),
                title: Text(d.etiqueta),
                selected: d.seccion == _seccion,
                onTap: () => Navigator.of(context).pop(d.seccion),
              ),
          ],
        ),
      ),
    );
    if (seccion != null && mounted) setState(() => _seccion = seccion);
  }
}

class _ResumenSeccionAdmin extends StatelessWidget {
  const _ResumenSeccionAdmin({
    required this.destino,
    required this.pendientesAutorizaciones,
  });

  final _Destino destino;
  final int pendientesAutorizaciones;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: colors.border),
        boxShadow: context.shadows.card,
      ),
      child: Row(
        children: [
          IconBadge(icono: destino.icono, color: destino.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sección activa',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destino.etiqueta,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  'Usa la navegación lateral para cambiar rápido entre módulos.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                pendientesAutorizaciones.toString(),
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: colors.textPrimary),
              ),
              Text(
                'por revisar',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
              ),
            ],
          ),
        ],
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
    required this.pendientesAutorizaciones,
    required this.onSeleccionar,
  });

  final int indiceSeleccionado;
  final int pendientesAutorizaciones;
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
                    badge: _destinos[i].seccion == _SeccionAdmin.autorizaciones
                        ? pendientesAutorizaciones
                        : 0,
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
    this.badge = 0,
  });

  final _Destino destino;
  final bool seleccionado;
  final VoidCallback onTap;

  /// Conteo a mostrar como badge junto a la etiqueta (ej. solicitudes por
  /// revisar) — `0` u otro valor no positivo no muestra nada.
  final int badge;

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
                if (badge > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.error,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$badge',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
