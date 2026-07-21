import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/session_provider.dart';
import '../../../data/auth_repository.dart';
import '../../../models/perfil.dart';
import '../../../router/route_paths.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/confirmar_accion_dialog.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/responsive_scroll_view.dart';
import '../../../widgets/stat_tile.dart';
import '../crear_administrador_dialog.dart';
import '../resetear_password_dialog.dart';

/// Pestaña "Choferes": directorio de choferes registrados, cada uno con
/// acceso a su historial completo (solicitudes + cargas). También permite
/// activar/desactivar cuentas, resetear contraseñas, y dar de alta nuevos
/// usuarios administrativos.
class ChoferesTab extends ConsumerStatefulWidget {
  const ChoferesTab({super.key});

  @override
  ConsumerState<ChoferesTab> createState() => _ChoferesTabState();
}

class _ChoferesTabState extends ConsumerState<ChoferesTab> {
  String? _accionEnCurso;

  Future<void> _verDetalle(Perfil chofer) async {
    await context.push(RoutePaths.administrativoChoferDetalle, extra: chofer);
    if (mounted) setState(() {}); // por si se editó el tope desde el detalle
  }

  Future<void> _crearAdministrador() async {
    final creado = await CrearAdministradorDialog.show(context);
    if (creado == true && mounted) setState(() {});
  }

  Future<void> _resetearPassword(Perfil usuario) async {
    await ResetearPasswordDialog.show(context, usuario: usuario);
  }

  Future<void> _cambiarEstado(Perfil usuario) async {
    final activar = !usuario.activo;
    final confirmado = await ConfirmarAccionDialog.show(
      context,
      titulo: activar ? 'Reactivar cuenta' : 'Desactivar cuenta',
      mensaje: activar
          ? '¿Reactivar a ${usuario.nombreCompleto}? Podrá iniciar sesión de nuevo.'
          : '¿Desactivar a ${usuario.nombreCompleto}? No podrá iniciar sesión '
                'hasta que se reactive su cuenta.',
      textoConfirmar: activar ? 'Reactivar' : 'Desactivar',
      destructivo: !activar,
    );
    if (!confirmado) return;

    setState(() => _accionEnCurso = usuario.id);
    try {
      await ref
          .read(authRepositoryProvider)
          .cambiarEstado(usuarioId: usuario.id, activo: activar);
    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _accionEnCurso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final choferes = ref.watch(authRepositoryProvider).listarChoferes();
    final sesion = ref.watch(sessionProvider);
    ref.watch(operacionesTickProvider);

    return ResponsiveScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choferes',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Directorio de choferes registrados en la obra.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: _crearAdministrador,
                icon: const Icon(Icons.admin_panel_settings_outlined),
                label: const Text('Crear administrador'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 200,
              child: StatTile(
                icono: Icons.groups_outlined,
                valor: '${choferes.length}',
                etiqueta: 'Choferes',
                color: AppSectionColors.choferes,
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (choferes.isEmpty)
            const EstadoVacio(
              icono: Icons.groups_outlined,
              mensaje: 'Aún no hay choferes registrados.',
            )
          else
            GroupedSection(
              header: 'Directorio',
              children: [
                for (final c in choferes)
                  GroupedRow(
                    titulo: c.nombreCompleto,
                    subtitulo: '@${c.usuario}',
                    icono: Icons.person_outline,
                    iconoColor: AppSectionColors.choferes,
                    onTap: () => _verDetalle(c),
                    trailing: _accionEnCurso == c.id
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!c.activo) ...[
                                _BadgeInactivo(),
                                const SizedBox(width: 8),
                              ],
                              _MenuAccionesUsuario(
                                // Key determinística por usuario — permite
                                // ubicar el menú de una fila específica en
                                // pruebas de widgets sin depender de
                                // finders ambiguos (ej. tooltips
                                // duplicados cuando hay varias filas).
                                key: ValueKey('acciones-${c.id}'),
                                usuario: c,
                                esSesionActual: sesion?.id == c.id,
                                onResetearPassword: () =>
                                    _resetearPassword(c),
                                onCambiarEstado: () => _cambiarEstado(c),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _BadgeInactivo extends StatelessWidget {
  const _BadgeInactivo();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.error.withValues(alpha: 0.14),
        borderRadius: AppRadii.badgeRadius,
      ),
      child: Text(
        'INACTIVO',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colors.error,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

enum _AccionUsuario { resetearPassword, cambiarEstado }

/// Menú de acciones sobre un usuario (chofer o administrativo). Oculta
/// "Desactivar" para la fila del propio usuario en sesión — un admin no
/// debe poder desactivarse a sí mismo desde la UI.
class _MenuAccionesUsuario extends StatelessWidget {
  const _MenuAccionesUsuario({
    super.key,
    required this.usuario,
    required this.esSesionActual,
    required this.onResetearPassword,
    required this.onCambiarEstado,
  });

  final Perfil usuario;
  final bool esSesionActual;
  final VoidCallback onResetearPassword;
  final VoidCallback onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final puedeCambiarEstado = !esSesionActual;

    return PopupMenuButton<_AccionUsuario>(
      tooltip: 'Acciones',
      icon: Icon(Icons.more_vert, color: colors.textMuted),
      onSelected: (accion) {
        switch (accion) {
          case _AccionUsuario.resetearPassword:
            onResetearPassword();
          case _AccionUsuario.cambiarEstado:
            onCambiarEstado();
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: _AccionUsuario.resetearPassword,
          child: Text('Resetear contraseña'),
        ),
        if (puedeCambiarEstado)
          PopupMenuItem(
            value: _AccionUsuario.cambiarEstado,
            child: Text(usuario.activo ? 'Desactivar' : 'Reactivar'),
          ),
      ],
    );
  }
}
