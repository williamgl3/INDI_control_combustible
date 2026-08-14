import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/despacho_marimba.dart';
import '../../../models/panel_marimba.dart';
import '../../../models/recorrido_marimba.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/estado_vacio.dart';

class MarimbaTab extends ConsumerStatefulWidget {
  const MarimbaTab({super.key});

  @override
  ConsumerState<MarimbaTab> createState() => _MarimbaTabState();
}

class _MarimbaTabState extends ConsumerState<MarimbaTab> {
  FiltrosRecorridosMarimba filtros = const FiltrosRecorridosMarimba();

  void _filtrar({
    String? categoria,
    String? combustible,
    String? estado,
    bool? revision,
  }) {
    setState(
      () => filtros = FiltrosRecorridosMarimba(
        categoria: categoria,
        tipoCombustible: combustible,
        estado: estado,
        requiereRevision: revision,
        limit: filtros.limit,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resumen = ref.watch(resumenUnidadesMarimbaProvider);
    final historial = ref.watch(
      recorridosAdministrativosMarimbaProvider(filtros),
    );
    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Marimba/Pipa',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                tooltip: 'Actualizar unidades',
                onPressed: () => ref.invalidate(resumenUnidadesMarimbaProvider),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const Text(
            'Consulta administrativa de inventario y recorridos. Las operaciones de campo permanecen separadas.',
          ),
          const SizedBox(height: 20),
          Text('Unidades', style: Theme.of(context).textTheme.titleLarge),
          resumen.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const EstadoVacio(
              icono: Icons.error_outline,
              mensaje:
                  'No fue posible consultar el inventario. El historial permanece disponible.',
            ),
            data: (items) => items.isEmpty
                ? const EstadoVacio(
                    icono: Icons.local_shipping_outlined,
                    mensaje: 'No hay Marimbas o Pipas registradas.',
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [for (final u in items) _UnidadCard(unidad: u)],
                  ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Historial de recorridos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: 'Actualizar historial',
                onPressed: () => ref.invalidate(
                  recorridosAdministrativosMarimbaProvider(filtros),
                ),
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              DropdownButton<String?>(
                key: const ValueKey('filtro-categoria-marimba'),
                value: filtros.categoria,
                hint: const Text('Categoría'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todas')),
                  DropdownMenuItem(value: 'Marimba', child: Text('Marimba')),
                  DropdownMenuItem(value: 'Pipa', child: Text('Pipa')),
                ],
                onChanged: (v) => _filtrar(
                  categoria: v,
                  combustible: filtros.tipoCombustible,
                  estado: filtros.estado,
                  revision: filtros.requiereRevision,
                ),
              ),
              DropdownButton<String?>(
                value: filtros.tipoCombustible,
                hint: const Text('Combustible'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(value: 'Magna', child: Text('Magna')),
                  DropdownMenuItem(value: 'Diésel', child: Text('Diésel')),
                ],
                onChanged: (v) => _filtrar(
                  categoria: filtros.categoria,
                  combustible: v,
                  estado: filtros.estado,
                  revision: filtros.requiereRevision,
                ),
              ),
              DropdownButton<String?>(
                value: filtros.estado,
                hint: const Text('Estado'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Todos')),
                  DropdownMenuItem(value: 'abierto', child: Text('Abiertos')),
                  DropdownMenuItem(value: 'cerrado', child: Text('Cerrados')),
                ],
                onChanged: (v) => _filtrar(
                  categoria: filtros.categoria,
                  combustible: filtros.tipoCombustible,
                  estado: v,
                  revision: filtros.requiereRevision,
                ),
              ),
              FilterChip(
                label: const Text('Requiere revisión'),
                selected: filtros.requiereRevision == true,
                onSelected: (v) => _filtrar(
                  categoria: filtros.categoria,
                  combustible: filtros.tipoCombustible,
                  estado: filtros.estado,
                  revision: v ? true : null,
                ),
              ),
              TextButton(
                onPressed: () =>
                    setState(() => filtros = const FiltrosRecorridosMarimba()),
                child: const Text('Limpiar filtros'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          historial.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const EstadoVacio(
              icono: Icons.error_outline,
              mensaje: 'No fue posible consultar los recorridos.',
            ),
            data: (pagina) => pagina.items.isEmpty
                ? const EstadoVacio(
                    icono: Icons.route_outlined,
                    mensaje: 'No hay recorridos con estos filtros.',
                  )
                : Column(
                    children: [
                      for (final r in pagina.items)
                        Card(
                          child: ListTile(
                            title: Text(r.frente),
                            subtitle: Text(
                              '${r.marimbaEtiqueta ?? r.marimbaId} · ${r.tipoCombustible ?? 'Combustible no disponible'} · ${r.responsableNombre ?? 'Responsable no disponible'}',
                            ),
                            trailing: Text(r.estado.name),
                            onTap: () => _detalle(context, r.id),
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: pagina.page > 1
                                ? () => setState(
                                    () => filtros = filtros.copyWith(
                                      page: pagina.page - 1,
                                    ),
                                  )
                                : null,
                            icon: const Icon(Icons.chevron_left),
                          ),
                          Text('Página ${pagina.page} de ${pagina.totalPages}'),
                          IconButton(
                            onPressed: pagina.page < pagina.totalPages
                                ? () => setState(
                                    () => filtros = filtros.copyWith(
                                      page: pagina.page + 1,
                                    ),
                                  )
                                : null,
                            icon: const Icon(Icons.chevron_right),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _detalle(BuildContext context, String id) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 720,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Consumer(
              builder: (context, ref, _) => ref
                  .watch(detalleAdministrativoMarimbaProvider(id))
                  .when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (_, _) => const EstadoVacio(
                      icono: Icons.error_outline,
                      mensaje: 'No fue posible consultar el detalle.',
                    ),
                    data: (d) => _Detalle(
                      recorrido: d.recorrido,
                      despachos: d.despachos,
                    ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnidadCard extends StatelessWidget {
  const _UnidadCard({required this.unidad});
  final ResumenUnidadMarimba unidad;
  String saldo(String? value) => value == null ? 'Sin registro' : '$value L';
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 310,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              unidad.modelo ??
                  unidad.numeroEconomico ??
                  unidad.placas ??
                  'Unidad sin etiqueta',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              '${unidad.tipoUnidad} · ${unidad.activo ? 'Activa' : 'Inactiva'}',
            ),
            const Divider(),
            Text('Magna: ${saldo(unidad.saldoMagna)}'),
            Text('Diésel: ${saldo(unidad.saldoDiesel)}'),
            const SizedBox(height: 6),
            Text(
              unidad.recorridoAbiertoId == null
                  ? 'Sin recorrido abierto'
                  : 'Recorrido abierto · ${unidad.responsableNombre ?? 'Responsable no disponible'}',
            ),
            if (unidad.requiereRevision)
              const Chip(label: Text('Requiere revisión')),
          ],
        ),
      ),
    ),
  );
}

class _Detalle extends StatelessWidget {
  const _Detalle({required this.recorrido, required this.despachos});
  final RecorridoMarimba recorrido;
  final List<DespachoMarimba> despachos;
  @override
  Widget build(BuildContext context) => ListView(
    shrinkWrap: true,
    children: [
      Text(
        'Detalle del recorrido',
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      Text(
        '${recorrido.marimbaEtiqueta ?? recorrido.marimbaId} · ${recorrido.frente}',
      ),
      Text(
        'Responsable: ${recorrido.responsableNombre ?? 'Dato no disponible'}',
      ),
      Text('Inventario inicial: ${recorrido.litrosIniciales} L'),
      Text(
        'Despachado: ${recorrido.litrosDespachadosTotal?.toString() ?? 'Dato no disponible'}',
      ),
      Text(
        'Inventario final: ${recorrido.existenciaFisica?.toString() ?? 'Dato no disponible'}',
      ),
      if (recorrido.requiereRevision)
        const ListTile(
          leading: Icon(Icons.warning_amber),
          title: Text('Requiere revisión'),
          subtitle: Text(
            'Los valores persistidos presentan una diferencia de conciliación.',
          ),
        ),
      const Divider(),
      Text('Despachos', style: Theme.of(context).textTheme.titleLarge),
      for (final d in despachos)
        ListTile(
          title: Text(
            d.unidadDestinoEtiqueta ??
                d.destinoTexto ??
                'Unidad destino no disponible',
          ),
          subtitle: Text(
            '${d.tipoCombustible ?? 'Combustible desconocido'} · ${d.litrosSuministrados} L · ${d.cantidadDeclarada == true
                ? 'Cantidad declarada'
                : d.cantidadDeclarada == false
                ? 'Cantidad medida'
                : 'Registro histórico'}\nMedidor: ${d.medidorInicial?.toString() ?? '—'} → ${d.medidorFinal?.toString() ?? '—'} · Horómetro: ${d.horometro?.toString() ?? '—'}',
          ),
          isThreeLine: true,
        ),
      const Divider(),
      Text('Evidencias', style: Theme.of(context).textTheme.titleLarge),
      _evidencia('Foto de cierre', recorrido.fotoCierrePath),
      _evidencia('Foto de nivel', recorrido.fotoNivelPath),
      for (final d in despachos) ...[
        _evidencia(
          'Foto de horómetro',
          d.fotoHorometroPath,
          key: ValueKey('despacho-${d.id}-foto-horometro'),
        ),
        _evidencia(
          'Foto de medidor',
          d.fotoMedidorPath,
          key: ValueKey('despacho-${d.id}-foto-medidor'),
        ),
        _evidencia(
          'Evidencia del despacho',
          d.fotoEvidenciaPath,
          key: ValueKey('despacho-${d.id}-foto-evidencia'),
        ),
      ],
    ],
  );
  Widget _evidencia(String nombre, String? ruta, {Key? key}) => ListTile(
    key: key,
    dense: true,
    leading: const Icon(Icons.image_outlined),
    title: Text(nombre),
    trailing: Text(ruta == null ? 'Evidencia no disponible' : 'Disponible'),
  );
}
