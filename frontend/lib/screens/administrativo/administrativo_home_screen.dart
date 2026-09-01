import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/auth_controller.dart';
import '../../core/notificaciones_provider.dart';
import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../models/solicitud_autorizacion.dart';
import '../../router/route_paths.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_section_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_theme.dart';
import '../../widgets/acerca_de_dialog.dart';
import '../../widgets/ayuda_soporte_dialog.dart';
import '../../widgets/brand_header.dart';
import '../../widgets/confirmar_cerrar_sesion_dialog.dart';
import '../../widgets/header_glass_button.dart';
import '../../widgets/header_menu_button.dart';
import '../../widgets/logo_glass.dart';
import '../../widgets/notificaciones_bell.dart';
import '../../widgets/selector_tema_dialog.dart';
import '../chofer/mi_perfil_screen.dart';
import 'tabs/auditoria_tab.dart';
import 'tabs/autorizaciones_tab.dart';
import 'tabs/choferes_tab.dart';
import 'tabs/concentrado_tab.dart';
import 'tabs/dashboard_tab.dart';
import 'tabs/finanzas_tab.dart';
import 'tabs/mantenimiento_tab.dart';
import 'tabs/marimba_tab.dart';
import 'tabs/vehiculos_tab.dart';

enum _SeccionAdmin {
  dashboard,
  autorizaciones,
  concentrado,
  finanzas,
  vehiculos,
  mantenimiento,
  marimba,
  choferes,
  auditoria,
  perfil,
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
    _SeccionAdmin.marimba,
    Icons.local_shipping_outlined,
    'Marimba/Pipa',
    AppSectionColors.marimba,
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
  _Destino(
    _SeccionAdmin.perfil,
    Icons.person_outline,
    'Mi perfil',
    AppSectionColors.choferes,
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

const _etiquetasMoviles = {
  _SeccionAdmin.autorizaciones: 'Autorizar',
  _SeccionAdmin.concentrado: 'Resumen',
  _SeccionAdmin.finanzas: 'Finanzas',
  _SeccionAdmin.dashboard: 'Inicio',
};

const _descripcionSeccion = {
  _SeccionAdmin.dashboard: 'Vista general de la operación disponible.',
  _SeccionAdmin.autorizaciones: 'Revisa y atiende solicitudes de combustible.',
  _SeccionAdmin.concentrado: 'Consulta cargas, cierres y rendimientos.',
  _SeccionAdmin.finanzas: 'Consulta presupuesto y precios vigentes.',
  _SeccionAdmin.vehiculos: 'Administra el catálogo de unidades.',
  _SeccionAdmin.mantenimiento: 'Da seguimiento al estado de las unidades.',
  _SeccionAdmin.marimba: 'Consulta inventarios y recorridos de campo.',
  _SeccionAdmin.choferes: 'Consulta perfiles y actividad de choferes.',
  _SeccionAdmin.auditoria: 'Revisa el historial de acciones registradas.',
  _SeccionAdmin.perfil: 'Consulta tu cuenta y actualiza tu contraseña.',
};

const _gruposSidebar = <(String, List<_SeccionAdmin>)>[
  (
    'OPERACIÓN',
    [
      _SeccionAdmin.dashboard,
      _SeccionAdmin.autorizaciones,
      _SeccionAdmin.concentrado,
    ],
  ),
  (
    'CONTROL',
    [
      _SeccionAdmin.finanzas,
      _SeccionAdmin.vehiculos,
      _SeccionAdmin.mantenimiento,
      _SeccionAdmin.marimba,
    ],
  ),
  ('ADMINISTRACIÓN', [_SeccionAdmin.choferes, _SeccionAdmin.auditoria]),
];

/// Shell del panel administrativo: sidebar en escritorio/tablet
/// (≥ [AppBreakpoints.tablet], con las 8 secciones) y bottom nav en móvil
/// (4 principales + "Más", ver [_seccionesPrincipalesMovil]) — decisión de
/// arquitectura confirmada por el usuario.
class AdministrativoHomeScreen extends ConsumerStatefulWidget {
  const AdministrativoHomeScreen({
    super.key,
    this.mostrarMarimba = false,
    this.seccionInicial,
    this.solicitudIdInicial,
  });

  final bool mostrarMarimba;
  final String? seccionInicial;
  final String? solicitudIdInicial;

  @override
  ConsumerState<AdministrativoHomeScreen> createState() =>
      _AdministrativoHomeScreenState();
}

class _AdministrativoHomeScreenState
    extends ConsumerState<AdministrativoHomeScreen> {
  bool? _sidebarContraida;
  bool _cerrandoSesion = false;
  bool _procesandoLogout = false;
  final Set<_SeccionAdmin> _seccionesVisitadas = {_SeccionAdmin.autorizaciones};

  _SeccionAdmin get _seccion {
    if (widget.mostrarMarimba) return _SeccionAdmin.marimba;
    return _SeccionAdmin.values.firstWhere(
      (seccion) => seccion.name == widget.seccionInicial,
      orElse: () => _SeccionAdmin.autorizaciones,
    );
  }

  void _seleccionar(_SeccionAdmin seccion) {
    if (seccion == _SeccionAdmin.perfil) {
      context.go(RoutePaths.administrativoPerfil);
      return;
    }
    if (seccion == _SeccionAdmin.marimba) {
      context.go(RoutePaths.administrativoMarimba);
      return;
    }
    context.go(RoutePaths.administrativoSeccion(seccion.name));
  }

  /// Mismo patrón que en el panel de chofer (`ChoferHomeScreen`,
  /// `MiPerfilScreen`): confirma antes de cerrar sesión — antes este botón
  /// llamaba `logout()` directo, sin aviso, a diferencia del resto de la app.
  Future<void> _cerrarSesion() async {
    if (_cerrandoSesion) return;
    setState(() => _cerrandoSesion = true);
    try {
      final confirmado = await confirmarCerrarSesion(context);
      if (confirmado && mounted) {
        final router = GoRouter.of(context);
        setState(() => _procesandoLogout = true);
        await ref.read(authControllerProvider).logout();
        router.go(RoutePaths.login);
      }
    } finally {
      if (mounted) {
        setState(() {
          _cerrandoSesion = false;
          _procesandoLogout = false;
        });
      }
    }
  }

  Widget _cuerpoDe(_SeccionAdmin seccion) {
    switch (seccion) {
      case _SeccionAdmin.dashboard:
        return const DashboardTab();
      case _SeccionAdmin.autorizaciones:
        return AutorizacionesTab(solicitudIdInicial: widget.solicitudIdInicial);
      case _SeccionAdmin.concentrado:
        return const ConcentradoTab();
      case _SeccionAdmin.finanzas:
        return const FinanzasTab();
      case _SeccionAdmin.vehiculos:
        return const VehiculosTab();
      case _SeccionAdmin.mantenimiento:
        return const MantenimientoTab();
      case _SeccionAdmin.marimba:
        return const MarimbaTab();
      case _SeccionAdmin.choferes:
        return const ChoferesTab();
      case _SeccionAdmin.auditoria:
        return const AuditoriaTab();
      case _SeccionAdmin.perfil:
        return const MiPerfilScreen(
          mostrarComoTab: true,
          mostrarCerrarSesion: false,
        );
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
    final sidebarContraida = _sidebarContraida ?? ancho < 1200;
    _seccionesVisitadas.add(_seccion);

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrandHeader(
          padding: EdgeInsets.symmetric(
            horizontal: esAncho ? AppSpacing.xxl : AppSpacing.lg,
            vertical: esAncho ? AppSpacing.lg : AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IndiLogo(width: internalHeaderLogoWidth(ancho)),
              SizedBox(width: internalHeaderLogoGap(ancho)),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Panel administrativo',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: BrandHeader.onColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      destinoActual.etiqueta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: BrandHeader.onColor,
                      ),
                    ),
                    if (esAncho) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        _descripcionSeccion[destinoActual.seccion]!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: BrandHeader.onColorMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              NotificacionesBell(
                provider: notificacionesAdminProvider,
                color: BrandHeader.onColor,
                onNotificationTap: (notificacion) {
                  if (notificacion.solicitudId == null) return;
                  context.go(
                    RoutePaths.administrativoAutorizacion(
                      solicitudId: notificacion.solicitudId,
                    ),
                  );
                },
              ),
              if (esAncho) ...[
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
                  onPressed: _cerrandoSesion ? null : _cerrarSesion,
                  icon: _procesandoLogout
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BrandHeader.onColor,
                          ),
                        )
                      : const Icon(Icons.logout, color: BrandHeader.onColor),
                ),
              ],
              const SizedBox(width: 8),
              HeaderMenuButton(
                items: [
                  if (!esAncho) ...[
                    HeaderMenuItem(
                      icon: Icons.brightness_6_outlined,
                      label: 'Tema',
                      onTap: () => SelectorTemaDialog.show(context),
                    ),
                    HeaderMenuItem(
                      icon: Icons.logout,
                      label: 'Cerrar sesión',
                      onTap: _cerrarSesion,
                      destructive: true,
                    ),
                  ],
                  HeaderMenuItem(
                    icon: Icons.info_outline,
                    label: 'Acerca de',
                    onTap: () => AcercaDeDialog.show(context),
                  ),
                  HeaderMenuItem(
                    icon: Icons.help_outline,
                    label: 'Ayuda y soporte',
                    onTap: () => AyudaSoporteDialog.show(context),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _seccion.index,
            children: [
              for (final seccion in _SeccionAdmin.values)
                KeyedSubtree(
                  key: ValueKey(seccion),
                  child: _seccionesVisitadas.contains(seccion)
                      ? _cuerpoDe(seccion)
                      : const SizedBox.shrink(),
                ),
            ],
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
                compacto: sidebarContraida,
                onCambiarModo: () =>
                    setState(() => _sidebarContraida = !sidebarContraida),
                onSeleccionar: _seleccionar,
                perfilSeleccionado: _seccion == _SeccionAdmin.perfil,
                onAbrirPerfil: () => _seleccionar(_SeccionAdmin.perfil),
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
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 68,
          indicatorColor: Colors.transparent,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              size: 23,
              color: states.contains(WidgetState.selected)
                  ? Theme.of(context).colorScheme.primary
                  : context.colors.textSecondary,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => Theme.of(context).textTheme.labelSmall?.copyWith(
              color: states.contains(WidgetState.selected)
                  ? Theme.of(context).colorScheme.primary
                  : context.colors.textSecondary,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: indiceBarraMovil,
          onDestinationSelected: (i) {
            if (i == destinosPrincipales.length) {
              _abrirMasMovil(context, destinosEnMas);
              return;
            }
            _seleccionar(destinosPrincipales[i].seccion);
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
                label: _etiquetasMoviles[d.seccion]!,
              ),
            const NavigationDestination(
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'Más',
            ),
          ],
        ),
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
                leading: Icon(
                  d.icono,
                  color: d.seccion == _seccion
                      ? context.colors.primary
                      : context.colors.textSecondary,
                ),
                title: Text(d.etiqueta),
                selected: d.seccion == _seccion,
                onTap: () => Navigator.of(context).pop(d.seccion),
              ),
          ],
        ),
      ),
    );
    if (seccion != null && mounted) _seleccionar(seccion);
  }
}

