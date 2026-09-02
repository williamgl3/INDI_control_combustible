import 'dart:async';

/// Mutex ligero basado en [Completer] para serializar operaciones de
/// lectura-modificación-escritura sobre SharedPreferences (u otro recurso
/// compartido).
///
/// No requiere dependencias externas. Replica el patrón ya existente en
/// `ColaSolicitudesOffline.agregar` pero extiétndolo a todas las
/// operaciones de cola.
///
/// Diferencia con el mutex de sincronización: este protege la integridad
/// del store local (SharedPreferences), no la ejecución de llamadas HTTP
/// de sincronización.
class MutexPersistencia {
  Future<void> _operacion = Future.value();

  /// Ejecuta [fn] de forma serializada — no puede correr simultáneamente
  /// con otra llamada a [run] en la misma instancia.
  Future<T> run<T>(Future<T> Function() fn) async {
    final previa = _operacion;
    final completa = Completer<void>();
    _operacion = completa.future;
    await previa;
    try {
      return await fn();
    } finally {
      completa.complete();
    }
  }
}
