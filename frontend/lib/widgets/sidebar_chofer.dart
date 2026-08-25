import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session_provider.dart';
import '../models/perfil.dart';
import '../router/route_paths.dart';
import '../theme/app_radii.dart';
import '../theme/app_sizes.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Un destino de la navegación de chofer (compartido por [SidebarChofer] y
/// la barra inferior de `ChoferHomeShell`).
class DestinoChofer {
  const DestinoChofer({
    required this.icono,
    required this.iconoSeleccionado,
    required this.etiqueta,
  });

  final IconData icono;
  final IconData iconoSeleccionado;
  final String etiqueta;
}

/// Destinos operativos compartidos entre la navegación lateral y móvil.
const destinosOperativosChofer = [
  DestinoChofer(
    icono: Icons.home_outlined,
    iconoSeleccionado: Icons.home_rounded,
    etiqueta: 'Inicio',
  ),
  DestinoChofer(
    icono: Icons.local_gas_station_outlined,
    iconoSeleccionado: Icons.local_gas_station_rounded,
    etiqueta: 'Solicitar',
  ),
  DestinoChofer(
    icono: Icons.history_outlined,
    iconoSeleccionado: Icons.history_rounded,
    etiqueta: 'Historial',
  ),
  DestinoChofer(
    icono: Icons.camera_alt_outlined,
    iconoSeleccionado: Icons.camera_alt_rounded,
    etiqueta: 'Evidencias',
  ),
];

/// La navegación móvil conserva únicamente los destinos operativos. El
/// perfil se abre desde el avatar del shell, evitando un destino duplicado.
const destinosChofer = destinosOperativosChofer;

/// Devuelve el único destino activo para una ruta del módulo del chofer.
int indiceDestinoChoferParaRuta(String ruta) {
  if (ruta == RoutePaths.chofer || ruta == RoutePaths.choferDashboard) return 0;
  if (ruta == RoutePaths.choferTipoOperacion ||
      ruta == RoutePaths.choferRespuesta ||
      ruta.startsWith('${RoutePaths.choferSolicitar}/')) {
    return 1;
  }
  if (ruta == RoutePaths.choferSolicitudes ||
      ruta.startsWith('${RoutePaths.choferSolicitudes}/')) {
    return 2;
  }
  if (ruta == RoutePaths.choferSubirEvidencias ||
      ruta == RoutePaths.choferComprobar ||
      ruta == RoutePaths.choferCerrarDia) {
    return 3;
  }
  if (ruta == RoutePaths.choferPerfil) return 0;
  return 0;
}

/// Sidebar de escritorio/tablet para el flujo de chofer — mismo
/// tratamiento visual que `_SidebarAdmin` (panel administrativo), para que
/// la app se sienta como una sola aplicación de escritorio en vez de una
/// app de teléfono estirada, sin importar el rol.
///
/// Extraído a un widget compartido (antes vivía solo dentro de
/// `ChoferHomeShell`) para que pantallas empujadas por separado —fuera del
/// `IndexedStack` del shell, como `TipoOperacionScreen`— también puedan
/// mostrarlo, con su propia lógica de qué índice resaltar y hacia dónde
/// navegar al tocar un destino.
class SidebarChofer extends ConsumerWidget {
  const SidebarChofer({
    super.key,
    required this.indiceSeleccionado,
    required this.onSeleccionar,
    this.compacto = true,
    this.onToggle,
  });

  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;
  final bool compacto;
  final VoidCallback? onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final perfil = ref.watch(sessionProvider);

