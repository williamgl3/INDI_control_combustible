import '../models/vehiculo.dart';

/// Catálogo compartido de vehículos/maquinaria de la obra, en memoria.
///
/// El vehículo ya NO es un dato fijo del chofer — se elige en cada
/// solicitud/comprobación de carga, porque varios choferes pueden usar
/// distintas unidades en días distintos. El tope semanal vive aquí, en
/// el vehículo, no en el chofer.
///
/// TODO-BACKEND: reemplazar por un repositorio real con la misma
/// interfaz cuando el backend esté listo.
class MockVehiculosRepository {
  MockVehiculosRepository() {
    // Semilla de demo — antes vivía embebida en el chofer1 del mock de auth.
    _vehiculos.add(
      const Vehiculo(
        id: 'veh-1',
        tipoUnidad: 'Vehículo',
        modelo: 'Chevrolet NPR 2020',
        identificador: 'ABC-123',
        tipoCombustible: 'Diésel',
        topeSemanal: 500,
      ),
    );
  }

  final List<Vehiculo> _vehiculos = [];
  int _idSeq = 2;

  List<Vehiculo> get todos => List.unmodifiable(_vehiculos);

  Vehiculo? porId(String id) {
    try {
      return _vehiculos.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Alta de un vehículo ya formalizada por un administrativo, con su
  /// tope semanal definido desde el inicio.
  Future<Vehiculo> crear({
    required String tipoUnidad,
    required String identificador,
    required String tipoCombustible,
    required double topeSemanal,
    String? modelo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final vehiculo = Vehiculo(
      id: 'veh-${_idSeq++}',
      tipoUnidad: tipoUnidad,
      identificador: identificador,
      tipoCombustible: tipoCombustible,
      topeSemanal: topeSemanal,
      modelo: modelo,
    );
    _vehiculos.add(vehiculo);
    return vehiculo;
  }

  /// Un chofer reporta sobre la marcha una unidad que no está en el
  /// catálogo (ej. una unidad recién llegada a la obra). Queda con tope
  /// `0` — sin tope asignado — hasta que un administrativo la formalice
  /// en la pestaña Vehículos; mientras tanto, cualquier solicitud que la
  /// use cae a revisión manual (mismo comportamiento que "sin tope").
  Future<Vehiculo> reportarNuevo({
    required String tipoUnidad,
    required String identificador,
    required String tipoCombustible,
  }) async {
    return crear(
      tipoUnidad: tipoUnidad,
      identificador: identificador,
      tipoCombustible: tipoCombustible,
      topeSemanal: 0,
    );
  }

  /// Edita los datos de un vehículo ya existente (formalizar tope,
  /// corregir identificador/tipo, etc.).
  Future<Vehiculo> actualizar({
    required String id,
    String? tipoUnidad,
    String? identificador,
    String? tipoCombustible,
    double? topeSemanal,
    String? modelo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _vehiculos.indexWhere((v) => v.id == id);
    final actualizado = _vehiculos[indice].copyWith(
      tipoUnidad: tipoUnidad,
      identificador: identificador,
      tipoCombustible: tipoCombustible,
      topeSemanal: topeSemanal,
      modelo: modelo,
    );
    _vehiculos[indice] = actualizado;
    return actualizado;
  }
}
