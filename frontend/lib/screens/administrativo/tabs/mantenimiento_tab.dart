import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/incidencia_vehiculo.dart';
import '../../../models/vehiculo.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_section_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_card.dart';
import '../../../widgets/estado_mantenimiento_badge.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/fecha_formato.dart';
import '../../../widgets/grouped_section.dart';
import '../../../widgets/icon_badge.dart';
import '../../../widgets/ios_segmented_control.dart';
import '../../../widgets/contenido_responsivo.dart';
import '../../../widgets/stat_tile_row.dart';
import '../../../widgets/ver_foto_dialog.dart';
import '../registrar_servicio_dialog.dart';
import '../editar_vehiculo_dialog.dart';
import 'mantenimiento_calculo.dart';

enum _FiltroVista { todos, vencidos, proximos, alDia, noConfigurados, sinDatos }

/// Pestaña "Mantenimiento": diagnóstico de mantenimiento preventivo por
/// vehículo/maquinaria (a partir del km recorrido o del horómetro),
/// con fecha proyectada del próximo servicio y un reporte descargable
/// para que el área encargada agilice el servicio mecánico.
class MantenimientoTab extends ConsumerStatefulWidget {
  const MantenimientoTab({super.key});

  @override
  ConsumerState<MantenimientoTab> createState() => _MantenimientoTabState();
}

class _MantenimientoTabState extends ConsumerState<MantenimientoTab> {
  _FiltroVista _filtroVista = _FiltroVista.todos;

  EstadoMantenimiento? get _filtro => switch (_filtroVista) {
    _FiltroVista.todos => null,
    _FiltroVista.vencidos => EstadoMantenimiento.vencido,
    _FiltroVista.proximos => EstadoMantenimiento.proximo,
    _FiltroVista.alDia => EstadoMantenimiento.alDia,
    _FiltroVista.noConfigurados => EstadoMantenimiento.noConfigurado,
    _FiltroVista.sinDatos => EstadoMantenimiento.sinDatos,
  };

