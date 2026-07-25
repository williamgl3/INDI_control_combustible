import 'package:indi_combustible/core/catalogos_vehiculo.dart';
import 'package:indi_combustible/data/vehiculos_repository.dart';
import 'package:indi_combustible/models/vehiculo.dart';

/// Catálogo compartido de vehículos/maquinaria de la obra, en memoria.
///
/// El vehículo ya NO es un dato fijo del chofer — se elige en cada
/// solicitud/comprobación de carga, porque varios choferes pueden usar
/// distintas unidades en días distintos. El tope semanal vive aquí, en
/// el vehículo, no en el chofer.
///
/// Útil para tests de widgets y como referencia de la interfaz que
/// implementa `ApiVehiculosRepository`.
class MockVehiculosRepository implements VehiculosRepository {
  MockVehiculosRepository() {
    _vehiculos.add(
      Vehiculo(
        id: 'veh-1',
        tipoUnidad: 'Vehículo',
        modelo: 'Chevrolet NPR 2020',
        identificador: 'ABC-123',
        tipoCombustible: 'Diésel',
        topeSemanal: 500,
        intervaloServicio: intervaloServicioPorDefecto('Vehículo'),
      ),
    );
  }

  final List<Vehiculo> _vehiculos = [];
  int _idSeq = 2;

  @override
  List<Vehiculo> get todos => List.unmodifiable(_vehiculos);

  @override
  Future<void> cargarVehiculos() async {}

  @override
  Vehiculo? porId(String id) {
    try {
      return _vehiculos.firstWhere((v) => v.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Vehiculo> crear({
    required String tipoUnidad,
    required String identificador,
    required String tipoCombustible,
    required double topeSemanal,
    String? modelo,
    double? intervaloServicio,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final vehiculo = Vehiculo(
      id: 'veh-${_idSeq++}',
      tipoUnidad: tipoUnidad,
      identificador: identificador,
      tipoCombustible: tipoCombustible,
      topeSemanal: topeSemanal,
      modelo: modelo,
      intervaloServicio:
          intervaloServicio ?? intervaloServicioPorDefecto(tipoUnidad),
    );
    _vehiculos.add(vehiculo);
    return vehiculo;
  }

  @override
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

  @override
  Future<Vehiculo> actualizar({
    required String id,
    String? tipoUnidad,
    String? identificador,
    String? tipoCombustible,
    double? topeSemanal,
    String? modelo,
    double? intervaloServicio,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _vehiculos.indexWhere((v) => v.id == id);
    final actualizado = _vehiculos[indice].copyWith(
      tipoUnidad: tipoUnidad,
      identificador: identificador,
      tipoCombustible: tipoCombustible,
      topeSemanal: topeSemanal,
      modelo: modelo,
      intervaloServicio: intervaloServicio,
    );
    _vehiculos[indice] = actualizado;
    return actualizado;
  }

  @override
  Future<Vehiculo> registrarServicio({
    required String id,
    required double lectura,
    required DateTime fecha,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _vehiculos.indexWhere((v) => v.id == id);
    final actualizado = _vehiculos[indice].copyWith(
      lecturaUltimoServicio: lectura,
      fechaUltimoServicio: fecha,
    );
    _vehiculos[indice] = actualizado;
    return actualizado;
  }
}
