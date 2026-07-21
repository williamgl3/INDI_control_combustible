import '../models/incidencia_vehiculo.dart';
import 'api_client.dart';
import 'incidencias_repository.dart';

/// Implementación real de [IncidenciasRepository]: habla por HTTP con el
/// backend (ver `backend/src/routes/incidencias.routes.ts`).
class ApiIncidenciasRepository implements IncidenciasRepository {
  ApiIncidenciasRepository(this._client);

  final ApiClient _client;

  List<IncidenciaVehiculo> _mias = [];
  List<IncidenciaVehiculo> _todas = [];

  @override
  List<IncidenciaVehiculo> get misIncidencias => List.unmodifiable(_mias);

  @override
  Future<void> cargarMisIncidencias() async {
    final data = await _client.get('/incidencias/mias');
    _mias = (data as List)
        .map((j) => IncidenciaVehiculo.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  List<IncidenciaVehiculo> get todasLasIncidencias => List.unmodifiable(_todas);

  @override
  Future<void> cargarTodasLasIncidencias() async {
    final data = await _client.get('/incidencias');
    _todas = (data as List)
        .map((j) => IncidenciaVehiculo.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<IncidenciaVehiculo> reportar({
    required String vehiculoId,
    required String descripcion,
  }) async {
    final data = await _client.post(
      '/incidencias',
      body: {'vehiculoId': vehiculoId, 'descripcion': descripcion},
    );
    final incidencia = IncidenciaVehiculo.fromJson(
      data as Map<String, dynamic>,
    );
    _mias = [incidencia, ..._mias];
    return incidencia;
  }

  @override
  Future<IncidenciaVehiculo> resolver({
    required String id,
    String? comentario,
  }) async {
    final data = await _client.patch(
      '/incidencias/$id/resolver',
      body: {'comentario': comentario},
    );
    final incidencia = IncidenciaVehiculo.fromJson(
      data as Map<String, dynamic>,
    );
    final indice = _todas.indexWhere((i) => i.id == incidencia.id);
    if (indice != -1) {
      _todas = [..._todas]..[indice] = incidencia;
    }
    return incidencia;
  }
}
