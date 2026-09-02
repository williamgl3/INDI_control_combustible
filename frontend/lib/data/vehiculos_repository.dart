import '../models/vehiculo.dart';

/// Distingue en un PATCH entre campo ausente y valor explícito (incluido
/// `null`). Evita usar el mismo `null` para "no tocar" y "eliminar".
class CampoActualizacion<T> {
  const CampoActualizacion.omitido() : incluir = false, valor = null;
  const CampoActualizacion.valor(this.valor) : incluir = true;

  final bool incluir;
  final T? valor;
}

class ActualizacionVehiculo {
  const ActualizacionVehiculo({
    this.tipoUnidad = const CampoActualizacion.omitido(),
    this.placas = const CampoActualizacion.omitido(),
    this.numeroEconomico = const CampoActualizacion.omitido(),
    this.tipoCombustible = const CampoActualizacion.omitido(),
    this.modelo = const CampoActualizacion.omitido(),
    this.intervaloServicio = const CampoActualizacion.omitido(),
    this.ubicacion = const CampoActualizacion.omitido(),
    this.unidadPadreId = const CampoActualizacion.omitido(),
    this.activo = const CampoActualizacion.omitido(),
  });

  final CampoActualizacion<String> tipoUnidad;
  final CampoActualizacion<String> placas;
  final CampoActualizacion<String> numeroEconomico;
  final CampoActualizacion<String> tipoCombustible;
  final CampoActualizacion<String> modelo;
  final CampoActualizacion<double> intervaloServicio;
  final CampoActualizacion<String> ubicacion;
  final CampoActualizacion<String> unidadPadreId;
  final CampoActualizacion<bool> activo;
}

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
    String? placas,
    String? numeroEconomico,
    String? tipoCombustible,
    String? modelo,
    double? intervaloServicio,
    String? ubicacion,
    String? unidadPadreId,
    bool activo = true,
  });

  Future<Vehiculo> reportarNuevo({
    required String tipoUnidad,
    String? placas,
    String? numeroEconomico,
    required String tipoCombustible,
    required String modelo,
  });

  Future<Vehiculo> actualizar({
    required String id,
    required ActualizacionVehiculo cambios,
  });

  Future<Vehiculo> registrarServicio({
    required String id,
    required double lectura,
    required DateTime fecha,
  });

  /// Activa/desactiva un vehículo del catálogo (soft-delete) — ver
  /// [Vehiculo.activo].
  Future<void> cambiarEstado({required String id, required bool activo});
}
