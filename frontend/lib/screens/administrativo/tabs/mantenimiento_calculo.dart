import 'dart:typed_data';

import 'package:csv/csv.dart';

import '../../../core/xlsx_document.dart';
import '../../../core/intervalo_mantenimiento.dart';
import '../../../models/vehiculo.dart';
import '../../../widgets/fecha_formato.dart';

/// Umbral de "próximo" — cuando el uso desde el último servicio ya
/// alcanzó este porcentaje del intervalo (85%).
const _umbralProximo = 0.85;

enum EstadoMantenimiento { noConfigurado, alDia, proximo, vencido, sinDatos }

/// Diagnóstico de mantenimiento preventivo de un [Vehiculo] — función pura
/// (sin acceso a Riverpod/filesystem) para que se pueda probar sin montar
/// widgets, siguiendo el mismo patrón que `concentrado_csv.dart`.
class DiagnosticoMantenimiento {
  const DiagnosticoMantenimiento({
    required this.vehiculo,
    required this.estado,
    this.lecturaActual,
    this.usoDesdeServicio,
    this.restante,
    this.fechaProyectada,
  });

  final Vehiculo vehiculo;
  final EstadoMantenimiento estado;

  /// Lectura del medidor más reciente conocida (km u horas). `null` si no
  /// hay ninguna carga/cierre registrado todavía para esta unidad.
  final double? lecturaActual;

  /// Uso acumulado desde el último servicio (o desde la primera lectura
  /// conocida, si nunca se ha registrado un servicio).
  final double? usoDesdeServicio;

  /// Cuánto falta (en km/horas) para el próximo servicio. Negativo si ya
  /// se pasó del intervalo.
  final double? restante;

  /// Fecha estimada del próximo servicio, proyectada con la tasa de uso
  /// histórica de la unidad. `null` si no hay suficiente historial para
  /// proyectar, o si ya está vencido.
  final DateTime? fechaProyectada;
}

class ResumenMantenimiento {
  const ResumenMantenimiento({
    required this.vencidos,
    required this.proximos,
    required this.noConfigurados,
  });

  final int vencidos;
  final int proximos;
  final int noConfigurados;
}

ResumenMantenimiento resumirMantenimiento(
  List<DiagnosticoMantenimiento> diagnosticos,
) => ResumenMantenimiento(
  vencidos: diagnosticos
      .where((d) => d.estado == EstadoMantenimiento.vencido)
      .length,
  proximos: diagnosticos
      .where((d) => d.estado == EstadoMantenimiento.proximo)
      .length,
  noConfigurados: diagnosticos
      .where((d) => d.estado == EstadoMantenimiento.noConfigurado)
      .length,
);

List<DiagnosticoMantenimiento> filtrarMantenimiento(
  List<DiagnosticoMantenimiento> diagnosticos,
  EstadoMantenimiento? estado,
) => estado == null
    ? diagnosticos
    : diagnosticos.where((d) => d.estado == estado).toList();

/// Calcula el diagnóstico de mantenimiento de un vehículo a partir de su
/// historial de lecturas del medidor (ver
/// `MockOperacionesRepository.historialLecturas`).
DiagnosticoMantenimiento calcularMantenimiento({
  required Vehiculo vehiculo,
  required List<({DateTime fecha, double lectura})> historial,
  required DateTime ahora,
}) {
  final intervalo = vehiculo.intervaloServicio;
  if (!intervaloMantenimientoConfigurado(intervalo)) {
    return DiagnosticoMantenimiento(
      vehiculo: vehiculo,
      estado: EstadoMantenimiento.noConfigurado,
    );
  }

  if (historial.isEmpty && vehiculo.lecturaUltimoServicio == null) {
    return DiagnosticoMantenimiento(
      vehiculo: vehiculo,
      estado: EstadoMantenimiento.sinDatos,
    );
  }

  final lecturaActual = historial.isEmpty
      ? vehiculo.lecturaUltimoServicio!
      : historial.map((h) => h.lectura).reduce((a, b) => a > b ? a : b);

  final lecturaBase = vehiculo.lecturaUltimoServicio ?? historial.first.lectura;
  final fechaBase = vehiculo.fechaUltimoServicio ?? historial.first.fecha;

  final usoDesdeServicio = lecturaActual - lecturaBase;
  final restante = intervalo! - usoDesdeServicio;

  final diasTranscurridos = ahora.difference(fechaBase).inDays;
  final tasaPorDia = diasTranscurridos > 0
      ? usoDesdeServicio / diasTranscurridos
      : 0.0;

  DateTime? fechaProyectada;
  if (restante > 0 && tasaPorDia > 0) {
    fechaProyectada = ahora.add(Duration(days: (restante / tasaPorDia).ceil()));
  }

  final estado = restante <= 0
      ? EstadoMantenimiento.vencido
      : usoDesdeServicio >= intervalo * _umbralProximo
      ? EstadoMantenimiento.proximo
      : EstadoMantenimiento.alDia;

  return DiagnosticoMantenimiento(
    vehiculo: vehiculo,
    estado: estado,
    lecturaActual: lecturaActual,
    usoDesdeServicio: usoDesdeServicio,
    restante: restante,
    fechaProyectada: fechaProyectada,
  );
}

