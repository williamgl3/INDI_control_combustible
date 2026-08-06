import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../widgets/contenido_responsivo.dart';
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
  final _busquedaController = TextEditingController();
  String _busqueda = '';

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _verDetalle(Perfil chofer) async {
    await context.push(RoutePaths.administrativoChoferDetalle, extra: chofer);
    if (mounted) setState(() {}); // por si se editó el tope desde el detalle
  }

  Future<void> _crearAdministrador() async {
    final creado = await CrearAdministradorDialog.show(context);
    if (creado == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Administrador creado correctamente.')),
      );
    }
  }

  Future<void> _resetearPassword(Perfil usuario) async {
    final actualizada = await ResetearPasswordDialog.show(context, usuario: usuario);
    if (actualizada == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Contraseña de ${usuario.nombreCompleto} actualizada.'),
        ),
      );
    }
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
      HapticFeedback.mediumImpact();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activar
                  ? '${usuario.nombreCompleto} reactivado correctamente.'
                  : '${usuario.nombreCompleto} desactivado correctamente.',
            ),
          ),
        );
      }
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

    final busqueda = _busqueda.trim().toLowerCase();
    final choferesFiltrados = busqueda.isEmpty
        ? choferes
        : choferes
              .where(
                (c) =>
                    c.nombreCompleto.toLowerCase().contains(busqueda) ||
                    c.usuario.toLowerCase().contains(busqueda),
              )
              .toList();

    return ContenidoResponsivo(
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
              // Exclusivo de superadmin — un administrativo normal no debe
              // ver ni poder tocar este botón. El backend igual lo
              // rechazaría con 403 (`requireRole('superadmin')` en
              // `POST /usuarios/administrativos`), esto solo evita
              // mostrarlo cuando ya sabemos que fallaría.
              if (sesion?.esSuperAdmin ?? false)
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
          if (choferes.isNotEmpty)
            TextField(
              controller: _busquedaController,
              decoration: const InputDecoration(
                labelText: 'Buscar por nombre o usuario',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _busqueda = v),
            ),
          if (choferes.isNotEmpty) const SizedBox(height: 16),
          if (choferes.isEmpty)
            const EstadoVacio(
              icono: Icons.groups_outlined,
              mensaje: 'Aún no hay choferes registrados.',
            )
          else if (choferesFiltrados.isEmpty)
            const EstadoVacio(
              icono: Icons.search_off_outlined,
              mensaje: 'Ningún chofer coincide con esa búsqueda.',
            )
          else
            GroupedSection(
              header: 'Directorio',
              children: [
                for (final c in choferesFiltrados)
                  GroupedRow(
                    titulo: c.nombreCompleto,
                    subtitulo: '@${c.usuario}',
                    // El directorio ahora también lista administradores
                    // (ver `crear_administrador_dialog.dart`) — sin esto,
                    // se veían idénticos a un chofer en la lista.
                    icono: c.esAdministrativo
                        ? Icons.shield_outlined
                        : Icons.person_outline,
                    iconoColor: c.esAdministrativo
                        ? AppSectionColors.auditoria
                        : AppSectionColors.choferes,
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
                              if (c.esAdministrativo) ...[
                                _BadgeRol(texto: c.esSuperAdmin ? 'SUPERADMIN' : 'ADMIN'),
                                const SizedBox(width: 8),
                              ],
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
                                // Cambiar el estado de una cuenta admin (o
                                // superadmin) es exclusivo de superadmin —
                                // el backend lo vuelve a validar
                                // (`actualizarEstadoUsuario` en
                                // `authService.ts`), esto solo oculta la
                                // opción cuando ya sabemos que fallaría.
                                puedeGestionarAdmins: sesion?.esSuperAdmin ?? false,
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

/// Pill genérico para el rol de una fila del directorio (ej. "ADMIN") —
/// mismo estilo visual que [_BadgeInactivo], con color propio para no
/// confundirse con el rojo de "inactivo".
class _BadgeRol extends StatelessWidget {
  const _BadgeRol({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final color = AppSectionColors.auditoria;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadii.badgeRadius,
      ),
      child: Text(
        texto,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
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
/// debe poder desactivarse a sí mismo desde la UI. También la oculta para
/// cualquier cuenta admin/superadmin cuando quien mira el menú no es
/// superadmin — ver [puedeGestionarAdmins].
class _MenuAccionesUsuario extends StatelessWidget {
  const _MenuAccionesUsuario({
    super.key,
    required this.usuario,
    required this.esSesionActual,
    required this.puedeGestionarAdmins,
    required this.onResetearPassword,
    required this.onCambiarEstado,
  });

  final Perfil usuario;
  final bool esSesionActual;

  /// `true` si quien ve este menú es superadmin — solo entonces puede
  /// cambiar el estado de una cuenta admin/superadmin (no aplica a
  /// choferes, esos los gestiona cualquier admin).
  final bool puedeGestionarAdmins;
  final VoidCallback onResetearPassword;
  final VoidCallback onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final puedeCambiarEstado =
        !esSesionActual && (!usuario.esAdministrativo || puedeGestionarAdmins);

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
