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
  MockVehiculosRepository({
    List<Vehiculo>? vehiculos,
    Future<void> Function()? alCargar,
  }) {
    _alCargar = alCargar;
    _vehiculos.addAll(
      vehiculos ??
          [
            Vehiculo(
              id: 'veh-1',
              tipoUnidad: 'Vehículo',
              modelo: 'Chevrolet NPR 2020',
              placas: 'ABC-123-A',
              numeroEconomico: null,
              tipoCombustible: 'Diésel',
              intervaloServicio: intervaloServicioPorDefecto('Vehículo'),
            ),
          ],
    );
  }

  final List<Vehiculo> _vehiculos = [];
  late final Future<void> Function()? _alCargar;
  int cargasRealizadas = 0;
  int _idSeq = 2;

  @override
  List<Vehiculo> get todos => List.unmodifiable(_vehiculos);

  @override
  Future<void> cargarVehiculos() async {
    cargasRealizadas++;
    await _alCargar?.call();
  }

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
    String? ubicacion,
    String? unidadPadreId,
    bool activo = true,
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
      intervaloServicio: intervaloServicio,
      ubicacion: ubicacion,
      unidadPadreId: unidadPadreId,
      activo: activo,
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
    required ActualizacionVehiculo cambios,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _vehiculos.indexWhere((v) => v.id == id);
    final actual = _vehiculos[indice];
    final actualizado = actual.copyWith(
      tipoUnidad: cambios.tipoUnidad.incluir ? cambios.tipoUnidad.valor : null,
      placas: cambios.placas.incluir ? cambios.placas.valor : actual.placas,
      numeroEconomico: cambios.numeroEconomico.incluir
          ? cambios.numeroEconomico.valor
          : actual.numeroEconomico,
      tipoCombustible: cambios.tipoCombustible.incluir
          ? cambios.tipoCombustible.valor
          : actual.tipoCombustible,
      modelo: cambios.modelo.incluir ? cambios.modelo.valor : null,
      intervaloServicio: cambios.intervaloServicio.incluir
          ? cambios.intervaloServicio.valor
          : actual.intervaloServicio,
      ubicacion: cambios.ubicacion.incluir
          ? cambios.ubicacion.valor
          : actual.ubicacion,
      unidadPadreId: cambios.unidadPadreId.incluir
          ? cambios.unidadPadreId.valor
          : actual.unidadPadreId,
      activo: cambios.activo.incluir ? cambios.activo.valor : null,
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
  Future<void> cambiarEstado({required String id, required bool activo}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _vehiculos.indexWhere((v) => v.id == id);
    _vehiculos[indice] = _vehiculos[indice].copyWith(activo: activo);
  }
}