    return Container(
      width: compacto
          ? AppSizes.choferSidebarCollapsed
          : AppSizes.choferSidebarExpanded,
      color: colors.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onToggle != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: compacto ? Alignment.center : Alignment.centerRight,
                child: Semantics(
                  button: true,
                  toggled: !compacto,
                  label: compacto ? 'Expandir menú' : 'Contraer menú',
                  child: Tooltip(
                    message: compacto ? 'Expandir menú' : 'Contraer menú',
                    child: IconButton(
                      tooltip: null,
                      onPressed: onToggle,
                      icon: Icon(
                        compacto
                            ? Icons.chevron_right_rounded
                            : Icons.chevron_left_rounded,
                      ),
                      color: colors.sidebarText,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              children: [
                for (var i = 0; i < destinosOperativosChofer.length; i++)
                  _ItemSidebarChofer(
                    key: ValueKey('sidebar-chofer-destino-$i'),
                    destino: destinosOperativosChofer[i],
                    seleccionado: i == indiceSeleccionado,
                    compacto: compacto,
                    onTap: () => onSeleccionar(i),
                  ),
              ],
            ),
          ),
          if (perfil != null)
            _AccesoPerfilChofer(
              perfil: perfil,
              seleccionado: indiceSeleccionado == 4,
              compacto: compacto,
              onTap: () => onSeleccionar(4),
            ),
        ],
      ),
    );
  }
}

class _AccesoPerfilChofer extends StatelessWidget {
  const _AccesoPerfilChofer({
    required this.perfil,
    required this.seleccionado,
    required this.compacto,
    required this.onTap,
  });

  final Perfil perfil;
  final bool seleccionado;
  final bool compacto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final scheme = Theme.of(context).colorScheme;
    final nombre = perfil.nombreCompleto.trim();
    final inicial = nombre.isEmpty
        ? null
        : nombre.substring(0, 1).toUpperCase();
    const tooltip = 'Ver perfil';

    final avatar = Material(
      key: const ValueKey('sidebar-chofer-perfil'),
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

    final contenido = compacto
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
            key: const ValueKey('sidebar-chofer-perfil-fila'),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    avatar,
                    const SizedBox(width: 10),
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
          padding: compacto
              ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
              : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: compacto ? Center(child: contenido) : contenido,
        ),
      ),
    );
  }
}

class _ItemSidebarChofer extends StatelessWidget {
  const _ItemSidebarChofer({
    super.key,
    required this.destino,
    required this.seleccionado,
    required this.compacto,
    required this.onTap,
  });

  final DestinoChofer destino;
  final bool seleccionado;
  final bool compacto;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colorScheme = Theme.of(context).colorScheme;
    final colorContenido = seleccionado
        ? colorScheme.onPrimary
        : context.colors.sidebarTextMuted;
    final icono = Icon(
      seleccionado ? destino.iconoSeleccionado : destino.icono,
      color: colorContenido,
      size: 22,
    );

    final contenido = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: EdgeInsets.symmetric(
        horizontal: compacto ? 4 : 12,
        vertical: compacto ? 8 : 10,
      ),
      child: compacto
          ? Center(child: SizedBox.square(dimension: 26, child: icono))
          : Row(
              children: [
                SizedBox.square(dimension: 30, child: icono),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destino.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: seleccionado
                          ? colorScheme.onPrimary
                          : context.colors.sidebarText,
                      fontWeight: seleccionado
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: seleccionado ? colors.primaryHover : Colors.transparent,
        borderRadius: AppRadii.navButtonRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.navButtonRadius,
          hoverColor: colorScheme.primary.withValues(alpha: 0.08),
          focusColor: colorScheme.primary.withValues(alpha: 0.12),
          child: compacto
              ? Tooltip(message: destino.etiqueta, child: contenido)
              : contenido,
        ),
      ),
    );
  }
}

/// Navega desde el sidebar de una pantalla de chofer que vive **fuera**
/// del `IndexedStack` de `ChoferHomeShell` (ej. `TipoOperacionScreen`,
/// `SubirEvidenciasScreen` en su ruta standalone) hacia el destino
/// tocado.
///
/// Los destinos principales usan `go`: cambiar de sección no debe apilar
/// copias de Historial, Evidencias o Perfil. Las pantallas secundarias son
/// las que usan `push` y conservan un regreso jerárquico.
void navegarDesdeSidebarChofer(
  BuildContext context,
  int indiceActual,
  int indice,
) {
  if (indice == indiceActual) return;
  switch (indice) {
    case 0:
      context.go(RoutePaths.chofer);
    case 1:
      context.go(RoutePaths.choferTipoOperacion);
    case 2:
      context.go(RoutePaths.choferSolicitudes);
    case 3:
      context.go(RoutePaths.choferSubirEvidencias);
    case 4:
      context.go(RoutePaths.choferPerfil);
  }
}
