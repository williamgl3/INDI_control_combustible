import '../models/despacho_marimba.dart';
import '../models/recorrido_marimba.dart';
import '../models/panel_marimba.dart';
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
    double? kmInicio,
    double? horasEquipoMenorInicio,
  }) async {
    final data = await _client.post(
      '/recorridos-marimba',
      body: {
        'marimbaId': marimbaId,
        'tipoCombustible': tipoCombustible,
        'frente': frente,
        'kmInicio': ?kmInicio,
        'horasEquipoMenorInicio': ?horasEquipoMenorInicio,
      },
    );
    return RecorridoMarimba.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<double> saldoDeMarimba(
    String marimbaId,
    String tipoCombustible,
  ) async {
    final data = await _client.get(
      '/despachos-marimba/saldo/$marimbaId?tipoCombustible=${Uri.encodeQueryComponent(tipoCombustible)}',
    );
    final valor = (data as Map<String, dynamic>)['saldoActual'];
    return valor is num ? valor.toDouble() : double.parse(valor as String);
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
  }) async {
    final data = await _client.postMultipart(
      '/recorridos-marimba/$recorridoId/despachos',
      campos: {
        'vehiculoDestinoId': vehiculoDestinoId,
        'tipoCombustible': tipoCombustible,
        'operadorTexto': operadorTexto,
        'litrosSuministrados': ?litrosDeclarados?.toString(),
        'horometro': horometro.toString(),
        'medidorInicial': ?medidorInicial?.toString(),
        'medidorFinal': ?medidorFinal?.toString(),
        'ubicacion': ?ubicacion,
        'observaciones': ?observaciones,
      },
      archivos: {
        'fotoHorometro': fotoHorometroPath,
        'fotoMedidor': fotoMedidorPath,
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
    required double existenciaFisica,
    required String fotoNivelPath,
    String? observaciones,
  }) async {
    final data = await _client.postMultipart(
      '/recorridos-marimba/$recorridoId/cerrar',
      campos: {
        'kmCierre': ?kmCierre?.toString(),
        'horasEquipoMenorCierre': ?horasEquipoMenorCierre?.toString(),
        'existenciaFisica': existenciaFisica.toString(),
        'observaciones': ?observaciones,
      },
      archivos: {'fotoCierre': fotoCierrePath, 'fotoNivel': fotoNivelPath},
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

  @override
  Future<List<ResumenUnidadMarimba>> listarResumenUnidades() async {
    final data = await _client.get('/recorridos-marimba/panel/unidades');
    return (data as List)
        .map(
          (item) => ResumenUnidadMarimba.fromJson(item as Map<String, dynamic>),
        )
        .toList(growable: false);
  }

  @override
  Future<PaginaRecorridosMarimba> listarRecorridosAdministrativos(
    FiltrosRecorridosMarimba filtros,
  ) async {
    final parametros = <String, String>{
      'marimbaId': ?filtros.marimbaId,
      'categoria': ?filtros.categoria,
      'tipoCombustible': ?filtros.tipoCombustible,
      'estado': ?filtros.estado,
      'responsableId': ?filtros.responsableId,
      'requiereRevision': ?filtros.requiereRevision?.toString(),
      'fechaDesde': ?filtros.fechaDesde?.toUtc().toIso8601String(),
      'fechaHasta': ?filtros.fechaHasta?.toUtc().toIso8601String(),
      'page': filtros.page.toString(),
      'limit': filtros.limit.toString(),
    };
    final query = parametros.entries
        .map(
          (entry) =>
              '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}',
        )
        .join('&');
    final data = await _client.get(
      '/recorridos-marimba/panel/recorridos?$query',
    );
    return PaginaRecorridosMarimba.fromJson(data as Map<String, dynamic>);
  }
}
