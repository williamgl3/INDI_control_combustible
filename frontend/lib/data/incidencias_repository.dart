import '../models/incidencia_vehiculo.dart';

/// Interfaz de incidencias/fallas de vehículo — implementada por
/// [ApiIncidenciasRepository] (real) y un mock en memoria para tests.
abstract class IncidenciasRepository {
  /// Incidencias reportadas por el chofer actual — se llenan con
  /// [cargarMisIncidencias].
  List<IncidenciaVehiculo> get misIncidencias;

  Future<void> cargarMisIncidencias();

  /// Todas las incidencias de todos los choferes — solo administrativo.
  List<IncidenciaVehiculo> get todasLasIncidencias;

  Future<void> cargarTodasLasIncidencias();

  Future<IncidenciaVehiculo> reportar({
    required String vehiculoId,
    required String descripcion,
  });

  Future<IncidenciaVehiculo> resolver({
    required String id,
    String? comentario,
  });
}
