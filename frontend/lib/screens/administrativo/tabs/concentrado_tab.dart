import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/semana_util.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/fecha_formato.dart';
import '../../../widgets/ios_segmented_control.dart';
import '../../../widgets/responsive_scroll_view.dart';
import 'concentrado_csv.dart';

enum _Periodo { dia, semana, mes, anio }

/// Pestaña "Concentrado": tabla de todas las cargas de combustible,
/// filtrable por periodo, con anomalías de rendimiento y tickets
/// pendientes resaltados — el reporte que usaría finanzas/auditoría.
class ConcentradoTab extends ConsumerStatefulWidget {
  const ConcentradoTab({super.key});

  @override
  ConsumerState<ConcentradoTab> createState() => _ConcentradoTabState();
}

class _ConcentradoTabState extends ConsumerState<ConcentradoTab> {
  _Periodo _periodo = _Periodo.semana;

  bool _dentroDelPeriodo(DateTime fecha, DateTime hoy) {
    switch (_periodo) {
      case _Periodo.dia:
        return fecha.year == hoy.year &&
            fecha.month == hoy.month &&
            fecha.day == hoy.day;
      case _Periodo.semana:
        return estaEnSemanaDe(fecha, hoy);
      case _Periodo.mes:
        return fecha.year == hoy.year && fecha.month == hoy.month;
      case _Periodo.anio:
        return fecha.year == hoy.year;
    }
  }

