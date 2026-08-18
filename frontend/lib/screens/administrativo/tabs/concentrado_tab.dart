import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/semana_util.dart';
import '../../../models/carga.dart';
import '../../../models/evidencia.dart';
import '../../../models/solicitud_autorizacion.dart';
import '../../../theme/app_motion.dart';
import '../../../theme/app_radii.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/celda_editable.dart';
import '../../../widgets/estado_vacio.dart';
import '../../../widgets/fecha_formato.dart';
import '../../../widgets/filtro_columna_boton.dart';
import '../../../widgets/formato_numero.dart';
import '../../../widgets/ios_segmented_control.dart';
import '../../../widgets/contenido_responsivo.dart';
import 'concentrado_csv.dart';

enum _Periodo { dia, semana, mes, anio }

typedef _Gasto = ({
  double? precioPorLitro,
  double? importe,
  FuenteGasto fuente,
});

/// Resuelve, para CADA carga, de dónde sale su gasto — jerarquía completa
/// en [FuenteGasto]. Nunca recalcula contra el precio de HOY (ese era el
/// bug de este archivo, ver migración 0029): la fuente es siempre una
/// evidencia real capturada por el chofer, o el snapshot de referencia
/// congelado al momento de la carga (`carga.costoReferencia`).
///
/// Sobre TODAS las cargas/evidencias (no solo las del periodo elegido en
/// pantalla) — la ambigüedad "esta solicitud tiene más de una carga" es
/// una propiedad de los datos, no debe cambiar según qué periodo esté
/// viendo el admin en este momento.
Map<String, _Gasto> _resolverGastoPorCarga({
  required List<Carga> todasLasCargas,
  required List<Evidencia> todasLasEvidencias,
  required List<SolicitudAutorizacion> todasLasSolicitudes,
}) {
  final evidenciasComprobante = todasLasEvidencias.where(
    (e) => e.tipo == TipoEvidencia.comprobante && e.montoPagado != null,
  );

  final evidenciasPorCarga = <String, List<Evidencia>>{};
  final evidenciasPorSolicitud = <String, List<Evidencia>>{};
  for (final e in evidenciasComprobante) {
    if (e.cargaId != null) {
      evidenciasPorCarga.putIfAbsent(e.cargaId!, () => []).add(e);
    } else if (e.folioId != null) {
      evidenciasPorSolicitud.putIfAbsent(e.folioId!, () => []).add(e);
    }
  }

  // `carga.folioAutorizacion` es el folio TEXTO (ej. "FA-0042");
  // `evidencia.folioId` es el id (uuid) de la SOLICITUD — son
  // identificadores distintos del mismo folio, hace falta este puente.
  final solicitudIdPorFolio = {
    for (final s in todasLasSolicitudes)
      if (s.folioAutorizacion != null) s.folioAutorizacion!: s.id,
  };

  // Cuántas cargas comparten cada folio — si son 2+, "hay una sola
  // evidencia para el folio" ya no basta para saber a CUÁL le pertenece.
  final cargasPorFolio = <String, int>{};
  for (final c in todasLasCargas) {
    cargasPorFolio[c.folioAutorizacion] =
        (cargasPorFolio[c.folioAutorizacion] ?? 0) + 1;
  }

  return {
    for (final carga in todasLasCargas)
      carga.id: () {
        // 1. Evidencia vinculada DIRECTO a esta carga — gasto real, sin
        //    ambigüedad posible (la FK ya identifica la carga exacta).
        final porCarga = evidenciasPorCarga[carga.id];
        if (porCarga != null && porCarga.length == 1) {
          final e = porCarga.single;
          return (
            precioPorLitro: e.precioPorLitro,
            importe: e.montoPagado,
            fuente: FuenteGasto.real,
          );
        }

        // 2. Exactamente una evidencia comprobante para el folio de esta
        //    carga, Y esta carga es la única con ese folio — se infiere
        //    que es la de esta carga.
        final solicitudId = solicitudIdPorFolio[carga.folioAutorizacion];
        final porSolicitud = solicitudId == null
            ? null
            : evidenciasPorSolicitud[solicitudId];
        final folioSinAmbiguedad =
            (cargasPorFolio[carga.folioAutorizacion] ?? 0) <= 1;
        if (porSolicitud != null &&
            porSolicitud.length == 1 &&
            folioSinAmbiguedad) {
          final e = porSolicitud.single;
          return (
            precioPorLitro: e.precioPorLitro,
            importe: e.montoPagado,
            fuente: FuenteGasto.inferidoPorFolio,
          );
        }

        // 3. Ambiguo (N cargas o M evidencias sobre el mismo folio) o sin
        //    evidencia todavía — snapshot de referencia congelado al
        //    momento de la carga, nunca el precio de hoy.
        if (carga.costoReferencia != null) {
          return (
            precioPorLitro: carga.precioReferenciaPorLitro,
            importe: carga.costoReferencia,
            fuente: FuenteGasto.estimado,
          );
        }

        // 4. Sin snapshot posible (vehículo sin tipoCombustible
        //    confirmado) — nunca 0, "—" en la UI.
        return (
          precioPorLitro: null,
          importe: null,
          fuente: FuenteGasto.sinDato,
        );
      }(),
  };
}

