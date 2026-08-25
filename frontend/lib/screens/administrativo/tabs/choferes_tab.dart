import 'dart:async';

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
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/stat_tile.dart';
import '../gestionar_chofer_dialogs.dart';
import '../resetear_password_dialog.dart';

class ChoferesTab extends ConsumerStatefulWidget {
  const ChoferesTab({super.key});
  @override
  ConsumerState<ChoferesTab> createState() => _ChoferesTabState();
}

class _ChoferesTabState extends ConsumerState<ChoferesTab> {
  final _busquedaController = TextEditingController();
  String _busqueda = '', _estado = 'todos';
  String? _accionEnCurso;
  bool _cargandoLista = false;
  String? _errorLista;
  int _pagina = 1, _totalPaginas = 1;
  Timer? _debounce;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargar());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busquedaController.dispose();
    super.dispose();
  }

  Future<void> _cargar({int? pagina}) async {
    if (_cargandoLista) return;
    setState(() {
      _cargandoLista = true;
      _errorLista = null;
    });
    try {
      final r = await ref
          .read(authRepositoryProvider)
          .cargarChoferes(
            buscar: _busqueda.trim(),
            estado: _estado,
            pagina: pagina ?? _pagina,
          );
      if (mounted) {
        setState(() {
          _pagina = r.pagina;
          _totalPaginas = r.totalPaginas == 0 ? 1 : r.totalPaginas;
        });
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorLista = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargandoLista = false);
    }
  }

  void _buscar(String value) {
    setState(() => _busqueda = value);
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 350),
      () => _cargar(pagina: 1),
    );
  }

  Future<void> _verPerfil(Perfil p) =>
      context.push(RoutePaths.administrativoChoferDetalle, extra: p);
  void _mensaje(String texto) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(texto)));

  Future<void> _actividad(Perfil p) async {
    setState(() => _accionEnCurso = p.id);
    try {
      final d = await ref.read(authRepositoryProvider).obtenerChofer(p.id);
      if (mounted) await mostrarActividadChofer(context, d);
    } on AuthException catch (e) {
      if (mounted) _mensaje(e.mensaje);
    } finally {
      if (mounted) setState(() => _accionEnCurso = null);
    }
  }

  Future<void> _editar(Perfil p) async {
    final r = await EditarChoferDialog.show(context, p);
    if (r != null && mounted) {
      setState(() {});
      _mensaje('Chofer actualizado.');
    }
  }

  Future<void> _reset(Perfil p) async {
    final ok = await ResetearPasswordDialog.show(context, usuario: p);
    if (ok == true && mounted) {
      _mensaje('Solicitud registrada. La contraseña no fue modificada.');
    }
  }

  Future<void> _estadoCuenta(Perfil p) async {
    final activar = !p.activo;
    final motivo = await solicitarMotivo(
      context,
      titulo: activar ? 'Reactivar cuenta' : 'Desactivar cuenta',
      mensaje: activar
          ? '¿Reactivar a ${p.nombreCompleto}? Podrá volver a iniciar sesión con sus credenciales vigentes.'
          : '¿Desactivar a ${p.nombreCompleto}? Ya no podrá iniciar sesión, pero su historial y actividad se conservarán.',
      accion: activar ? 'Reactivar' : 'Desactivar',
      destructivo: !activar,
    );
    if (motivo == null) return;
    setState(() => _accionEnCurso = p.id);
    try {
      await ref
          .read(authRepositoryProvider)
          .cambiarEstado(usuarioId: p.id, activo: activar, motivo: motivo);
      HapticFeedback.mediumImpact();
      if (mounted) {
        setState(() {});
        _mensaje(
          activar
              ? '${p.nombreCompleto} reactivado.'
              : '${p.nombreCompleto} desactivado.',
        );
      }
    } on AuthException catch (e) {
      if (mounted) _mensaje(e.mensaje);
    } finally {
      if (mounted) setState(() => _accionEnCurso = null);
    }
  }

  Future<void> _eliminar(Perfil p) async {
    setState(() => _accionEnCurso = p.id);
    try {
      final e = await ref
          .read(authRepositoryProvider)
          .consultarElegibilidadEliminacion(p.id);
      if (!mounted) return;
      if (!e.elegible) {
        _mensaje(
          'La cuenta tiene historial relacionado y solo puede desactivarse.',
        );
        return;
      }
      final ok = await EliminarChoferDialog.show(context, p);
      if (ok == true && mounted) {
        setState(() {});
        _mensaje('Cuenta de prueba eliminada permanentemente.');
      }
    } on AuthException catch (e) {
      if (mounted) _mensaje(e.mensaje);
    } finally {
      if (mounted) setState(() => _accionEnCurso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors, sesion = ref.watch(sessionProvider);
    ref.watch(operacionesTickProvider);
    final todos = ref
        .watch(authRepositoryProvider)
        .listarChoferes()
        .where((p) => p.esChofer)
        .toList();
    final q = _busqueda.trim().toLowerCase();
    final datos = todos
        .where(
          (p) =>
              (_estado == 'todos' || (_estado == 'activo') == p.activo) &&
              (q.isEmpty ||
                  p.nombreCompleto.toLowerCase().contains(q) ||
                  p.usuario.toLowerCase().contains(q) ||
                  p.correo.toLowerCase().contains(q)),
        )
        .toList();
    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Choferes', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 4),
          Text(
            'Gestión segura de cuentas operativas de chofer.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: 20),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: 200,
              child: StatTile(
                icono: Icons.groups_outlined,
                valor: '${todos.length}',
                etiqueta: 'Choferes',
                color: AppSectionColors.choferes,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 420,
                child: TextField(
                  controller: _busquedaController,
                  decoration: const InputDecoration(
                    labelText: 'Buscar por nombre, apellidos, usuario o correo',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: _buscar,
                ),
              ),
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _estado,
                  decoration: const InputDecoration(labelText: 'Estado'),
                  items: const [
                    DropdownMenuItem(
                      value: 'todos',
                      child: Text('Todos', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'activo',
                      child: Text('Activos', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'inactivo',
                      child: Text('Inactivos', overflow: TextOverflow.ellipsis),
                    ),
                  ],
                  onChanged: (v) {
                    setState(() => _estado = v ?? 'todos');
                    _cargar(pagina: 1);
                  },
                ),
              ),
              IconButton(
                tooltip: 'Actualizar choferes',
                onPressed: _cargandoLista ? null : () => _cargar(),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          if (todos.isNotEmpty) const SizedBox(height: 16),
          if (_cargandoLista && todos.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_errorLista != null)
            EstadoVacio(icono: Icons.error_outline, mensaje: _errorLista!)
          else if (todos.isEmpty)
            const EstadoVacio(
              icono: Icons.groups_outlined,
              mensaje: 'Aún no hay choferes registrados.',
            )
          else if (datos.isEmpty)
            const EstadoVacio(
              icono: Icons.search_off_outlined,
              mensaje: 'Ningún chofer coincide con los filtros.',
            )
          else ...[
            GroupedSection(
              header: 'Directorio',
              children: [
                for (final p in datos)
                  GroupedRow(
                    titulo: p.nombreCompleto,
                    subtitulo:
                        '@${p.usuario} · ${p.activo ? 'Activo' : 'Inactivo'}${p.ultimaActividad == null ? '' : ' · Última actividad ${p.ultimaActividad!.toLocal().toString().substring(0, 16)}'}',
                    icono: Icons.person_outline,
                    iconoColor: AppSectionColors.choferes,
                    onTap: () => _verPerfil(p),
                    trailing: _accionEnCurso == p.id
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _EstadoBadge(activo: p.activo),
                              const SizedBox(width: 8),
                              _Menu(
                                key: ValueKey('acciones-${p.id}'),
                                chofer: p,
                                esSuperadmin: sesion?.esSuperAdmin ?? false,
                                onPerfil: () => _verPerfil(p),
                                onActividad: () => _actividad(p),
                                onEditar: () => _editar(p),
                                onReset: () => _reset(p),
                                onEstado: () => _estadoCuenta(p),
                                onEliminar: () => _eliminar(p),
                              ),
                            ],
                          ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Página anterior',
                  onPressed: _pagina > 1 && !_cargandoLista
                      ? () => _cargar(pagina: _pagina - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('Página $_pagina de $_totalPaginas'),
                IconButton(
                  tooltip: 'Página siguiente',
                  onPressed: _pagina < _totalPaginas && !_cargandoLista
                      ? () => _cargar(pagina: _pagina + 1)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  const _EstadoBadge({required this.activo});
  final bool activo;
  @override
  Widget build(BuildContext context) {
    final color = activo ? Colors.green : context.colors.error;
    return Semantics(
      label: 'Estado: ${activo ? 'activo' : 'inactivo'}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: AppRadii.badgeRadius,
        ),
        child: Text(
          activo ? 'ACTIVO' : 'INACTIVO',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

enum _Accion { perfil, actividad, editar, reset, estado, eliminar }

class _Menu extends StatelessWidget {
  const _Menu({
    super.key,
    required this.chofer,
    required this.esSuperadmin,
    required this.onPerfil,
    required this.onActividad,
    required this.onEditar,
    required this.onReset,
    required this.onEstado,
    required this.onEliminar,
  });
  final Perfil chofer;
  final bool esSuperadmin;
  final VoidCallback onPerfil,
      onActividad,
      onEditar,
      onReset,
      onEstado,
      onEliminar;
  @override
  Widget build(BuildContext context) => PopupMenuButton<_Accion>(
    tooltip: 'Acciones de ${chofer.nombreCompleto}',
    icon: const Icon(Icons.more_vert),
    onSelected: (a) {
      switch (a) {
        case _Accion.perfil:
          onPerfil();
        case _Accion.actividad:
          onActividad();
        case _Accion.editar:
          onEditar();
        case _Accion.reset:
          onReset();
        case _Accion.estado:
          onEstado();
        case _Accion.eliminar:
          onEliminar();
      }
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: _Accion.perfil, child: Text('Ver perfil')),
      const PopupMenuItem(
        value: _Accion.actividad,
        child: Text('Ver actividad'),
      ),
      const PopupMenuItem(value: _Accion.editar, child: Text('Editar datos')),
      if (chofer.activo)
        const PopupMenuItem(
          value: _Accion.reset,
          child: Text('Restablecer contraseña'),
        ),
      PopupMenuItem(
        value: _Accion.estado,
        child: Text(chofer.activo ? 'Desactivar' : 'Reactivar'),
      ),
      if (!chofer.activo && esSuperadmin)
        const PopupMenuItem(
          value: _Accion.eliminar,
          child: Text('Eliminar definitivamente'),
        ),
    ],
  );
}