/// Sidebar claro del panel administrativo (escritorio/tablet), estilo el
/// panel maestro de Ajustes en iPad — marca + navegación + el admin en
/// sesión, en vez del `NavigationRail` por defecto de Material.
class _SidebarAdmin extends ConsumerWidget {
  const _SidebarAdmin({
    required this.indiceSeleccionado,
    required this.pendientesAutorizaciones,
    required this.compacto,
    required this.onCambiarModo,
    required this.onSeleccionar,
    required this.perfilSeleccionado,
    required this.onAbrirPerfil,
  });

  final int indiceSeleccionado;
  final int pendientesAutorizaciones;
  final bool compacto;
  final VoidCallback onCambiarModo;
  final ValueChanged<_SeccionAdmin> onSeleccionar;
  final bool perfilSeleccionado;
  final VoidCallback onAbrirPerfil;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final admin = ref.watch(sessionProvider);

    return Container(
      key: const ValueKey('sidebar-administrativo'),
      width: compacto ? 76 : 240,
      color: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compacto ? AppSpacing.sm : AppSpacing.lg,
              AppSpacing.lg,
              compacto ? AppSpacing.sm : AppSpacing.md,
              AppSpacing.md,
            ),
            child: Align(
              alignment: compacto ? Alignment.center : Alignment.centerRight,
              child: IconButton(
                tooltip: compacto
                    ? 'Expandir navegación'
                    : 'Contraer navegación',
                onPressed: onCambiarModo,
                icon: Icon(compacto ? Icons.chevron_right : Icons.chevron_left),
                color: colors.sidebarText,
              ),
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
                for (final grupo in _gruposSidebar) ...[
                  if (compacto)
                    const Divider(height: AppSpacing.lg)
                  else
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.xxl,
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: Text(
                        grupo.$1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colors.sidebarTextMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  for (final seccion in grupo.$2)
                    _ItemSidebar(
                      destino: _destinos.firstWhere(
                        (destino) => destino.seccion == seccion,
                      ),
                      seleccionado:
                          _destinos[indiceSeleccionado].seccion == seccion,
                      compacto: compacto,
                      badge: seccion == _SeccionAdmin.autorizaciones
                          ? pendientesAutorizaciones
                          : 0,
                      onTap: () => onSeleccionar(seccion),
                    ),
                ],
              ],
            ),
          ),
          if (admin != null)
            _AccesoPerfilAdmin(
              nombreCompleto: admin.nombreCompleto,
              compacto: compacto,
              seleccionado: perfilSeleccionado,
              onTap: onAbrirPerfil,
            ),
        ],
      ),
    );
  }
}

