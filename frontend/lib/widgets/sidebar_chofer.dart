import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/session_provider.dart';
import '../router/route_paths.dart';
import '../theme/app_radii.dart';
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

/// Los 5 destinos del panel de chofer, en el mismo orden que la barra
/// inferior móvil — índice 1 ("Solicitar") es navegación directa, no un
/// tab, tanto en `ChoferHomeShell` como en cualquier pantalla que use este
/// sidebar fuera del shell.
const destinosChofer = [
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
  DestinoChofer(
    icono: Icons.person_outline,
    iconoSeleccionado: Icons.person_rounded,
    etiqueta: 'Perfil',
  ),
];

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
  if (ruta == RoutePaths.choferPerfil) return 4;
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
  });

  final int indiceSeleccionado;
  final ValueChanged<int> onSeleccionar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final perfil = ref.watch(sessionProvider);

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
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                for (var i = 0; i < destinosChofer.length; i++)
                  _ItemSidebarChofer(
                    key: ValueKey('sidebar-chofer-destino-$i'),
                    destino: destinosChofer[i],
                    seleccionado: i == indiceSeleccionado,
                    onTap: () => onSeleccionar(i),
                  ),
              ],
            ),
          ),
          if (perfil != null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.sidebarSurfaceAlt,
                    child: Text(
                      perfil.nombreCompleto.isNotEmpty
                          ? perfil.nombreCompleto[0]
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
                      perfil.nombreCompleto,
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

class _ItemSidebarChofer extends StatelessWidget {
  const _ItemSidebarChofer({
    super.key,
    required this.destino,
    required this.seleccionado,
    required this.onTap,
  });

  final DestinoChofer destino;
  final bool seleccionado;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Material(
        color: seleccionado ? colorScheme.primary : Colors.transparent,
        borderRadius: AppRadii.navButtonRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadii.navButtonRadius,
          hoverColor: colorScheme.primary.withValues(alpha: 0.08),
          focusColor: colorScheme.primary.withValues(alpha: 0.12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: Icon(
                    seleccionado ? destino.iconoSeleccionado : destino.icono,
                    color: seleccionado
                        ? colorScheme.onPrimary
                        : colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    destino.etiqueta,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: seleccionado
                          ? colorScheme.onPrimary
                          : colorScheme.onSurface,
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

/// Navega desde el sidebar de una pantalla de chofer que vive **fuera**
/// del `IndexedStack` de `ChoferHomeShell` (ej. `TipoOperacionScreen`,
/// `SubirEvidenciasScreen` en su ruta standalone) hacia el destino
/// tocado.
///
/// `push`, no `go`, para todo excepto "Inicio": esas pantallas standalone
/// usan `context.pop()` en su propio botón de atrás — con `go` no queda
/// nada en el stack para hacer pop y truena con
/// `GoError: There is nothing to pop`. "Inicio" sí es la raíz del flujo
/// de chofer, así que usa `go` para no acumular pantallas en el stack.
/// Si ya se está en el destino tocado, no hace nada.
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
      context.push(RoutePaths.choferTipoOperacion);
    case 2:
      context.push(RoutePaths.choferSolicitudes);
    case 3:
      context.push(RoutePaths.choferSubirEvidencias);
    case 4:
      context.push(RoutePaths.choferPerfil);
  }
}