/// Pestaña "Concentrado": tabla de todas las cargas de combustible,
/// filtrable por periodo Y por columna (chofer, vehículo, combustible,
/// ticket — estilo Excel), con litros/km editables directo en la celda
/// (corrección administrativa, queda en auditoría del lado del backend) y
/// anomalías de rendimiento/tickets pendientes resaltados.
class ConcentradoTab extends ConsumerStatefulWidget {
  const ConcentradoTab({super.key});

  @override
  ConsumerState<ConcentradoTab> createState() => _ConcentradoTabState();
}

class _ConcentradoTabState extends ConsumerState<ConcentradoTab> {
  _Periodo _periodo = _Periodo.semana;

  // Filtros por columna estilo Excel — vacío significa "todos". Se
  // aplican DESPUÉS del filtro de periodo.
  Set<String> _filtroChoferes = {};
  Set<String> _filtroVehiculos = {};
  Set<String> _filtroCombustibles = {};
  Set<bool> _filtroTicket = {};

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
      final contenido = construirXlsxConcentrado(
        filas,
        totalLitros: totalLitros,
        totalImporte: totalImporte,
      );
      await ref
          .read(exportadorServiceProvider)
          .exportarXlsx(
            nombreArchivo: nombreArchivoConcentrado(DateTime.now()),
            contenido: contenido,
            descripcion: 'Concentrado de cargas de combustible',
          );
    } catch (_) {
      mensajero.showSnackBar(
        const SnackBar(
          content: Text('No pudimos preparar el archivo. Intenta de nuevo.'),
        ),
      );
    }
  }

  Future<void> _editarLitros(FilaConcentrado fila, double nuevo) async {
    final repo = ref.read(operacionesRepositoryProvider);
    await repo.editarCarga(cargaId: fila.carga.id, litrosCargados: nuevo);
    ref.read(operacionesTickProvider.notifier).state++;
  }

  Future<void> _editarKm(FilaConcentrado fila, double nuevo) async {
    final repo = ref.read(operacionesRepositoryProvider);
    await repo.editarCarga(cargaId: fila.carga.id, kmAlCargar: nuevo);
    ref.read(operacionesTickProvider.notifier).state++;
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
    final cargasDelPeriodo = repo.todasLasCargas
        .where((c) => _dentroDelPeriodo(c.creadaEn, hoy))
        .toList();

    final gastoPorCarga = _resolverGastoPorCarga(
      todasLasCargas: repo.todasLasCargas,
      todasLasEvidencias: ref
          .watch(evidenciasRepositoryProvider)
          .todasLasEvidencias,
      todasLasSolicitudes: repo.todasLasSolicitudes,
    );

    final filasDelPeriodo = cargasDelPeriodo.map((carga) {
      final cierre = repo.cierreDe(carga);
      final chofer = choferesPorId[carga.choferId];
      final vehiculo = vehiculosRepo.porId(carga.vehiculoId);
      final gasto = gastoPorCarga[carga.id]!;
      return FilaConcentrado(
        carga: carga,
        cierre: cierre,
        chofer: chofer,
        vehiculo: vehiculo,
        rendimiento: cierre == null ? null : repo.rendimientoDe(cierre),
        precioPorLitro: gasto.precioPorLitro,
        importe: gasto.importe,
        fuenteGasto: gasto.fuente,
      );
    }).toList();

    // Opciones de cada filtro: se calculan sobre el periodo ya elegido
    // (no sobre el resultado ya filtrado por otras columnas), para que la
    // lista de opciones no se vaya encogiendo sola al combinar filtros.
    final opcionesChofer = {
      for (final f in filasDelPeriodo)
        if (f.chofer != null) f.chofer!.nombreCompleto,
    }.toList()..sort();
    final opcionesVehiculo = {
      for (final f in filasDelPeriodo)
        if (f.vehiculo != null) f.vehiculo!.etiquetaUnidad,
    }.toList()..sort();
    final opcionesCombustible = {
      for (final f in filasDelPeriodo)
        if (f.vehiculo?.tipoCombustible != null) f.vehiculo!.tipoCombustible!,
    }.toList()..sort();

    final filas = filasDelPeriodo.where((f) {
      if (_filtroChoferes.isNotEmpty &&
          !_filtroChoferes.contains(f.chofer?.nombreCompleto)) {
        return false;
      }
      if (_filtroVehiculos.isNotEmpty &&
          !_filtroVehiculos.contains(f.vehiculo?.etiquetaUnidad)) {
        return false;
      }
      if (_filtroCombustibles.isNotEmpty &&
          !_filtroCombustibles.contains(f.vehiculo?.tipoCombustible)) {
        return false;
      }
      if (_filtroTicket.isNotEmpty &&
          !_filtroTicket.contains(f.ticketPendiente)) {
        return false;
      }
      return true;
    }).toList();

    final totalLitros = filas.fold(0.0, (s, f) => s + f.carga.litrosCargados);
    final totalImporte = filas.fold(0.0, (s, f) => s + (f.importe ?? 0));
    final hayFiltrosDeColumna =
        _filtroChoferes.isNotEmpty ||
        _filtroVehiculos.isNotEmpty ||
        _filtroCombustibles.isNotEmpty ||
        _filtroTicket.isNotEmpty;

    return ContenidoResponsivo(
      maxWidth: 1300,
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
          Row(
            children: [
              Expanded(
                child: IosSegmentedControl<_Periodo>(
                  valor: _periodo,
                  opciones: const {
                    _Periodo.dia: 'Día',
                    _Periodo.semana: 'Semana',
                    _Periodo.mes: 'Mes',
                    _Periodo.anio: 'Año',
                  },
                  onChanged: (p) => setState(() => _periodo = p),
                ),
              ),
              if (hayFiltrosDeColumna) ...[
                const SizedBox(width: 12),
                TextButton.icon(
                  onPressed: () => setState(() {
                    _filtroChoferes = {};
                    _filtroVehiculos = {};
                    _filtroCombustibles = {};
                    _filtroTicket = {};
                  }),
                  icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
                  label: const Text('Quitar filtros'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: KeyedSubtree(
              key: ValueKey((_periodo, filas.length, hayFiltrosDeColumna)),
              child: filas.isEmpty
                  ? SizedBox(
                      // Le da presencia vertical real al estado vacío en
                      // vez de dejarlo compacto pegado arriba con un
                      // vacío grande debajo (mala sensación de balance en
                      // monitores anchos/altos) — no usa `Expanded` para
                      // evitar el error clásico de Flutter de "flex
                      // hijo con alto entrante no acotado" dentro de un
                      // `SingleChildScrollView`.
                      height: MediaQuery.sizeOf(context).height * 0.4,
                      child: Center(
                        child: EstadoVacio(
                          icono: Icons.table_chart_outlined,
                          mensaje: hayFiltrosDeColumna
                              ? 'Ninguna carga coincide con los filtros elegidos.'
                              : 'No hay cargas registradas en este periodo.',
                        ),
                      ),
                    )
                  : _TablaConcentrado(
                      filas: filas,
                      totalLitros: totalLitros,
                      totalImporte: totalImporte,
                      opcionesChofer: opcionesChofer,
                      opcionesVehiculo: opcionesVehiculo,
                      opcionesCombustible: opcionesCombustible,
                      filtroChoferes: _filtroChoferes,
                      filtroVehiculos: _filtroVehiculos,
                      filtroCombustibles: _filtroCombustibles,
                      filtroTicket: _filtroTicket,
                      onCambiarFiltroChoferes: (v) =>
                          setState(() => _filtroChoferes = v),
                      onCambiarFiltroVehiculos: (v) =>
                          setState(() => _filtroVehiculos = v),
                      onCambiarFiltroCombustibles: (v) =>
                          setState(() => _filtroCombustibles = v),
                      onCambiarFiltroTicket: (v) =>
                          setState(() => _filtroTicket = v),
                      onEditarLitros: _editarLitros,
                      onEditarKm: _editarKm,
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
              _Leyenda(
                color: colors.primary,
                texto: 'Celda editable (toca para corregir)',
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
    required this.opcionesChofer,
    required this.opcionesVehiculo,
    required this.opcionesCombustible,
    required this.filtroChoferes,
    required this.filtroVehiculos,
    required this.filtroCombustibles,
    required this.filtroTicket,
    required this.onCambiarFiltroChoferes,
    required this.onCambiarFiltroVehiculos,
    required this.onCambiarFiltroCombustibles,
    required this.onCambiarFiltroTicket,
    required this.onEditarLitros,
    required this.onEditarKm,
  });

  final List<FilaConcentrado> filas;
  final double totalLitros;
  final double totalImporte;

  final List<String> opcionesChofer;
  final List<String> opcionesVehiculo;
  final List<String> opcionesCombustible;
  final Set<String> filtroChoferes;
  final Set<String> filtroVehiculos;
  final Set<String> filtroCombustibles;
  final Set<bool> filtroTicket;
  final ValueChanged<Set<String>> onCambiarFiltroChoferes;
  final ValueChanged<Set<String>> onCambiarFiltroVehiculos;
  final ValueChanged<Set<String>> onCambiarFiltroCombustibles;
  final ValueChanged<Set<bool>> onCambiarFiltroTicket;
  final Future<void> Function(FilaConcentrado fila, double nuevo)
  onEditarLitros;
  final Future<void> Function(FilaConcentrado fila, double nuevo) onEditarKm;

  static const _anchos = <double>[76, 150, 130, 90, 60, 70, 60, 60, 80, 90, 60];

  Widget _celdaTexto(
    BuildContext context,
    String texto, {
    TextStyle? estilo,
    Color? color,
  }) {
    final colors = context.colors;
    final base =
        estilo ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colors.textPrimary,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return Text(
      texto,
      style: color == null ? base : base?.copyWith(color: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final estiloEncabezado = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: colors.textMuted,
      fontWeight: FontWeight.w700,
    );

    Widget encabezado(String texto, {Widget? filtro}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              texto,
              style: estiloEncabezado,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ?filtro,
        ],
      );
    }

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
                celdas: [
                  encabezado('FECHA'),
                  encabezado(
                    'RESPONSABLE',
                    filtro: FiltroColumnaBoton<String>(
                      titulo: 'responsable',
                      opciones: opcionesChofer,
                      etiquetaDe: (v) => v,
                      seleccionados: filtroChoferes,
                      onCambiar: onCambiarFiltroChoferes,
                    ),
                  ),
                  encabezado(
                    'VEHÍCULO',
                    filtro: FiltroColumnaBoton<String>(
                      titulo: 'vehículo',
                      opciones: opcionesVehiculo,
                      etiquetaDe: (v) => v,
                      seleccionados: filtroVehiculos,
                      onCambiar: onCambiarFiltroVehiculos,
                    ),
                  ),
                  encabezado('PLACAS'),
                  encabezado('KM'),
                  encabezado('LITROS'),
                  encabezado('KM/L'),
                  encabezado('\$/L'),
                  encabezado(
                    'COMB.',
                    filtro: FiltroColumnaBoton<String>(
                      titulo: 'combustible',
                      opciones: opcionesCombustible,
                      etiquetaDe: (v) => v,
                      seleccionados: filtroCombustibles,
                      onCambiar: onCambiarFiltroCombustibles,
                    ),
                  ),
                  encabezado('IMPORTE'),
                  encabezado(
                    'TICKET',
                    filtro: FiltroColumnaBoton<bool>(
                      titulo: 'ticket',
                      opciones: const [true, false],
                      etiquetaDe: (v) => v ? 'Pendiente' : 'Completo',
                      seleccionados: filtroTicket,
                      onCambiar: onCambiarFiltroTicket,
                    ),
                  ),
                ],
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
                    _celdaTexto(
                      context,
                      formatearFechaCorta(fila.carga.creadaEn).split(',').first,
                    ),
                    _celdaTexto(
                      context,
                      fila.chofer?.nombreCompleto ?? fila.carga.choferId,
                    ),
                    _celdaTexto(
                      context,
                      fila.vehiculo?.modelo ?? fila.vehiculo?.tipoUnidad ?? '—',
                    ),
                    _celdaTexto(context, fila.vehiculo?.etiquetaUnidad ?? '—'),
                    CeldaEditable(
                      valor: fila.carga.kmAlCargar,
                      decimales: 0,
                      estilo: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: fila.rendimientoAnomalo
                            ? colors.error
                            : colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      onGuardar: (nuevo) => onEditarKm(fila, nuevo),
                    ),
                    CeldaEditable(
                      valor: fila.carga.litrosCargados,
                      decimales: 1,
                      estilo: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.textPrimary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      onGuardar: (nuevo) => onEditarLitros(fila, nuevo),
                    ),
                    _celdaTexto(
                      context,
                      fila.rendimiento?.rendimiento == null
                          ? 'n/a'
                          : fila.rendimiento!.rendimiento!.toStringAsFixed(1),
                    ),
                    // 'estimado' se marca con color muted — es un
                    // snapshot de referencia, no el gasto real pagado en
                    // el ticket (ver FuenteGasto). Nunca se muestra "0"
                    // cuando no hubo snapshot posible (sinDato) — "—".
                    _celdaTexto(
                      context,
                      fila.precioPorLitro?.toStringAsFixed(2) ?? '—',
                      color: fila.fuenteGasto == FuenteGasto.estimado
                          ? colors.textMuted
                          : null,
                    ),
                    _celdaTexto(context, fila.vehiculo?.tipoCombustible ?? '—'),
                    _celdaTexto(
                      context,
                      fila.importe == null
                          ? '—'
                          : '${fila.fuenteGasto == FuenteGasto.estimado ? "~" : ""}${formatearMonedaDecimal(fila.importe!)}',
                      color: fila.fuenteGasto == FuenteGasto.estimado
                          ? colors.textMuted
                          : null,
                    ),
                    _celdaTexto(
                      context,
                      fila.ticketPendiente ? 'pend.' : '✓',
                      color: fila.ticketPendiente ? colors.warning : null,
                    ),
                  ],
                ),
              _FilaTabla(
                anchos: _anchos,
                fondo: colors.info.withValues(alpha: 0.08),
                celdas: [
                  _celdaTexto(
                    context,
                    'TOTALES',
                    estilo: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  _celdaTexto(
                    context,
                    totalLitros.toStringAsFixed(1),
                    estilo: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  _celdaTexto(
                    context,
                    formatearMonedaDecimal(totalImporte),
                    estilo: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaTabla extends StatelessWidget {
  const _FilaTabla({required this.anchos, required this.celdas, this.fondo});

  final List<double> anchos;
  final List<Widget> celdas;
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: fondo,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: List.generate(
          celdas.length,
          (i) => SizedBox(width: anchos[i], child: celdas[i]),
        ),
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
