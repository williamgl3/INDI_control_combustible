import '../models/registro_auditoria.dart';

/// Interfaz de auditoría (bitácora de actividad administrativa) —
/// implementada por [ApiAuditoriaRepository] (real) y un mock en memoria
/// para tests.
abstract class AuditoriaRepository {
  /// Registros ya cargados en memoria, más reciente primero — ver
  /// [cargarRegistros].
  List<RegistroAuditoria> get registros;

  /// `true` si la última página cargada trajo menos de `limit` registros
  /// (o vino vacía) — no hay más para paginar hacia atrás.
  bool get sinMasRegistros;

  /// Trae la primera página de registros (más recientes primero),
  /// reemplazando lo que hubiera cargado antes.
  Future<void> cargarRegistros({int limit = 30});

  /// Trae la siguiente página (anterior en el tiempo) usando el cursor
  /// `before` del registro más antiguo ya cargado, y la agrega al final
  /// de [registros].
  Future<void> cargarMasRegistros({int limit = 30});
}
