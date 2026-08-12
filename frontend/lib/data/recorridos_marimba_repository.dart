import '../models/despacho_marimba.dart';
import '../models/recorrido_marimba.dart';

/// Interfaz del flujo de recorridos (jornadas) de despacho de la marimba
/// — implementada por [ApiRecorridosMarimbaRepository] (real) y por un
/// fake en tests. Complementa a [DespachosMarimbaRepository]: aquí vive
/// el encabezado de la jornada y su conciliación; los despachos
/// individuales que agrega siguen siendo [DespachoMarimba].
abstract class RecorridosMarimbaRepository {
  Future<RecorridoMarimba> abrirRecorrido({
    required String marimbaId,
    required String tipoCombustible,
    required String frente,
    String? cargaId,
    required double litrosIniciales,
    double? kmInicio,
    double? horasEquipoMenorInicio,
  });

  Future<RecorridoMarimba?> buscarRecorrido(String id);

  Future<List<DespachoMarimba>> listarDespachosDeRecorrido(String recorridoId);

  Future<DespachoMarimba> agregarDespacho({
    required String recorridoId,
    required String tipoCombustible,
    String? vehiculoDestinoId,
    String? destinoTexto,
    required String operadorTexto,
    String? residenteTexto,
    double? litrosSolicitados,
    required double litrosSuministrados,
    double? lecturaMedidor,
    String? fotoEvidenciaPath,
  });

  Future<RecorridoMarimba> cerrarRecorrido({
    required String recorridoId,
    double? kmCierre,
    double? horasEquipoMenorCierre,
    required String fotoCierrePath,
    double? existenciaFisica,
    String? fotoNivelPath,
    String? observaciones,
  });

  /// Panel admin — recorridos filtrados (ver PASO 4c del diseño).
  Future<List<RecorridoMarimba>> listarRecorridos({
    String? marimbaId,
    bool? requiereRevision,
  });
}
