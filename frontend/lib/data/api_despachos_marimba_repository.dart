import '../models/despacho_marimba.dart';
import 'api_client.dart';
import 'despachos_marimba_repository.dart';

class ApiDespachosMarimbaRepository implements DespachosMarimbaRepository {
  ApiDespachosMarimbaRepository(this._client);

  final ApiClient _client;

  @override
  Future<double> saldoDeMarimba(String marimbaId) async {
    final data = await _client.get('/despachos-marimba/saldo/$marimbaId');
    return ((data as Map<String, dynamic>)['saldoActual'] as num).toDouble();
  }

  @override
  Future<List<DespachoMarimba>> listarDespachosDeMarimba(String marimbaId) async {
    final data = await _client.get('/despachos-marimba?marimbaId=$marimbaId');
    return (data as List)
        .map((j) => DespachoMarimba.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  @override
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
  }) async {
    final data = await _client.postMultipart(
      '/despachos-marimba',
      campos: {
        'marimbaId': marimbaId,
        'vehiculoDestinoId': ?vehiculoDestinoId,
        'destinoTexto': ?destinoTexto,
        'operadorTexto': operadorTexto,
        'residenteTexto': ?residenteTexto,
        'sitio': sitio,
        'litrosSolicitados': ?litrosSolicitados?.toString(),
        'litrosSuministrados': '$litrosSuministrados',
        'lecturaMedidor': ?lecturaMedidor?.toString(),
        'estado': estado.name,
      },
      archivos: {'fotoEvidencia': fotoEvidenciaPath},
    );
    return DespachoMarimba.fromJson(data as Map<String, dynamic>);
  }
}
