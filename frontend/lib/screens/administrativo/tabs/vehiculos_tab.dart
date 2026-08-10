import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/catalogos_vehiculo.dart';
import '../../../core/providers.dart';
import '../../../data/api_client.dart';
import '../../../models/vehiculo.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/confirmar_accion_dialog.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/estado_vacio.dart';
import '../editar_vehiculo_dialog.dart';

enum _VistaCatalogo { vehiculos, maquinaria, granel }

enum _FiltroEstado { todos, activos, inactivos }

class VehiculosTab extends ConsumerStatefulWidget {
  const VehiculosTab({super.key});

  @override
  ConsumerState<VehiculosTab> createState() => _VehiculosTabState();
}

class _VehiculosTabState extends ConsumerState<VehiculosTab> {
  final _busquedaController = TextEditingController();
  _VistaCatalogo _vista = _VistaCatalogo.vehiculos;
  _FiltroEstado _estado = _FiltroEstado.todos;
  String _busqueda = '';
  String? _combustible;
  String? _accionEnCurso;

  @override
  void dispose() {
    _busquedaController.dispose();
    super.dispose();
  }

  bool _pertenece(Vehiculo unidad) => switch (_vista) {
    _VistaCatalogo.vehiculos => esVehiculoLigero(unidad.tipoUnidad),
    _VistaCatalogo.maquinaria => esMaquinaria(unidad.tipoUnidad),
    _VistaCatalogo.granel => esUnidadGranel(unidad.tipoUnidad),
  };

  bool _coincide(Vehiculo unidad) {
    if (!_pertenece(unidad)) return false;
    if (_estado == _FiltroEstado.activos && !unidad.activo) return false;
    if (_estado == _FiltroEstado.inactivos && unidad.activo) return false;
    if (_combustible != null && unidad.tipoCombustible != _combustible) {
      return false;
    }
    final consulta = _busqueda.trim().toLowerCase();
    if (consulta.isEmpty) return true;
    return unidad.etiquetaUnidad.toLowerCase().contains(consulta) ||
        (unidad.placas?.toLowerCase().contains(consulta) ?? false) ||
        (unidad.numeroEconomico?.toLowerCase().contains(consulta) ?? false) ||
        (unidad.modelo?.toLowerCase().contains(consulta) ?? false) ||
        (unidad.ubicacion?.toLowerCase().contains(consulta) ?? false);
  }

  Future<void> _agregar() async {
    final guardado = await EditarVehiculoDialog.show(context);
    if (guardado == true && mounted) {
      ref.invalidate(catalogoUnidadesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidad agregada correctamente.')),
      );
    }
  }

  Future<void> _editar(Vehiculo unidad) async {
    final guardado = await EditarVehiculoDialog.show(context, vehiculo: unidad);
    if (guardado == true && mounted) {
      ref.invalidate(catalogoUnidadesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unidad actualizada correctamente.')),
      );
    }
  }