  Future<void> _registrarServicio(
    Vehiculo vehiculo,
    double? lecturaActual,
  ) async {
    final guardado = await RegistrarServicioDialog.show(
      context,
      vehiculo: vehiculo,
      lecturaActualSugerida: lecturaActual,
    );
    if (guardado == true && mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Servicio registrado correctamente.')),
      );
    }
  }

  Future<void> _configurarIntervalo(Vehiculo vehiculo) async {
    final guardado = await EditarVehiculoDialog.show(
      context,
      vehiculo: vehiculo,
    );
    if (guardado == true && mounted) setState(() {});
  }

  Future<void> _resolverIncidencia(IncidenciaVehiculo incidencia) async {
    final comentarioController = TextEditingController();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Marcar como resuelta'),
        content: TextField(
          controller: comentarioController,
          decoration: const InputDecoration(labelText: 'Comentario (opcional)'),
          maxLines: 2,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Resolver'),
          ),
        ],
      ),
    );
    if (confirmado != true) return;
    await ref
        .read(incidenciasRepositoryProvider)
        .resolver(
          id: incidencia.id,
          comentario: comentarioController.text.trim().isEmpty
              ? null
              : comentarioController.text.trim(),
        );
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Incidencia marcada como resuelta.')),
      );
    }
  }

  Future<void> _exportar(List<DiagnosticoMantenimiento> diagnosticos) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final contenido = construirXlsxMantenimiento(diagnosticos);
      await ref
          .read(exportadorServiceProvider)
          .exportarXlsx(
            nombreArchivo: nombreArchivoMantenimiento(DateTime.now()),
            contenido: contenido,
            descripcion: 'Reporte de mantenimiento',
          );
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('No pudimos preparar el archivo. Intenta de nuevo.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);
    final operacionesRepo = ref.watch(operacionesRepositoryProvider);
    final incidenciasRepo = ref.watch(incidenciasRepositoryProvider);
    ref.watch(operacionesTickProvider);

    final incidenciasAbiertas = incidenciasRepo.todasLasIncidencias
        .where((i) => i.estado == EstadoIncidencia.abierta)
        .toList();
    final vehiculosPorId = {for (final v in vehiculosRepo.todos) v.id: v};

    final ahora = DateTime.now();
    final diagnosticos = vehiculosRepo.todos
        .map(
          (v) => calcularMantenimiento(
            vehiculo: v,
            historial: operacionesRepo.historialLecturas(v.id),
            ahora: ahora,
          ),
        )
        .toList();

    final resumen = resumirMantenimiento(diagnosticos);
    final visibles = filtrarMantenimiento(diagnosticos, _filtro);

    return ContenidoResponsivo(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titulo = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mantenimiento',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Servicio general mecánico proyectado por km recorridos u horómetro.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              );
              final exportar = OutlinedButton.icon(
                onPressed: diagnosticos.isEmpty
                    ? null
                    : () => _exportar(diagnosticos),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Exportar reporte'),
              );
              if (constraints.maxWidth < 600) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    titulo,
                    const SizedBox(height: AppSpacing.md),
                    exportar,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: titulo),
                  const SizedBox(width: AppSpacing.md),
                  exportar,
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          StatTileRow(
            tiles: [
              _EstadisticaMantenimiento(
                valor: '${resumen.vencidos}',
                etiqueta: 'Vencidos',
                color: colors.error,
                onTap: () =>
                    setState(() => _filtroVista = _FiltroVista.vencidos),
              ),
              _EstadisticaMantenimiento(
                valor: '${resumen.noConfigurados}',
                etiqueta: 'Sin configurar',
                color: colors.textMuted,
                onTap: () =>
                    setState(() => _filtroVista = _FiltroVista.noConfigurados),
              ),
              _EstadisticaMantenimiento(
                valor: '${resumen.proximos}',
                etiqueta: 'Próximos',
                color: colors.warning,
                onTap: () =>
                    setState(() => _filtroVista = _FiltroVista.proximos),
              ),
            ],
          ),
          if (incidenciasAbiertas.isNotEmpty) ...[
            const SizedBox(height: 20),
            GroupedSection(
              header: 'Incidencias reportadas (${incidenciasAbiertas.length})',
              children: [
                for (final i in incidenciasAbiertas)
                  _IncidenciaTile(
                    incidencia: i,
                    vehiculo: vehiculosPorId[i.vehiculoId],
                    onResolver: () => _resolverIncidencia(i),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          IosSegmentedControl<_FiltroVista>(
            valor: _filtroVista,
            opciones: const {
              _FiltroVista.todos: 'Todos',
              _FiltroVista.vencidos: 'Vencidos',
              _FiltroVista.proximos: 'Próximos',
              _FiltroVista.alDia: 'Al día',
              _FiltroVista.noConfigurados: 'No configurados',
              _FiltroVista.sinDatos: 'Sin datos',
            },
            onChanged: (f) => setState(() => _filtroVista = f),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Column(
              key: ValueKey(_filtro),
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (visibles.isEmpty)
                  const EstadoVacio(
                    icono: Icons.build_outlined,
                    mensaje: 'No hay unidades que coincidan con este filtro.',
                  )
                else
                  GroupedSection(
                    children: [
                      for (final d in visibles)
                        _TarjetaMantenimiento(
                          diagnostico: d,
                          onRegistrarServicio: () =>
                              _registrarServicio(d.vehiculo, d.lecturaActual),
                          onConfigurarIntervalo: () =>
                              _configurarIntervalo(d.vehiculo),
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
}

class _EstadisticaMantenimiento extends StatelessWidget {
  const _EstadisticaMantenimiento({
    required this.valor,
    required this.etiqueta,
    required this.color,
    this.onTap,
  });

  final String valor;
  final String etiqueta;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Antes reimplementaba a mano el mismo Material+InkWell+Container que
    // ya encapsula AppCard (con el token de sombra correcto, pero
    // duplicando la estructura) — usa el widget compartido directamente.
    return AppCard(
      onTap: onTap,
      rippleColor: color,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.14),
            child: Icon(Icons.build_outlined, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(valor, style: Theme.of(context).textTheme.titleLarge),
                Text(
                  etiqueta,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right, size: 16, color: colors.textMuted),
        ],
      ),
    );
  }
}

class _TarjetaMantenimiento extends StatelessWidget {
  const _TarjetaMantenimiento({
    required this.diagnostico,
    required this.onRegistrarServicio,
    required this.onConfigurarIntervalo,
  });

  final DiagnosticoMantenimiento diagnostico;
  final VoidCallback onRegistrarServicio;
  final VoidCallback onConfigurarIntervalo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vehiculo = diagnostico.vehiculo;

    final informacion = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const IconBadge(
          icono: Icons.local_shipping_outlined,
          color: AppSectionColors.mantenimiento,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${vehiculo.tipoUnidad} · ${vehiculo.etiquetaUnidad}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  EstadoMantenimientoBadge(estado: diagnostico.estado),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                switch (diagnostico.estado) {
                  EstadoMantenimiento.noConfigurado =>
                    'Intervalo: No configurado · Restante: —',
                  EstadoMantenimiento.sinDatos =>
                    'Aún no hay lecturas registradas para esta unidad.',
                  _ =>
                    '${diagnostico.usoDesdeServicio!.toStringAsFixed(0)} '
                        'de ${vehiculo.intervaloServicio!.toStringAsFixed(0)} '
                        'desde el último servicio.',
                },
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              if (diagnostico.fechaProyectada != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Próximo servicio estimado: '
                  '${formatearFechaCorta(diagnostico.fechaProyectada!)}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final accion = OutlinedButton(
      onPressed: diagnostico.estado == EstadoMantenimiento.noConfigurado
          ? onConfigurarIntervalo
          : onRegistrarServicio,
      child: Text(
        diagnostico.estado == EstadoMantenimiento.noConfigurado
            ? 'Configurar intervalo'
            : 'Registrar servicio',
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth < 600
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  informacion,
                  const SizedBox(height: AppSpacing.md),
                  accion,
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: informacion),
                  const SizedBox(width: 8),
                  accion,
                ],
              ),
      ),
    );
  }
}

class _IncidenciaTile extends StatelessWidget {
  const _IncidenciaTile({
    required this.incidencia,
    required this.vehiculo,
    required this.onResolver,
  });

  final IncidenciaVehiculo incidencia;
  final Vehiculo? vehiculo;
  final VoidCallback onResolver;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icono: Icons.report_gmailerrorred_outlined,
            color: colors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vehiculo == null
                      ? 'Vehículo no encontrado'
                      : '${vehiculo!.tipoUnidad} · ${vehiculo!.etiquetaUnidad}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  incidencia.descripcion,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      formatearFechaCorta(incidencia.creadaEn),
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
                    ),
                    if (incidencia.fotoPath != null) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => VerFotoDialog.show(
                          context,
                          titulo: 'Foto de la incidencia',
                          url: incidencia.fotoPath,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.photo_outlined,
                              size: 14,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              'Ver foto',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(onPressed: onResolver, child: const Text('Resolver')),
        ],
      ),
    );
  }
}
