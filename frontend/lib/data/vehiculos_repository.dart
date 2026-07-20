import '../models/vehiculo.dart';

/// Interfaz común del catálogo de vehículos — implementada por
/// [MockVehiculosRepository] (datos en memoria) y por la implementación
/// real que habla con el backend.
abstract class VehiculosRepository {
  /// Catálogo ya cargado en memoria — ver [cargarVehiculos].
  List<Vehiculo> get todos;

  Vehiculo? porId(String id);

  /// Trae/actualiza el catálogo completo desde el backend. Se llama tras
  /// iniciar sesión (ver `AuthController._cargarDatosIniciales`).
  Future<void> cargarVehiculos();

  Future<Vehiculo> crear({
    required String tipoUnidad,
    required String identificador,
    required String tipoCombustible,
    required double topeSemanal,
    String? modelo,
    double? intervaloServicio,
  });

  Future<Vehiculo> reportarNuevo({
    required String tipoUnidad,
    required String identificador,
    required String tipoCombustible,
  });

  Future<Vehiculo> actualizar({
    required String id,
    String? tipoUnidad,
    String? identificador,
    String? tipoCombustible,
    double? topeSemanal,
    String? modelo,
    double? intervaloServicio,
  });

  Future<Vehiculo> registrarServicio({
    required String id,
    required double lectura,
    required DateTime fecha,
  });
}
