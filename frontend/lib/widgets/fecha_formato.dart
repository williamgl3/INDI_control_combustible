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

/// Ej. "15/07/2026" — fecha completa en formato numérico, para una fecha
/// "aislada" que no está en lista (respuesta de solicitud, fecha de
/// nacimiento en el perfil, fecha programada) — antes cada pantalla la
/// armaba a mano con el mismo `padLeft(2, '0')` repetido.
String formatearFecha(DateTime fecha) {
  final dia = fecha.day.toString().padLeft(2, '0');
  final mes = fecha.month.toString().padLeft(2, '0');
  return '$dia/$mes/${fecha.year}';
}

/// Ej. "14:05" — solo la hora, para filas ya agrupadas bajo un encabezado
/// de fecha (ver [etiquetaGrupoFecha]), donde repetir la fecha completa en
/// cada renglón sería redundante.
String formatearHora(DateTime fecha) {
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '$hora:$minuto';
}

/// Encabezado de grupo para listas ordenadas por fecha — "HOY", "AYER", o
/// "15 JUL" para cualquier otro día (el `GroupedSection.header` de cada
/// grupo ya pone el texto en mayúsculas).
String etiquetaGrupoFecha(DateTime fecha) {
  final hoy = DateTime.now();
  final soloFecha = DateTime(fecha.year, fecha.month, fecha.day);
  final soloHoy = DateTime(hoy.year, hoy.month, hoy.day);
  final diferenciaDias = soloHoy.difference(soloFecha).inDays;
  if (diferenciaDias == 0) return 'Hoy';
  if (diferenciaDias == 1) return 'Ayer';
  return formatearDiaMes(fecha);
}

/// Agrupa una lista ya ordenada de más a menos reciente por día calendario,
/// sin reordenarla — cada grupo conserva el orden original y arma su
/// encabezado ("Hoy", "Ayer", "15 jul") con [etiquetaGrupoFecha]. Genérico
/// para poder reusarse en cualquier lista con fecha (solicitudes, cargas,
/// etc.) — antes vivía duplicado/privado en cada pantalla.
List<({String etiqueta, List<T> items})> agruparPorFecha<T>(
  List<T> items,
  DateTime Function(T) fechaDe,
) {
  final grupos = <({String etiqueta, List<T> items})>[];
  for (final item in items) {
    final etiqueta = etiquetaGrupoFecha(fechaDe(item));
    if (grupos.isNotEmpty && grupos.last.etiqueta == etiqueta) {
      grupos.last.items.add(item);
    } else {
      grupos.add((etiqueta: etiqueta, items: [item]));
    }
  }
  return grupos;
}
