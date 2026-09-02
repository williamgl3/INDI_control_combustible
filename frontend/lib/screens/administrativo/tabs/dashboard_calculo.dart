import '../../../core/semana_util.dart';
import '../../../models/carga.dart';

/// Periodo de agregación del dashboard de estadísticas.
enum PeriodoDashboard { dia, semana, mes, anio }

/// Un punto de la serie de litros a lo largo del sub-periodo (ej. un día
/// de la semana, una semana del mes, un mes del año).
class SegmentoLitros {
  const SegmentoLitros({required this.etiqueta, required this.litros});

  final String etiqueta;
  final double litros;
}

/// Participación de un tipo de combustible dentro del total del periodo.
class DesgloseCombustible {
  const DesgloseCombustible({
    required this.tipo,
    required this.litros,
    required this.porcentaje,
  });

  final String tipo;
  final double litros;

  /// 0-100.
  final double porcentaje;
}

const _diasSemana = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
const _meses = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

/// `true` si [fecha] cae dentro de [periodo], tomando [ahora] como
/// referencia de "hoy".
bool cargaDentroDePeriodo(
  DateTime fecha,
  PeriodoDashboard periodo,
  DateTime ahora,
) {
  switch (periodo) {
    case PeriodoDashboard.dia:
      return fecha.year == ahora.year &&
          fecha.month == ahora.month &&
          fecha.day == ahora.day;
    case PeriodoDashboard.semana:
      return estaEnSemanaDe(fecha, ahora);
    case PeriodoDashboard.mes:
      return fecha.year == ahora.year && fecha.month == ahora.month;
    case PeriodoDashboard.anio:
      return fecha.year == ahora.year;
  }
}

/// Ej. "Hoy · 17 jul", "Semana del 13 al 19 jul", "Julio 2026", "2026".
String etiquetaPeriodoDashboard(PeriodoDashboard periodo, DateTime ahora) {
  switch (periodo) {
    case PeriodoDashboard.dia:
      return 'Hoy · ${ahora.day} ${_meses[ahora.month - 1]}';
    case PeriodoDashboard.semana:
      return 'Semana del ${etiquetaRangoSemana(ahora)}';
    case PeriodoDashboard.mes:
      return '${_nombreMesCompleto(ahora.month)} ${ahora.year}';
    case PeriodoDashboard.anio:
      return '${ahora.year}';
  }
}

const _mesesCompletos = [
  'Enero',
  'Febrero',
  'Marzo',
  'Abril',
  'Mayo',
  'Junio',
  'Julio',
  'Agosto',
  'Septiembre',
  'Octubre',
  'Noviembre',
  'Diciembre',
];

String _nombreMesCompleto(int mes) => _mesesCompletos[mes - 1];

/// Agrupa los litros cargados en sub-periodos para la gráfica de barras:
/// por día de la semana (semana), por semana del mes (mes), o por mes del
/// año (año). Para [PeriodoDashboard.dia] no hay sub-agrupación posible
/// (devuelve una lista vacía — el dashboard omite la barra en ese caso).
List<SegmentoLitros> agruparLitrosPorSubperiodo(
  List<Carga> cargasDelPeriodo,
  PeriodoDashboard periodo,
  DateTime ahora,
) {
  switch (periodo) {
    case PeriodoDashboard.dia:
      return const [];

    case PeriodoDashboard.semana:
      final acumulado = List<double>.filled(7, 0);
      for (final carga in cargasDelPeriodo) {
        acumulado[carga.creadaEn.weekday - 1] += carga.litrosCargados;
      }
      return [
        for (var i = 0; i < 7; i++)
          SegmentoLitros(etiqueta: _diasSemana[i], litros: acumulado[i]),
      ];

    case PeriodoDashboard.mes:
      final semanasEnMes =
          ((DateTime(ahora.year, ahora.month + 1, 0).day - 1) ~/ 7) + 1;
      final acumulado = List<double>.filled(semanasEnMes, 0);
      for (final carga in cargasDelPeriodo) {
        final indice = ((carga.creadaEn.day - 1) ~/ 7).clamp(
          0,
          semanasEnMes - 1,
        );
        acumulado[indice] += carga.litrosCargados;
      }
      return [
        for (var i = 0; i < semanasEnMes; i++)
          SegmentoLitros(etiqueta: 'Sem. ${i + 1}', litros: acumulado[i]),
      ];

    case PeriodoDashboard.anio:
      final acumulado = List<double>.filled(12, 0);
      for (final carga in cargasDelPeriodo) {
        acumulado[carga.creadaEn.month - 1] += carga.litrosCargados;
      }
      return [
        for (var i = 0; i < 12; i++)
          SegmentoLitros(etiqueta: _meses[i], litros: acumulado[i]),
      ];
  }
}

/// Participación porcentual de cada tipo de combustible sobre el total de
/// litros cargados en el periodo. [tipoCombustiblePorVehiculo] resuelve el
/// tipo de combustible de cada carga por su `vehiculoId`.
List<DesgloseCombustible> desglosarPorCombustible(
  List<Carga> cargasDelPeriodo,
  Map<String, String?> tipoCombustiblePorVehiculo,
) {
  final litrosPorTipo = <String, double>{};
  for (final carga in cargasDelPeriodo) {
    final tipo =
        tipoCombustiblePorVehiculo[carga.vehiculoId] ?? 'Sin especificar';
    litrosPorTipo[tipo] = (litrosPorTipo[tipo] ?? 0) + carga.litrosCargados;
  }
  final total = litrosPorTipo.values.fold(0.0, (s, v) => s + v);
  if (total <= 0) return const [];

  final entradas = litrosPorTipo.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in entradas)
      DesgloseCombustible(
        tipo: e.key,
        litros: e.value,
        porcentaje: (e.value / total) * 100,
      ),
  ];
}
