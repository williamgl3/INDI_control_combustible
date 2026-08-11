import '../models/vehiculo.dart';
import 'api_client.dart';
import 'vehiculos_repository.dart';

/// Implementación real de [VehiculosRepository]: habla por HTTP con el
/// backend (ver `backend/src/routes/vehiculos.routes.ts`). Mantiene un
/// caché en memoria idéntico al de [MockVehiculosRepository] para que
/// las pantallas (que leen `todos`/`porId` de forma síncrona) no
/// necesiten cambios — el caché se llena con [cargarVehiculos] y se
/// actualiza localmente tras cada mutación.
class ApiVehiculosRepository implements VehiculosRepository {
  ApiVehiculosRepository(this._client);

  final ApiClient _client;
  List<Vehiculo> _vehiculos = [];

  @override
  List<Vehiculo> get todos => List.unmodifiable(_vehiculos);

  @override
  Vehiculo? porId(String id) {
    try {
      return _vehiculos.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> cargarVehiculos() async {
    final data = await _client.get('/vehiculos');
    _vehiculos = (data as List)
        .map((j) => Vehiculo.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  void _upsert(Vehiculo vehiculo) {
    final indice = _vehiculos.indexWhere((v) => v.id == vehiculo.id);
    if (indice == -1) {
      _vehiculos = [..._vehiculos, vehiculo];
    } else {
      _vehiculos = [..._vehiculos]..[indice] = vehiculo;
    }
  }

  @override
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
  }) async {
    final data = await _client.post(
      '/vehiculos',
      body: {
        'tipoUnidad': tipoUnidad,
        'placas': placas,
        'numeroEconomico': numeroEconomico,
        'tipoCombustible': tipoCombustible,
        'modelo': modelo,
        'intervaloServicio': intervaloServicio,
        'ubicacion': ubicacion,
        'unidadPadreId': unidadPadreId,
        'activo': activo,
      },
    );
    final vehiculo = Vehiculo.fromJson(data as Map<String, dynamic>);
    _upsert(vehiculo);
    return vehiculo;
  }

  @override
  Future<Vehiculo> reportarNuevo({
    required String tipoUnidad,
    String? placas,
    String? numeroEconomico,
    required String tipoCombustible,
    required String modelo,
  }) async {
    final data = await _client.post(
      '/vehiculos/reportar-nuevo',
      body: {
        'tipoUnidad': tipoUnidad,
        'placas': placas,
        'numeroEconomico': numeroEconomico,
        'tipoCombustible': tipoCombustible,
        'modelo': modelo,
      },
    );
    final vehiculo = Vehiculo.fromJson(data as Map<String, dynamic>);
    _upsert(vehiculo);
    return vehiculo;
  }

  @override
  Future<Vehiculo> actualizar({
    required String id,
    required ActualizacionVehiculo cambios,
  }) async {
    final body = <String, dynamic>{};
    void incluir<T>(String nombre, CampoActualizacion<T> campo) {
      if (campo.incluir) body[nombre] = campo.valor;
    }

    incluir('tipoUnidad', cambios.tipoUnidad);
    incluir('placas', cambios.placas);
    incluir('numeroEconomico', cambios.numeroEconomico);
    incluir('tipoCombustible', cambios.tipoCombustible);
    incluir('modelo', cambios.modelo);
    incluir('intervaloServicio', cambios.intervaloServicio);
    incluir('ubicacion', cambios.ubicacion);
    incluir('unidadPadreId', cambios.unidadPadreId);
    incluir('activo', cambios.activo);
    final data = await _client.patch('/vehiculos/$id', body: body);
    final vehiculo = Vehiculo.fromJson(data as Map<String, dynamic>);
    _upsert(vehiculo);
    return vehiculo;
  }

  @override
  Future<Vehiculo> registrarServicio({
    required String id,
    required double lectura,
    required DateTime fecha,
  }) async {
    final data = await _client.post(
      '/vehiculos/$id/registrar-servicio',
      body: {'lectura': lectura},
    );
    final vehiculo = Vehiculo.fromJson(data as Map<String, dynamic>);
    _upsert(vehiculo);
    return vehiculo;
  }

  @override
  Future<void> cambiarEstado({required String id, required bool activo}) async {
    final data = await _client.patch(
      '/vehiculos/$id/estado',
      body: {'activo': activo},
    );
    _upsert(Vehiculo.fromJson(data as Map<String, dynamic>));
  }
}