class _AccesoPerfilAdmin extends StatelessWidget {
  const _AccesoPerfilAdmin({
    required this.nombreCompleto,
    required this.compacto,
    required this.seleccionado,
    required this.onTap,
  });

  final String nombreCompleto;
  final bool compacto;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final nombre = nombreCompleto.trim();
    final inicial = nombre.isEmpty
        ? null
        : nombre.substring(0, 1).toUpperCase();
    final tooltip = nombre.isEmpty
        ? 'Abrir perfil'
        : 'Perfil de ${nombre.split(RegExp(r'\s+')).first}';
    final avatar = Material(
      key: const ValueKey('sidebar-admin-perfil-avatar'),
      color: seleccionado ? scheme.primary : colors.sidebarSurfaceAlt,
      shape: CircleBorder(
        side: BorderSide(
          color: seleccionado
              ? scheme.onPrimary.withValues(alpha: 0.8)
              : colors.sidebarTextMuted.withValues(alpha: 0.35),
          width: seleccionado ? 2 : 1,
        ),
      ),
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: inicial == null
              ? Icon(
                  Icons.person_outline,
                  size: 24,
                  color: seleccionado ? scheme.onPrimary : colors.sidebarText,
                )
              : Text(
                  inicial,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: seleccionado ? scheme.onPrimary : colors.sidebarText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );

    final child = compacto
        ? Material(
            color: Colors.transparent,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              customBorder: const CircleBorder(),
              hoverColor: scheme.primary.withValues(alpha: 0.16),
              focusColor: scheme.primary.withValues(alpha: 0.22),
              child: avatar,
            ),
          )
        : Material(
            key: const ValueKey('sidebar-admin-perfil-fila'),
            color: seleccionado
                ? scheme.primary.withValues(alpha: 0.14)
                : Colors.transparent,
            borderRadius: AppRadii.navButtonRadius,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              borderRadius: AppRadii.navButtonRadius,
              hoverColor: scheme.primary.withValues(alpha: 0.12),
              focusColor: scheme.primary.withValues(alpha: 0.16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        nombre.isEmpty ? 'Perfil' : nombre,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: seleccionado
                              ? colors.sidebarText
                              : colors.sidebarTextMuted,
                          fontWeight: seleccionado
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

    return Semantics(
      button: true,
      selected: seleccionado,
      label: 'Abrir perfil',
      child: Tooltip(
        message: tooltip,
        child: Padding(
          padding: EdgeInsets.all(compacto ? AppSpacing.md : AppSpacing.lg),
          child: compacto ? Center(child: child) : child,
        ),
      ),
    );
  }
}

class _ItemSidebar extends StatelessWidget {
  const _ItemSidebar({
    required this.destino,
    required this.seleccionado,
    required this.onTap,
    required this.compacto,
    this.badge = 0,
  });

