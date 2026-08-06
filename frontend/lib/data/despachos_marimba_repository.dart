import '../models/despacho_marimba.dart';

/// Interfaz del ciclo de despacho de la marimba — implementada por
/// [ApiDespachosMarimbaRepository] (real) y por un fake en tests.
abstract class DespachosMarimbaRepository {
  /// Saldo actual del libro mayor de la marimba (litros cargados − litros
  /// despachados, acumulado sin reiniciarse por carga ni por día).
  Future<double> saldoDeMarimba(String marimbaId);

  Future<List<DespachoMarimba>> listarDespachosDeMarimba(String marimbaId);

  Future<DespachoMarimba> registrarDespacho({
    required String marimbaId,
    String? vehiculoDestinoId,
    String? destinoTexto,
    required String operadorTexto,
    String? residenteTexto,
    required String sitio,
    double? litrosSolicitados,
    required double litrosSuministrados,
    double? lecturaMedidor,
    EstadoDespacho estado = EstadoDespacho.activo,
    String? fotoEvidenciaPath,
  });
}