  Future<void> _cambiarEstado(Vehiculo unidad) async {
    final activar = !unidad.activo;
    final confirmado = await ConfirmarAccionDialog.show(
      context,
      titulo: activar ? 'Reactivar unidad' : 'Desactivar unidad',
      mensaje: activar
          ? '¿Reactivar ${unidad.tipoUnidad} · ${unidad.etiquetaUnidad}?'
          : '¿Desactivar ${unidad.tipoUnidad} · ${unidad.etiquetaUnidad}? '
                'Conservará todo su historial.',
      textoConfirmar: activar ? 'Reactivar' : 'Desactivar',
      destructivo: !activar,
    );
    if (!confirmado) return;
    setState(() => _accionEnCurso = unidad.id);
    try {
      await ref
          .read(vehiculosRepositoryProvider)
          .cambiarEstado(id: unidad.id, activo: activar);
      ref.invalidate(catalogoUnidadesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activar ? 'Unidad reactivada.' : 'Unidad desactivada.',
            ),
          ),
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.mensaje)));
      }
    } finally {
      if (mounted) setState(() => _accionEnCurso = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = ref.watch(catalogoUnidadesProvider);
    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EncabezadoCatalogo(onAgregar: _agregar),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_VistaCatalogo>(
              segments: const [
                ButtonSegment(
                  value: _VistaCatalogo.vehiculos,
                  label: Text('Vehículos'),
                  icon: Icon(Icons.directions_car_outlined),
                ),
                ButtonSegment(
                  value: _VistaCatalogo.maquinaria,
                  label: Text('Maquinaria'),
                  icon: Icon(Icons.precision_manufacturing_outlined),
                ),
                ButtonSegment(
                  value: _VistaCatalogo.granel,
                  label: Text('Marimbas y pipas'),
                  icon: Icon(Icons.local_shipping_outlined),
                ),
              ],
              selected: {_vista},
              showSelectedIcon: false,
              onSelectionChanged: (value) {
                final nuevaVista = value.first;
                final combustiblesDisponibles =
                    catalogo.valueOrNull
                        ?.where(
                          (unidad) => switch (nuevaVista) {
                            _VistaCatalogo.vehiculos => esVehiculoLigero(
                              unidad.tipoUnidad,
                            ),
                            _VistaCatalogo.maquinaria => esMaquinaria(
                              unidad.tipoUnidad,
                            ),
                            _VistaCatalogo.granel => esUnidadGranel(
                              unidad.tipoUnidad,
                            ),
                          },
                        )
                        .map((unidad) => unidad.tipoCombustible)
                        .whereType<String>()
                        .toSet() ??
                    const <String>{};
                setState(() {
                  _vista = nuevaVista;
                  if (!combustiblesDisponibles.contains(_combustible)) {
                    _combustible = null;
                  }
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          catalogo.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (error, stack) => EstadoVacio(
              icono: Icons.cloud_off_outlined,
              mensaje: 'No fue posible cargar el catálogo.',
              textoAccion: 'Reintentar',
              onAccion: () => ref.invalidate(catalogoUnidadesProvider),
            ),
            data: _construirCatalogo,
          ),
        ],
      ),
    );
  }

  Widget _construirCatalogo(List<Vehiculo> unidades) {
    final base = unidades.where(_pertenece).toList();
    final combustibles =
        base.map((u) => u.tipoCombustible).whereType<String>().toSet().toList()
          ..sort();
    final filtradas = unidades.where(_coincide).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${base.length} unidades en esta categoría',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: TextField(
                controller: _busquedaController,
                decoration: const InputDecoration(
                  labelText: 'Buscar por identificador, modelo o ubicación',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (value) => setState(() => _busqueda = value),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: DropdownButtonFormField<_FiltroEstado>(
                initialValue: _estado,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Estado'),
                items: const [
                  DropdownMenuItem(
                    value: _FiltroEstado.todos,
                    child: Text('Todos los estados'),
                  ),
                  DropdownMenuItem(
                    value: _FiltroEstado.activos,
                    child: Text('Activos'),
                  ),
                  DropdownMenuItem(
                    value: _FiltroEstado.inactivos,
                    child: Text('Inactivos'),
                  ),
                ],
                onChanged: (value) => setState(() => _estado = value!),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: DropdownButtonFormField<String?>(
                initialValue: _combustible,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Combustible'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Todos los combustibles'),
                  ),
                  for (final combustible in combustibles)
                    DropdownMenuItem(
                      value: combustible,
                      child: Text(combustible),
                    ),
                ],
                onChanged: (value) => setState(() => _combustible = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (base.isEmpty)
          const EstadoVacio(
            icono: Icons.inventory_2_outlined,
            mensaje: 'No hay unidades en esta categoría.',
          )
        else if (filtradas.isEmpty)
          const EstadoVacio(
            icono: Icons.search_off_outlined,
            mensaje: 'No hay coincidencias con los filtros actuales.',
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final ancho = constraints.maxWidth;
              return Column(
                children: [
                  for (final unidad in filtradas)
                    _FilaUnidad(
                      unidad: unidad,
                      compacta: ancho < 700,
                      ocupada: _accionEnCurso == unidad.id,
                      onEditar: () => _editar(unidad),
                      onCambiarEstado: () => _cambiarEstado(unidad),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _EncabezadoCatalogo extends StatelessWidget {
  const _EncabezadoCatalogo({required this.onAgregar});
  final VoidCallback onAgregar;
  @override
  Widget build(BuildContext context) => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 16,
    runSpacing: 12,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catálogo de unidades',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            'Vehículos, maquinaria, marimbas y pipas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ],
      ),
      ElevatedButton.icon(
        onPressed: onAgregar,
        icon: const Icon(Icons.add),
        label: const Text('Agregar unidad'),
      ),
    ],
  );
}

class _FilaUnidad extends StatelessWidget {
  const _FilaUnidad({
    required this.unidad,
    required this.compacta,
    required this.ocupada,
    required this.onEditar,
    required this.onCambiarEstado,
  });
  final Vehiculo unidad;
  final bool compacta;
  final bool ocupada;
  final VoidCallback onEditar;
  final VoidCallback onCambiarEstado;

  @override
  Widget build(BuildContext context) {
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          unidad.modelo ?? unidad.tipoUnidad,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          [
            unidad.etiquetaCompleta ?? unidad.etiquetaUnidad,
            unidad.tipoCombustible ?? 'Sin combustible',
            if (unidad.ubicacion != null) unidad.ubicacion!,
          ].join(' · '),
          maxLines: compacta ? 3 : 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _Badge(
              texto: etiquetaCategoria(unidad.tipoUnidad),
              color: AppSectionColors.vehiculos,
            ),
            _Badge(
              texto: unidad.activo ? 'ACTIVO' : 'INACTIVO',
              color: unidad.activo
                  ? context.colors.success
                  : context.colors.error,
            ),
          ],
        ),
      ],
    );
    final acciones = ocupada
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Wrap(
            spacing: 4,
            children: [
              OutlinedButton.icon(
                onPressed: onEditar,
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
              PopupMenuButton<void>(
                tooltip: 'Más acciones',
                itemBuilder: (_) => [
                  PopupMenuItem(
                    onTap: onCambiarEstado,
                    child: Text(unidad.activo ? 'Desactivar' : 'Reactivar'),
                  ),
                ],
              ),
            ],
          );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: compacta
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  info,
                  Align(alignment: Alignment.centerRight, child: acciones),
                ],
              )
            : Row(
                children: [
                  Expanded(child: info),
                  const SizedBox(width: 16),
                  acciones,
                ],
              ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.texto, required this.color});
  final String texto;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: AppRadii.badgeRadius,
    ),
    child: Text(
      texto,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: color,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