  final _Destino destino;
  final bool seleccionado;
  final VoidCallback onTap;
  final bool compacto;

  /// Conteo a mostrar como badge junto a la etiqueta (ej. solicitudes por
  /// revisar) — `0` u otro valor no positivo no muestra nada.
  final int badge;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? AppSpacing.sm : AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Tooltip(
        message: compacto ? destino.etiqueta : '',
        child: Material(
          key: ValueKey('admin-destino-${destino.seccion.name}'),
          color: seleccionado ? colors.primaryHover : Colors.transparent,
          borderRadius: AppRadii.navButtonRadius,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadii.navButtonRadius,
            hoverColor: colors.sidebarSurfaceAlt,
            focusColor: colors.primary.withValues(alpha: 0.22),
            child: Semantics(
              selected: seleccionado,
              button: true,
              label: destino.etiqueta,
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: EdgeInsets.symmetric(
                  horizontal: compacto ? AppSpacing.sm : AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: compacto
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  children: [
                    Badge(
                      isLabelVisible: compacto && badge > 0,
                      label: Text('$badge'),
                      child: SizedBox.square(
                        dimension: 30,
                        child: Icon(
                          destino.icono,
                          size: 22,
                          color: seleccionado
                              ? colors.primaryOn
                              : colors.sidebarTextMuted,
                        ),
                      ),
                    ),
                    if (!compacto) ...[
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          destino.etiqueta,
                          maxLines: 1,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: seleccionado
                                    ? colors.primaryOn
                                    : colors.sidebarText,
                                fontWeight: seleccionado
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                        ),
                      ),
                      if (badge > 0) ...[
                        const SizedBox(width: AppSpacing.sm),
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
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.primaryOn,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
