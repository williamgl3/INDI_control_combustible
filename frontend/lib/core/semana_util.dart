import '../widgets/fecha_formato.dart';

/// Corte de semana usado en todo el mock (presupuesto semanal, litros
/// acumulados, filtro "Semana" del Concentrado): lunes 00:00 a domingo
/// 23:59:59, en la fecha/hora local del dispositivo.
///
/// Se usa lunes-domingo por ser el estándar ISO más común en México.
DateTime inicioDeSemana(DateTime fecha) {
  final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
  return soloFecha.subtract(Duration(days: soloFecha.weekday - 1));
}

/// Primer instante de la semana SIGUIENTE — límite superior exclusivo.
DateTime finDeSemana(DateTime fecha) =>
    inicioDeSemana(fecha).add(const Duration(days: 7));

/// `true` si [fecha] cae en la misma semana (lunes-domingo) que
/// [semanaDeReferencia].
bool estaEnSemanaDe(DateTime fecha, DateTime semanaDeReferencia) {
  final inicio = inicioDeSemana(semanaDeReferencia);
  final fin = finDeSemana(semanaDeReferencia);
  return !fecha.isBefore(inicio) && fecha.isBefore(fin);
}

/// Ej. "15 al 21 jul" — para mostrar en la UI a qué semana corresponde
/// el presupuesto/acumulado mostrado.
String etiquetaRangoSemana(DateTime fecha) {
  final inicio = inicioDeSemana(fecha);
  final fin = inicio.add(const Duration(days: 6));
  return '${inicio.day} al ${formatearDiaMes(fin)}';
}
