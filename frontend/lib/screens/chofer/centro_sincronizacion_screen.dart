import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/centro_sincronizacion/centro_providers.dart';
import '../../core/centro_sincronizacion/operacion_sincronizacion_view.dart';
import '../../core/connectivity_provider.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_status_colors.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_elevated_button.dart';
import '../../widgets/contenido_responsivo.dart';
import '../../widgets/estado_vacio.dart';
import '../../widgets/chofer_operation_scaffold.dart';

class CentroSincronizacionScreen extends ConsumerStatefulWidget {
  const CentroSincronizacionScreen({super.key});

  @override
  ConsumerState<CentroSincronizacionScreen> createState() =>
      _CentroSincronizacionScreenState();
}

class _CentroSincronizacionScreenState
    extends ConsumerState<CentroSincronizacionScreen> {
  final _filtroEstados = <EstadoVisualSincronizacion>{};
  final _filtroTipos = <TipoOperacionOffline>{};
  bool _sincronizando = false;

  @override
  Widget build(BuildContext context) {
    final datosAsync = ref.watch(centroSincronizacionProvider);
    final conectado = ref.watch(conectividadProvider).valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Centro de sincronización'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => volverEnFlujoChofer(context),
        ),
        actions: [
          // Indicador de conectividad
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _IndicadorConectividad(conectado: conectado),
          ),
        ],
      ),
      body: SafeArea(
        child: datosAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (datos) {
            if (datos.total == 0) {
              return _CentroVacio(conectado: conectado);
            }
            return _CentroContenido(
              datos: datos,
              filtroEstados: _filtroEstados,
              filtroTipos: _filtroTipos,
              onToggleFiltroEstado: (estado) => setState(() {
                _filtroEstados.contains(estado)
                    ? _filtroEstados.remove(estado)
                    : _filtroEstados.add(estado);
              }),
              onToggleFiltroTipo: (tipo) => setState(() {
                _filtroTipos.contains(tipo)
                    ? _filtroTipos.remove(tipo)
                    : _filtroTipos.add(tipo);
              }),
              onReintentar: _reintentarOperacion,
              onDetalle: _mostrarDetalle,
            );
          },
        ),
      ),
      bottomNavigationBar: datosAsync.hasValue && datosAsync.value!.total > 0
          ? _BarraSincronizar(
              reintentables: datosAsync.value!.reintentables,
              sincronizando: _sincronizando,
              onSincronizar: _sincronizarTodas,
            )
          : null,
    );
  }

  Future<void> _reintentarOperacion(OperacionSincronizacionView op) async {
    if (_sincronizando) return;
    setState(() => _sincronizando = true);
    try {
      await reintentarOperacion(ref, op);
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  Future<void> _sincronizarTodas() async {
    if (_sincronizando) return;
    setState(() => _sincronizando = true);
    try {
      await sincronizarTodasOffline(ref);
    } finally {
      if (mounted) setState(() => _sincronizando = false);
    }
  }

  void _mostrarDetalle(OperacionSincronizacionView op) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DetalleOperacionSheet(
        operacion: op,
        onReintentar: () {
          Navigator.of(context).pop();
          _reintentarOperacion(op);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Indicador de conectividad
// ---------------------------------------------------------------------------

class _IndicadorConectividad extends StatelessWidget {
  const _IndicadorConectividad({required this.conectado});

  final bool conectado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = conectado ? colors.success : context.statusColors.offline;
    final icono = conectado ? Icons.wifi_rounded : Icons.wifi_off_rounded;
    final texto = conectado ? 'En línea' : 'Sin conexión';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            texto.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estado vacío
// ---------------------------------------------------------------------------

class _CentroVacio extends StatelessWidget {
  const _CentroVacio({required this.conectado});

  final bool conectado;

  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.cloud_done_outlined,
      mensaje: conectado
          ? 'Todo sincronizado — no hay operaciones pendientes offline.'
          : 'Todo sincronizado. Se guardará localmente si pierdes conexión.',
    );
  }
}

// ---------------------------------------------------------------------------
// Contenido principal
// ---------------------------------------------------------------------------

class _CentroContenido extends StatelessWidget {
  const _CentroContenido({
    required this.datos,
    required this.filtroEstados,
    required this.filtroTipos,
    required this.onToggleFiltroEstado,
    required this.onToggleFiltroTipo,
    required this.onReintentar,
    required this.onDetalle,
  });

  final CentroSincronizacionData datos;
  final Set<EstadoVisualSincronizacion> filtroEstados;
  final Set<TipoOperacionOffline> filtroTipos;
  final ValueChanged<EstadoVisualSincronizacion> onToggleFiltroEstado;
  final ValueChanged<TipoOperacionOffline> onToggleFiltroTipo;
  final ValueChanged<OperacionSincronizacionView> onReintentar;
  final ValueChanged<OperacionSincronizacionView> onDetalle;

  @override
  Widget build(BuildContext context) {
    final operacionesFiltradas = _aplicarFiltros(datos);

    return ContenidoResponsivo(
      paddingSuperior: AppSpacing.lg,
      paddingInferior: 20,
      scrollable: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Resumen de estados
          _ResumenEstados(conteo: datos.conteoPorEstado),
          const SizedBox(height: AppSpacing.lg),
          // Filtros de estado
          _FiltrosEstado(
            conteo: datos.conteoPorEstado,
            seleccionados: filtroEstados,
            onToggle: onToggleFiltroEstado,
          ),
          const SizedBox(height: AppSpacing.md),
          // Filtros de tipo
          _FiltrosTipo(
            seleccionados: filtroTipos,
            onToggle: onToggleFiltroTipo,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Lista de operaciones
          Expanded(
            child: operacionesFiltradas.isEmpty
                ? _EstadoVacioFiltros()
                : ListView.separated(
                    itemCount: operacionesFiltradas.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final op = operacionesFiltradas[index];
                      return _OperacionTile(
                        key: ValueKey('${op.tipo.name}-${op.idLocal}'),
                        operacion: op,
                        onReintentar: () => onReintentar(op),
                        onDetalle: () => onDetalle(op),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<OperacionSincronizacionView> _aplicarFiltros(
    CentroSincronizacionData datos,
  ) {
    var resultado = datos.operaciones;
    if (filtroEstados.isNotEmpty) {
      resultado = resultado
          .where((op) => filtroEstados.contains(op.estadoVisual))
          .toList();
    }
    if (filtroTipos.isNotEmpty) {
      resultado = resultado
          .where((op) => filtroTipos.contains(op.tipo))
          .toList();
    }
    return resultado;
  }
}

// ---------------------------------------------------------------------------
// Resumen de estados
// ---------------------------------------------------------------------------

class _ResumenEstados extends StatelessWidget {
  const _ResumenEstados({required this.conteo});

  final Map<EstadoVisualSincronizacion, int> conteo;

  @override
  Widget build(BuildContext context) {
    final items = _EstadosVisibles.values
        .where((e) => (conteo[e] ?? 0) > 0)
        .toList();

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final estado in items)
          _StatChip(
            label: _EstadosVisibles.label(estado),
            cantidad: conteo[estado] ?? 0,
            color: _EstadosVisibles.color(estado, context),
            icono: _EstadosVisibles.icono(estado),
          ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.cantidad,
    required this.color,
    required this.icono,
  });

  final String label;
  final int cantidad;
  final Color color;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            '$cantidad',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filtros de estado
// ---------------------------------------------------------------------------

class _FiltrosEstado extends StatelessWidget {
  const _FiltrosEstado({
    required this.conteo,
    required this.seleccionados,
    required this.onToggle,
  });

  final Map<EstadoVisualSincronizacion, int> conteo;
  final Set<EstadoVisualSincronizacion> seleccionados;
  final ValueChanged<EstadoVisualSincronizacion> onToggle;

  @override
  Widget build(BuildContext context) {
    final estados = _EstadosVisibles.values
        .where((e) => (conteo[e] ?? 0) > 0)
        .toList();

    if (estados.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: estados.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final estado = estados[index];
          final seleccionado = seleccionados.contains(estado);
          final color = _EstadosVisibles.color(estado, context);

          return FilterChip(
            label: Text(_EstadosVisibles.label(estado)),
            selected: seleccionado,
            onSelected: (_) => onToggle(estado),
            selectedColor: color.withValues(alpha: 0.15),
            checkmarkColor: color,
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: seleccionado ? color : context.colors.textSecondary,
            ),
            shape: StadiumBorder(
              side: BorderSide(
                color: seleccionado
                    ? color.withValues(alpha: 0.5)
                    : context.colors.border,
              ),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filtros de tipo
// ---------------------------------------------------------------------------

class _FiltrosTipo extends StatelessWidget {
  const _FiltrosTipo({required this.seleccionados, required this.onToggle});

  final Set<TipoOperacionOffline> seleccionados;
  final ValueChanged<TipoOperacionOffline> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: TipoOperacionOffline.values.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final tipo = TipoOperacionOffline.values[index];
          final seleccionado = seleccionados.contains(tipo);

          return FilterChip(
            label: Text(_TiposLabels.label(tipo)),
            selected: seleccionado,
            onSelected: (_) => onToggle(tipo),
            selectedColor: context.colors.primary.withValues(alpha: 0.12),
            checkmarkColor: context.colors.primary,
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: seleccionado
                  ? context.colors.primary
                  : context.colors.textSecondary,
            ),
            shape: StadiumBorder(
              side: BorderSide(
                color: seleccionado
                    ? context.colors.primary.withValues(alpha: 0.4)
                    : context.colors.border,
              ),
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile de operación
// ---------------------------------------------------------------------------

class _OperacionTile extends StatelessWidget {
  const _OperacionTile({
    super.key,
    required this.operacion,
    required this.onReintentar,
    required this.onDetalle,
  });

  final OperacionSincronizacionView operacion;
  final VoidCallback onReintentar;
  final VoidCallback onDetalle;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final op = operacion;
    final estadoColor = _EstadosVisibles.color(op.estadoVisual, context);

    return AppCard(
      onTap: onDetalle,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ícono del tipo
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: estadoColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(
              _TiposIcons.icono(op.tipo),
              size: 20,
              color: estadoColor,
            ),
          ),
          const SizedBox(width: 12),
          // Contenido
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        op.titulo,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    _BadgeEstadoVisual(estado: op.estadoVisual),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  op.descripcion,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (op.requiereAtencion) ...[
                  const SizedBox(height: 6),
                  _AlertaRequiereAtencion(operacion: op),
                ],
                if (op.archivos.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoArchivos(archivos: op.archivos),
                ],
                if (op.dependencias.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  _InfoDependencias(dependencias: op.dependencias),
                ],
              ],
            ),
          ),
          // Botón de reintento
          if (op.puedeReintentar) ...[
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              tooltip: 'Reintentar',
              onPressed: onReintentar,
              color: colors.primary,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge de estado visual
// ---------------------------------------------------------------------------

class _BadgeEstadoVisual extends StatelessWidget {
  const _BadgeEstadoVisual({required this.estado});

  final EstadoVisualSincronizacion estado;

  @override
  Widget build(BuildContext context) {
    final color = _EstadosVisibles.color(estado, context);
    final texto = _EstadosVisibles.label(estado);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        texto.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Alerta de requiere atención
// ---------------------------------------------------------------------------

class _AlertaRequiereAtencion extends StatelessWidget {
  const _AlertaRequiereAtencion({required this.operacion});

  final OperacionSincronizacionView operacion;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    String mensaje;
    if (operacion.requiereLogin) {
      mensaje = 'Requiere iniciar sesión';
    } else if (operacion.estadoVisual ==
        EstadoVisualSincronizacion.errorPermanente) {
      mensaje = 'Error permanente';
    } else {
      mensaje = 'Requiere revisión';
    }

    return Row(
      children: [
        Icon(Icons.warning_amber_rounded, size: 14, color: colors.error),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            mensaje,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Info de archivos
// ---------------------------------------------------------------------------

class _InfoArchivos extends StatelessWidget {
  const _InfoArchivos({required this.archivos});

  final List<ArchivoSincronizacionView> archivos;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final cantidad = archivos.length;
    final durables = archivos.where((a) => a.esDurable).length;

    return Row(
      children: [
        Icon(Icons.attach_file_rounded, size: 14, color: colors.textMuted),
        const SizedBox(width: 4),
        Text(
          '$cantidad archivo${cantidad == 1 ? '' : 's'}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
        ),
        if (durables > 0) ...[
          Text(
            ' ($durables en almacenamiento durable)',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Info de dependencias
// ---------------------------------------------------------------------------

class _InfoDependencias extends StatelessWidget {
  const _InfoDependencias({required this.dependencias});

  final List<DependenciaSincronizacionView> dependencias;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Wrap(
      spacing: 4,
      children: [
        Icon(Icons.link_rounded, size: 14, color: colors.textMuted),
        for (final dep in dependencias)
          Text(
            dep.descripcion,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              fontStyle: FontStyle.italic,
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet de detalle
// ---------------------------------------------------------------------------

class _DetalleOperacionSheet extends StatelessWidget {
  const _DetalleOperacionSheet({
    required this.operacion,
    required this.onReintentar,
  });

  final OperacionSincronizacionView operacion;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final op = operacion;
    final estadoColor = _EstadosVisibles.color(op.estadoVisual, context);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Título
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: estadoColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      _TiposIcons.icono(op.tipo),
                      size: 24,
                      color: estadoColor,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          op.titulo,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        _BadgeEstadoVisual(estado: op.estadoVisual),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Descripción
              _DetalleRow(labelo: 'Descripción', valor: op.descripcion),
              _DetalleRow(labelo: 'Tipo', valor: _TiposLabels.label(op.tipo)),
              _DetalleRow(labelo: 'Intentos', valor: '${op.intentos}'),
              if (op.idempotencyKey != null)
                _DetalleRow(
                  labelo: 'Idempotency Key',
                  valor: op.idempotencyKey!,
                ),
              if (op.ultimoError != null)
                _DetalleRow(labelo: 'Último error', valor: op.ultimoError!),
              if (op.codigoError != null)
                _DetalleRow(labelo: 'Código', valor: op.codigoError!),
              if (op.ultimoStatus != null)
                _DetalleRow(labelo: 'HTTP Status', valor: '${op.ultimoStatus}'),
              if (op.proximoIntento != null)
                _DetalleRow(
                  labelo: 'Próximo reintento',
                  valor: _formatearFecha(op.proximoIntento!),
                ),
              if (op.requiereLogin)
                _DetalleRow(
                  labelo: 'Requiere',
                  valor: 'Iniciar sesión',
                  color: colors.error,
                ),
              // Archivos
              if (op.archivos.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Archivos', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final a in op.archivos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          a.esDurable
                              ? Icons.storage_rounded
                              : Icons.folder_outlined,
                          size: 16,
                          color: a.esDurable
                              ? colors.success
                              : colors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            a.nombreArchivo,
                            style: Theme.of(context).textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (a.sizeBytes != null)
                          Text(
                            _formatearTamano(a.sizeBytes!),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.textMuted),
                          ),
                      ],
                    ),
                  ),
              ],
              // Dependencias
              if (op.dependencias.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Dependencias',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                for (final d in op.dependencias)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.link_rounded,
                          size: 16,
                          color: colors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_TiposLabels.label(d.tipo)}: ${d.descripcion}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              // Botón de reintento
              if (op.puedeReintentar) ...[
                const SizedBox(height: 24),
                AppElevatedButton(
                  onPressed: onReintentar,
                  cargando: false,
                  child: const Text('Reintentar ahora'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _DetalleRow extends StatelessWidget {
  const _DetalleRow({required this.labelo, required this.valor, this.color});

  final String labelo;
  final String valor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelo,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barra de sincronización
// ---------------------------------------------------------------------------

class _BarraSincronizar extends StatelessWidget {
  const _BarraSincronizar({
    required this.reintentables,
    required this.sincronizando,
    required this.onSincronizar,
  });

  final int reintentables;
  final bool sincronizando;
  final VoidCallback onSincronizar;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: AppElevatedButton(
          onPressed: (reintentables > 0 && !sincronizando)
              ? onSincronizar
              : () {},
          cargando: sincronizando,
          child: Text(
            sincronizando
                ? 'Sincronizando…'
                : reintentables > 0
                ? 'Sincronizar ahora ($reintentables)'
                : 'Todo sincronizado',
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Estado vacío de filtros
// ---------------------------------------------------------------------------

class _EstadoVacioFiltros extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return EstadoVacio(
      icono: Icons.filter_list_off_rounded,
      mensaje:
          'Sin resultados — no hay operaciones que coincidan con los filtros seleccionados.',
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _EstadosVisibles {
  _EstadosVisibles._();

  static final values = [
    EstadoVisualSincronizacion.errorPermanente,
    EstadoVisualSincronizacion.requiereRevision,
    EstadoVisualSincronizacion.conflicto,
    EstadoVisualSincronizacion.errorTransitorio,
    EstadoVisualSincronizacion.reintentoPendiente,
    EstadoVisualSincronizacion.pendiente,
    EstadoVisualSincronizacion.sincronizando,
    EstadoVisualSincronizacion.completada,
  ];

  static String label(EstadoVisualSincronizacion estado) => switch (estado) {
    EstadoVisualSincronizacion.pendiente => 'Pendiente',
    EstadoVisualSincronizacion.sincronizando => 'Sincronizando',
    EstadoVisualSincronizacion.reintentoPendiente => 'Reintento programado',
    EstadoVisualSincronizacion.errorTransitorio => 'Error transitorio',
    EstadoVisualSincronizacion.errorPermanente => 'Error permanente',
    EstadoVisualSincronizacion.conflicto => 'Conflicto',
    EstadoVisualSincronizacion.completada => 'Completada',
    EstadoVisualSincronizacion.requiereRevision => 'Requiere revisión',
  };

  static Color color(EstadoVisualSincronizacion estado, BuildContext context) {
    final colors = context.colors;
    return switch (estado) {
      EstadoVisualSincronizacion.pendiente => colors.textSecondary,
      EstadoVisualSincronizacion.sincronizando => colors.info,
      EstadoVisualSincronizacion.reintentoPendiente => colors.info,
      EstadoVisualSincronizacion.errorTransitorio => colors.error,
      EstadoVisualSincronizacion.errorPermanente => colors.error,
      EstadoVisualSincronizacion.conflicto => colors.error,
      EstadoVisualSincronizacion.completada => colors.success,
      EstadoVisualSincronizacion.requiereRevision => colors.error,
    };
  }

  static IconData icono(EstadoVisualSincronizacion estado) => switch (estado) {
    EstadoVisualSincronizacion.pendiente => Icons.schedule_outlined,
    EstadoVisualSincronizacion.sincronizando => Icons.sync_rounded,
    EstadoVisualSincronizacion.reintentoPendiente => Icons.timer_outlined,
    EstadoVisualSincronizacion.errorTransitorio => Icons.warning_amber_rounded,
    EstadoVisualSincronizacion.errorPermanente => Icons.error_outline_rounded,
    EstadoVisualSincronizacion.conflicto => Icons.sync_problem_rounded,
    EstadoVisualSincronizacion.completada => Icons.check_circle_outline_rounded,
    EstadoVisualSincronizacion.requiereRevision => Icons.help_outline_rounded,
  };
}

class _TiposLabels {
  _TiposLabels._();

  static String label(TipoOperacionOffline tipo) => switch (tipo) {
    TipoOperacionOffline.solicitud => 'Solicitud',
    TipoOperacionOffline.comprobarCarga => 'Comprobar carga',
    TipoOperacionOffline.cerrarDia => 'Cerrar día',
    TipoOperacionOffline.incidencia => 'Incidencia',
    TipoOperacionOffline.evidencia => 'Evidencia',
    TipoOperacionOffline.recorridoMarimba => 'Recorrido marimba',
    TipoOperacionOffline.despachoMarimba => 'Despacho marimba',
    TipoOperacionOffline.cierreRecorridoMarimba => 'Cierre recorrido',
  };
}

class _TiposIcons {
  _TiposIcons._();

  static IconData icono(TipoOperacionOffline tipo) => switch (tipo) {
    TipoOperacionOffline.solicitud => Icons.local_gas_station_outlined,
    TipoOperacionOffline.comprobarCarga => Icons.receipt_long_outlined,
    TipoOperacionOffline.cerrarDia => Icons.nights_stay_outlined,
    TipoOperacionOffline.incidencia => Icons.warning_amber_outlined,
    TipoOperacionOffline.evidencia => Icons.camera_alt_outlined,
    TipoOperacionOffline.recorridoMarimba => Icons.route_outlined,
    TipoOperacionOffline.despachoMarimba => Icons.local_shipping_outlined,
    TipoOperacionOffline.cierreRecorridoMarimba => Icons.flag_outlined,
  };
}

String _formatearFecha(DateTime fecha) {
  final d = fecha.day.toString().padLeft(2, '0');
  final m = fecha.month.toString().padLeft(2, '0');
  final h = fecha.hour.toString().padLeft(2, '0');
  final min = fecha.minute.toString().padLeft(2, '0');
  return '$d/$m/${fecha.year} $h:$min';
}

String _formatearTamano(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