  Future<void> _exportar(
    List<FilaConcentrado> filas,
    double totalLitros,
    double totalImporte,
  ) async {
    final mensajero = ScaffoldMessenger.of(context);
    try {
      final contenidoCsv = construirCsvConcentrado(
        filas,
        totalLitros: totalLitros,
        totalImporte: totalImporte,
      );
      await ref
          .read(exportadorServiceProvider)
          .exportarCsv(
            nombreArchivo: nombreArchivoConcentrado(DateTime.now()),
            contenidoCsv: contenidoCsv,
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
    final repo = ref.watch(operacionesRepositoryProvider);
    ref.watch(operacionesTickProvider);
    final choferes = ref.watch(authRepositoryProvider).listarChoferes();
    final choferesPorId = {for (final c in choferes) c.id: c};
    final vehiculosRepo = ref.watch(vehiculosRepositoryProvider);

    final hoy = DateTime.now();
    final cargas = repo.todasLasCargas
        .where((c) => _dentroDelPeriodo(c.creadaEn, hoy))
        .toList();

    final filas = cargas.map((carga) {
      final cierre = repo.cierreDe(carga);
      final chofer = choferesPorId[carga.choferId];
      final vehiculo = vehiculosRepo.porId(carga.vehiculoId);
      final precioPorLitro = vehiculo == null
          ? 0.0
          : repo.precios
                .firstWhere(
                  (p) => p.tipoCombustible == vehiculo.tipoCombustible,
                  orElse: () => repo.precios.first,
                )
                .precioPorLitro;
      return FilaConcentrado(
        carga: carga,
        cierre: cierre,
        chofer: chofer,
        vehiculo: vehiculo,
        rendimiento: cierre == null ? null : repo.rendimientoDe(cierre),
        precioPorLitro: precioPorLitro,
      );
    }).toList();

    final totalLitros = filas.fold(0.0, (s, f) => s + f.carga.litrosCargados);
    final totalImporte = filas.fold(0.0, (s, f) => s + f.importe);

    return ResponsiveScrollView(
      maxWidth: 1100,
      primary: false,
      physics: const ClampingScrollPhysics(),
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
                      'Concentrado de cargas',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Historial de cargas de combustible, con alertas de auditoría.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportar(filas, totalLitros, totalImporte),
                icon: const Icon(Icons.download_outlined),
                label: const Text('Exportar Excel'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          IosSegmentedControl<_Periodo>(
            valor: _periodo,
            opciones: const {
              _Periodo.dia: 'Día',
              _Periodo.semana: 'Semana',
              _Periodo.mes: 'Mes',
              _Periodo.anio: 'Año',
            },
            onChanged: (p) => setState(() => _periodo = p),
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey(_periodo),
              child: filas.isEmpty
                  ? const EstadoVacio(
                      icono: Icons.table_chart_outlined,
                      mensaje: 'No hay cargas registradas en este periodo.',
                    )
                  : _TablaConcentrado(
                      filas: filas,
                      totalLitros: totalLitros,
                      totalImporte: totalImporte,
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _Leyenda(
                color: colors.error,
                texto: 'Rendimiento anómalo (alerta)',
              ),
              _Leyenda(
                color: colors.warning,
                texto: 'Ticket pendiente de subir',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TablaConcentrado extends StatelessWidget {
  const _TablaConcentrado({
    required this.filas,
    required this.totalLitros,
    required this.totalImporte,
  });

  final List<FilaConcentrado> filas;
  final double totalLitros;
  final double totalImporte;

  static const _anchos = <double>[76, 150, 130, 90, 60, 70, 60, 60, 80, 90, 60];

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: colors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        primary: false,
        physics: const ClampingScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: _anchos.reduce((a, b) => a + b),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FilaTabla(
                anchos: _anchos,
                fondo: colors.surfaceAlt,
                celdas: const [
                  'FECHA',
                  'RESPONSABLE',
                  'VEHÍCULO',
                  'PLACAS',
                  'KM',
                  'LITROS',
                  'KM/L',
                  '\$/L',
                  'COMB.',
                  'IMPORTE',
                  'TICKET',
                ],
                estilo: (context) =>
                    Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              for (final fila in filas)
                _FilaTabla(
                  anchos: _anchos,
                  fondo: fila.rendimientoAnomalo
                      ? colors.error.withValues(alpha: 0.07)
                      : fila.ticketPendiente
                      ? colors.warning.withValues(alpha: 0.08)
                      : null,
                  celdas: [
                    formatearFechaCorta(fila.carga.creadaEn).split(',').first,
                    fila.chofer?.nombreCompleto ?? fila.carga.choferId,
                    fila.vehiculo?.modelo ?? fila.vehiculo?.tipoUnidad ?? '—',
                    fila.vehiculo?.identificador ?? '—',
                    fila.rendimiento == null
                        ? '—'
                        : fila.rendimiento!.kmRecorridos.toStringAsFixed(0),
                    fila.carga.litrosCargados.toStringAsFixed(1),
                    fila.rendimiento?.rendimiento == null
                        ? 'n/a'
                        : fila.rendimiento!.rendimiento!.toStringAsFixed(1),
                    fila.precioPorLitro.toStringAsFixed(2),
                    fila.vehiculo?.tipoCombustible ?? '—',
                    '\$${fila.importe.toStringAsFixed(2)}',
                    fila.ticketPendiente ? 'pend.' : '✓',
                  ],
                  colorTexto: (i) {
                    if (i == 4 && fila.rendimientoAnomalo) return colors.error;
                    if (i == 10 && fila.ticketPendiente) return colors.warning;
                    return null;
                  },
                ),
              _FilaTabla(
                anchos: _anchos,
                fondo: colors.info.withValues(alpha: 0.08),
                celdas: [
                  'TOTALES',
                  '',
                  '',
                  '',
                  '',
                  totalLitros.toStringAsFixed(1),
                  '',
                  '',
                  '',
                  '\$${totalImporte.toStringAsFixed(2)}',
                  '',
                ],
                estilo: (context) =>
                    Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaTabla extends StatelessWidget {
  const _FilaTabla({
    required this.anchos,
    required this.celdas,
    this.fondo,
    this.estilo,
    this.colorTexto,
  });

  final List<double> anchos;
  final List<String> celdas;
  final Color? fondo;
  final TextStyle? Function(BuildContext)? estilo;
  final Color? Function(int indice)? colorTexto;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estiloBase =
        estilo?.call(context) ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        );

    return Container(
      color: fondo,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List.generate(celdas.length, (i) {
          final colorCelda = colorTexto?.call(i);
          return SizedBox(
            width: anchos[i],
            child: Text(
              celdas[i],
              style: colorCelda == null
                  ? estiloBase
                  : estiloBase?.copyWith(color: colorCelda),
            ),
          );
        }),
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.color, required this.texto});

  final Color color;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          texto,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.colors.textMuted),
        ),
      ],
    );
  }
}
