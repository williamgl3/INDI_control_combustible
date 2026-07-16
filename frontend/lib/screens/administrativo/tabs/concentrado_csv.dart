import 'package:csv/csv.dart';

import '../../../models/carga.dart';
import '../../../models/cierre_dia.dart';
import '../../../models/perfil.dart';
import '../../../widgets/fecha_formato.dart';

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
    required this.rendimiento,
    required this.precioPorLitro,
  });

  final Carga carga;
  final CierreDia? cierre;
  final Perfil? chofer;
  final RendimientoDia? rendimiento;
  final double precioPorLitro;

  double get importe => carga.litrosCargados * precioPorLitro;
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
      'Placas',
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
        fila.chofer?.vehiculo?.modelo ?? '',
        fila.chofer?.vehiculo?.placaONumeroEconomico ?? '',
        fila.rendimiento?.kmRecorridos.toStringAsFixed(0) ?? '',
        fila.carga.litrosCargados.toStringAsFixed(1),
        fila.rendimiento?.rendimiento?.toStringAsFixed(1) ?? '',
        fila.precioPorLitro.toStringAsFixed(2),
        fila.chofer?.vehiculo?.tipoCombustible ?? '',
        fila.importe.toStringAsFixed(2),
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
  final fecha = '${momento.year}${_dosDigitos(momento.month)}${_dosDigitos(momento.day)}';
  final hora =
      '${_dosDigitos(momento.hour)}${_dosDigitos(momento.minute)}${_dosDigitos(momento.second)}';
  return 'concentrado_${fecha}_$hora.csv';
}