/// Arma el CSV del reporte de mantenimiento — función pura, para que el
/// área encargada de servicio mecánico lo descargue y agilice su trabajo.
String construirCsvMantenimiento(List<DiagnosticoMantenimiento> diagnosticos) {
  final filasCsv = <List<dynamic>>[
    const [
      'Unidad',
      'Tipo',
      'Lectura actual',
      'Uso desde último servicio',
      'Intervalo de servicio',
      'Restante',
      'Fecha proyectada',
      'Estado',
    ],
    for (final d in diagnosticos)
      [
        d.vehiculo.etiquetaUnidad,
        d.vehiculo.tipoUnidad,
        d.lecturaActual?.toStringAsFixed(0) ?? '',
        d.usoDesdeServicio?.toStringAsFixed(0) ?? '',
        intervaloMantenimientoConfigurado(d.vehiculo.intervaloServicio)
            ? d.vehiculo.intervaloServicio!.toStringAsFixed(0)
            : 'No configurado',
        d.estado == EstadoMantenimiento.noConfigurado
            ? 'No aplica'
            : d.restante?.toStringAsFixed(0) ?? '',
        d.fechaProyectada != null
            ? formatearFechaCorta(d.fechaProyectada!)
            : '',
        _etiquetaEstado(d.estado),
      ],
  ];
  return const ListToCsvConverter().convert(filasCsv);
}

Uint8List construirXlsxMantenimiento(
  List<DiagnosticoMantenimiento> diagnosticos,
) {
  return construirXlsx(
    nombreHoja: 'Mantenimiento',
    encabezados: const [
      'Unidad',
      'Tipo',
      'Lectura actual',
      'Uso desde último servicio',
      'Intervalo de servicio',
      'Restante',
      'Fecha proyectada',
      'Estado',
    ],
    anchos: const [22, 18, 17, 25, 23, 15, 20, 22],
    filas: [
      for (final d in diagnosticos)
        [
          XlsxCell.text(d.vehiculo.etiquetaUnidad),
          XlsxCell.text(d.vehiculo.tipoUnidad),
          XlsxCell.number(d.lecturaActual, style: XlsxCellStyle.oneDecimal),
          XlsxCell.number(d.usoDesdeServicio, style: XlsxCellStyle.oneDecimal),
          intervaloMantenimientoConfigurado(d.vehiculo.intervaloServicio)
              ? XlsxCell.number(
                  d.vehiculo.intervaloServicio,
                  style: XlsxCellStyle.oneDecimal,
                )
              : const XlsxCell.text('No configurado'),
          d.estado == EstadoMantenimiento.noConfigurado
              ? const XlsxCell.text('No aplica')
              : XlsxCell.number(d.restante, style: XlsxCellStyle.oneDecimal),
          d.fechaProyectada == null
              ? const XlsxCell.text('')
              : XlsxCell.dateTime(d.fechaProyectada!),
          XlsxCell.text(_etiquetaEstado(d.estado)),
        ],
    ],
  );
}

String _etiquetaEstado(EstadoMantenimiento estado) {
  switch (estado) {
    case EstadoMantenimiento.noConfigurado:
      return 'No configurado';
    case EstadoMantenimiento.alDia:
      return 'Al día';
    case EstadoMantenimiento.proximo:
      return 'Próximo';
    case EstadoMantenimiento.vencido:
      return 'Vencido';
    case EstadoMantenimiento.sinDatos:
      return 'Sin datos suficientes';
  }
}

String _dosDigitos(int numero) => numero.toString().padLeft(2, '0');

/// Ej. "mantenimiento_20260715_143205.xlsx".
String nombreArchivoMantenimiento(DateTime momento) {
  final fecha =
      '${momento.year}${_dosDigitos(momento.month)}${_dosDigitos(momento.day)}';
  final hora =
      '${_dosDigitos(momento.hour)}${_dosDigitos(momento.minute)}${_dosDigitos(momento.second)}';
  return 'mantenimiento_${fecha}_$hora.xlsx';
}
