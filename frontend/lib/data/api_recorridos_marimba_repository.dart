import '../models/despacho_marimba.dart';
import '../models/recorrido_marimba.dart';
import 'api_client.dart';
import 'recorridos_marimba_repository.dart';

class ApiRecorridosMarimbaRepository implements RecorridosMarimbaRepository {
  ApiRecorridosMarimbaRepository(this._client);

  final ApiClient _client;

  @override
  Future<RecorridoMarimba> abrirRecorrido({
    required String marimbaId,
    required String tipoCombustible,
    required String frente,
    String? cargaId,
    required double litrosIniciales,
    double? kmInicio,
    double? horasEquipoMenorInicio,
  }) async {
    final data = await _client.post(
      '/recorridos-marimba',
      body: {
        'marimbaId': marimbaId,
        'tipoCombustible': tipoCombustible,
        'frente': frente,
        'cargaId': ?cargaId,
        'litrosIniciales': litrosIniciales,
        'kmInicio': ?kmInicio,
        'horasEquipoMenorInicio': ?horasEquipoMenorInicio,
      },
    );
    return RecorridoMarimba.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<RecorridoMarimba?> buscarRecorrido(String id) async {
    final data = await _client.get('/recorridos-marimba/$id');
    return data == null
        ? null
        : RecorridoMarimba.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<DespachoMarimba>> listarDespachosDeRecorrido(
    String recorridoId,
  ) async {
    final data = await _client.get(
      '/recorridos-marimba/$recorridoId/despachos',
    );
    return (data as List)
        .map((j) => DespachoMarimba.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
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
  }) async {
    final data = await _client.postMultipart(
      '/recorridos-marimba/$recorridoId/despachos',
      campos: {
        'vehiculoDestinoId': ?vehiculoDestinoId,
        'tipoCombustible': tipoCombustible,
        'operadorTexto': operadorTexto,
        'litrosSuministrados': '$litrosSuministrados',
        'horometro': '${lecturaMedidor ?? 0}',
      },
      archivos: {
        'fotoHorometro': fotoEvidenciaPath,
        'fotoEvidencia': fotoEvidenciaPath,
      },
    );
    return DespachoMarimba.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<RecorridoMarimba> cerrarRecorrido({
    required String recorridoId,
    double? kmCierre,
    double? horasEquipoMenorCierre,
    required String fotoCierrePath,
    double? existenciaFisica,
    String? fotoNivelPath,
    String? observaciones,
  }) async {
    final data = await _client.postMultipart(
      '/recorridos-marimba/$recorridoId/cerrar',
      campos: {
        'kmCierre': ?kmCierre?.toString(),
        'horasEquipoMenorCierre': ?horasEquipoMenorCierre?.toString(),
        'existenciaFisica': '${existenciaFisica ?? 0}',
        'observaciones': ?observaciones,
      },
      archivos: {
        'fotoCierre': fotoCierrePath,
        'fotoNivel': fotoNivelPath ?? fotoCierrePath,
      },
    );
    return RecorridoMarimba.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<List<RecorridoMarimba>> listarRecorridos({
    String? marimbaId,
    bool? requiereRevision,
  }) async {
    final params = <String, String>{
      'marimbaId': ?marimbaId,
      'requiereRevision': ?requiereRevision?.toString(),
    };
    final query = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _client.get('/recorridos-marimba$query');
    return (data as List)
        .map((j) => RecorridoMarimba.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
