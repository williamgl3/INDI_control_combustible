/// Formateo de fechas sin depender del paquete `intl`.
const _meses = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

/// Ej. "15 jul, 14:05".
String formatearFechaCorta(DateTime fecha) {
  final dia = fecha.day;
  final mes = _meses[fecha.month - 1];
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '$dia $mes, $hora:$minuto';
}

/// Ej. "15 jul" (sin hora) — para mostrar rangos de fecha.
String formatearDiaMes(DateTime fecha) {
  return '${fecha.day} ${_meses[fecha.month - 1]}';
}
