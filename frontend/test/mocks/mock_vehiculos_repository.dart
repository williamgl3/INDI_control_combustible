import 'package:indi_combustible/core/catalogos_vehiculo.dart';
import 'package:indi_combustible/data/vehiculos_repository.dart';
import 'package:indi_combustible/models/vehiculo.dart';

/// Catálogo compartido de vehículos/maquinaria de la obra, en memoria.
///
/// El vehículo ya NO es un dato fijo del chofer — se elige en cada
/// solicitud/comprobación de carga, porque varios choferes pueden usar
/// distintas unidades en días distintos.
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
        placas: 'ABC-123-A',
        numeroEconomico: null,
        tipoCombustible: 'Diésel',
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
    String? placas,
    String? numeroEconomico,
    String? tipoCombustible,
    String? modelo,
    double? intervaloServicio,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final vehiculo = Vehiculo(
      id: 'veh-${_idSeq++}',
      tipoUnidad: tipoUnidad,
      placas: (placas == null || placas.isEmpty) ? null : placas,
      numeroEconomico: (numeroEconomico == null || numeroEconomico.isEmpty)
          ? null
          : numeroEconomico,
      tipoCombustible: tipoCombustible,
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
    String? placas,
    String? numeroEconomico,
    required String tipoCombustible,
    required String modelo,
  }) async {
    return crear(
      tipoUnidad: tipoUnidad,
      placas: placas,
      numeroEconomico: numeroEconomico,
      tipoCombustible: tipoCombustible,
      modelo: modelo,
    );
  }

  @override
  Future<Vehiculo> actualizar({
    required String id,
    String? tipoUnidad,
    String? placas,
    String? numeroEconomico,
    String? tipoCombustible,
    String? modelo,
    double? intervaloServicio,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _vehiculos.indexWhere((v) => v.id == id);
    final actual = _vehiculos[indice];
    final actualizado = actual.copyWith(
      tipoUnidad: tipoUnidad,
      placas: placas == null
          ? actual.placas
          : (placas.isEmpty ? null : placas),
      numeroEconomico: numeroEconomico == null
          ? actual.numeroEconomico
          : (numeroEconomico.isEmpty ? null : numeroEconomico),
      tipoCombustible: tipoCombustible,
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

  @override
  Future<void> cambiarEstado({
    required String id,
    required bool activo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _vehiculos.indexWhere((v) => v.id == id);
    _vehiculos[indice] = _vehiculos[indice].copyWith(activo: activo);
  }
}
