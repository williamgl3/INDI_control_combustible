import '../models/despacho_marimba.dart';
import '../models/recorrido_marimba.dart';
import '../models/panel_marimba.dart';

/// Interfaz del flujo de recorridos (jornadas) de despacho de la marimba
/// — implementada por [ApiRecorridosMarimbaRepository] (real) y por un
/// fake en tests. Es la única fuente de datos del recorrido completo:
/// apertura, inventario, despachos y conciliación.
abstract class RecorridosMarimbaRepository {
  Future<RecorridoMarimba> abrirRecorrido({
    required String marimbaId,
    required String tipoCombustible,
    required String frente,
    double? kmInicio,
    double? horasEquipoMenorInicio,
  });

  Future<double> saldoDeMarimba(String marimbaId, String tipoCombustible);

  Future<RecorridoMarimba?> buscarRecorrido(String id);

  Future<List<DespachoMarimba>> listarDespachosDeRecorrido(String recorridoId);

  Future<DespachoMarimba> agregarDespacho({
    required String recorridoId,
    required String tipoCombustible,
    required String vehiculoDestinoId,
    required String operadorTexto,
    required double horometro,
    required String fotoHorometroPath,
    double? litrosDeclarados,
    double? medidorInicial,
    double? medidorFinal,
    String? fotoMedidorPath,
    String? fotoEvidenciaPath,
    String? ubicacion,
    String? observaciones,
  });

  Future<RecorridoMarimba> cerrarRecorrido({
    required String recorridoId,
    double? kmCierre,
    double? horasEquipoMenorCierre,
    required String fotoCierrePath,
    required double existenciaFisica,
    required String fotoNivelPath,
    String? observaciones,
  });

  /// Panel admin — recorridos filtrados (ver PASO 4c del diseño).
  Future<List<RecorridoMarimba>> listarRecorridos({
    String? marimbaId,
    bool? requiereRevision,
  });

  Future<List<ResumenUnidadMarimba>> listarResumenUnidades();

  Future<PaginaRecorridosMarimba> listarRecorridosAdministrativos(
    FiltrosRecorridosMarimba filtros,
  );
}
