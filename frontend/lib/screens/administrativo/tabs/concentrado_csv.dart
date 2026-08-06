import 'package:csv/csv.dart';

import '../../../models/carga.dart';
import '../../../models/cierre_dia.dart';
import '../../../models/perfil.dart';
import '../../../models/vehiculo.dart';
import '../../../widgets/fecha_formato.dart';

/// De dónde salió el gasto de una [FilaConcentrado] — jerarquía de mayor
/// a menor confianza (ver `ConcentradoTab._resolverGasto`):
///   1. [real]: hay una evidencia comprobante vinculada por `carga_id`
///      con `montoPagado` — el gasto REAL pagado en la estación.
///   2. [inferidoPorFolio]: no hay vínculo directo por carga, pero hay
///      exactamente UNA evidencia comprobante para el folio de la
///      solicitud de esta carga — se infiere que es la de esta carga.
///   3. [estimado]: no hay evidencia usable (ninguna, o ambigua — varias
///      cargas o varias evidencias sobre el mismo folio) — se usa el
///      snapshot de referencia (`carga.costoReferencia`), congelado al
///      momento de cargar, nunca recalculado contra el precio de hoy.
///   4. [sinDato]: no hubo snapshot posible (vehículo sin
///      `tipoCombustible` confirmado) — nunca se muestra 0, se muestra
///      "—".
enum FuenteGasto { real, inferidoPorFolio, estimado, sinDato }

/// Una fila resuelta del concentrado: una [Carga] (registro 1) más su
/// [CierreDia] (registro 2) si ya cerró, y los datos derivados
/// (rendimiento, importe) para mostrar en la tabla y para exportar.
///
/// Vive en su propio archivo (sin depender de Flutter/widgets) para que
/// [construirCsvConcentrado] se pueda probar sin montar el árbol de
/// widgets de ConcentradoTab.
class FilaConcentrado {
  FilaConcentrado({
    required this.carga,
    required this.cierre,
    required this.chofer,
    required this.vehiculo,
    required this.rendimiento,
    required this.precioPorLitro,
    required this.importe,
    required this.fuenteGasto,
  });

  final Carga carga;
  final CierreDia? cierre;
  final Perfil? chofer;
  // El vehículo se resuelve por `carga.vehiculoId`, no por el chofer —
  // un chofer puede haber usado distintas unidades en días distintos.
  final Vehiculo? vehiculo;
  final RendimientoDia? rendimiento;

  /// `null` solo cuando [fuenteGasto] es [FuenteGasto.sinDato] — nunca 0.
  final double? precioPorLitro;

  /// El total a mostrar/exportar. NO se deriva de `litros × precioPorLitro`
  /// aquí a propósito: cuando [fuenteGasto] es [FuenteGasto.real] o
  /// [FuenteGasto.inferidoPorFolio], este es el `montoPagado` real del
  /// ticket (la cifra autoritativa), que puede no coincidir centavo a
  /// centavo con ese producto porque litros/precio se capturaron por
  /// separado del monto total. Para [FuenteGasto.estimado] sí es
  /// `carga.costoReferencia` (el snapshot ya redondeado en el backend).
  final double? importe;
  final FuenteGasto fuenteGasto;

  bool get ticketPendiente => carga.fotoTicketPath == null;
  bool get rendimientoAnomalo => rendimiento?.esAnomalo ?? false;
}

/// Arma el CSV del concentrado (encabezado + una fila por carga + fila de
/// totales) — función pura, sin acceso a filesystem ni a Riverpod.
String construirCsvConcentrado(
  List<FilaConcentrado> filas, {
  required double totalLitros,
  required double totalImporte,
}) {
  final filasCsv = <List<dynamic>>[
    const [
      'Fecha',
      'Responsable',
      'Vehículo',
      'Placas / Económico',
      'Km',
      'Litros',
      'Km/L',
      r'$/L',
      'Combustible',
      'Importe',
      'Ticket',
    ],
    for (final fila in filas)
      [
        formatearFechaCorta(fila.carga.creadaEn),
        fila.chofer?.nombreCompleto ?? fila.carga.choferId,
        fila.vehiculo?.modelo ?? fila.vehiculo?.tipoUnidad ?? '',
        fila.vehiculo?.etiquetaUnidad ?? '',
        fila.rendimiento?.kmRecorridos.toStringAsFixed(0) ?? '',
        fila.carga.litrosCargados.toStringAsFixed(1),
        fila.rendimiento?.rendimiento?.toStringAsFixed(1) ?? '',
        fila.precioPorLitro?.toStringAsFixed(2) ?? '—',
        fila.vehiculo?.tipoCombustible ?? '',
        fila.importe?.toStringAsFixed(2) ?? '—',
        fila.ticketPendiente ? 'Pendiente' : 'OK',
      ],
    [
      'TOTALES',
      '',
      '',
      '',
      '',
      totalLitros.toStringAsFixed(1),
      '',
      '',
      '',
      totalImporte.toStringAsFixed(2),
      '',
    ],
  ];
  return const ListToCsvConverter().convert(filasCsv);
}

String _dosDigitos(int numero) => numero.toString().padLeft(2, '0');

/// Ej. "concentrado_20260715_143205.csv" — nombre de archivo con marca de
/// tiempo para no pisar exportaciones anteriores.
String nombreArchivoConcentrado(DateTime momento) {
  final fecha =
      '${momento.year}${_dosDigitos(momento.month)}${_dosDigitos(momento.day)}';
  final hora =
      '${_dosDigitos(momento.hour)}${_dosDigitos(momento.minute)}${_dosDigitos(momento.second)}';
  return 'concentrado_${fecha}_$hora.csv';
}
