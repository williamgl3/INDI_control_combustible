import '../models/incidencia_vehiculo.dart';
import 'incidencias_repository.dart';

/// Repositorio de incidencias MOCK — datos en memoria, para widget tests.
class MockIncidenciasRepository implements IncidenciasRepository {
  final List<IncidenciaVehiculo> _todas = [];
  int _idSeq = 1;

  @override
  List<IncidenciaVehiculo> get misIncidencias => List.unmodifiable(_todas);

  @override
  Future<void> cargarMisIncidencias() async {}

  @override
  List<IncidenciaVehiculo> get todasLasIncidencias => List.unmodifiable(_todas);

  @override
  Future<void> cargarTodasLasIncidencias() async {}

  @override
  Future<IncidenciaVehiculo> reportar({
    required String vehiculoId,
    required String descripcion,
  }) async {
    final incidencia = IncidenciaVehiculo(
      id: 'inc-${_idSeq++}',
      vehiculoId: vehiculoId,
      choferId: 'mock-chofer-1',
      descripcion: descripcion,
      estado: EstadoIncidencia.abierta,
      creadaEn: DateTime.now(),
    );
    _todas.insert(0, incidencia);
    return incidencia;
  }

  @override
  Future<IncidenciaVehiculo> resolver({
    required String id,
    String? comentario,
  }) async {
    final indice = _todas.indexWhere((i) => i.id == id);
    final actualizada = IncidenciaVehiculo(
      id: _todas[indice].id,
      vehiculoId: _todas[indice].vehiculoId,
      choferId: _todas[indice].choferId,
      descripcion: _todas[indice].descripcion,
      estado: EstadoIncidencia.resuelta,
      creadaEn: _todas[indice].creadaEn,
      resueltaPor: 'Admin de prueba',
      comentarioResolucion: comentario,
      resueltaEn: DateTime.now(),
    );
    _todas[indice] = actualizada;
    return actualizada;
  }
}
