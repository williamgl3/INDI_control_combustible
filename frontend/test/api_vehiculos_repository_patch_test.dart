import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/token_storage.dart';
import 'package:indi_combustible/data/api_client.dart';
import 'package:indi_combustible/data/api_vehiculos_repository.dart';
import 'package:indi_combustible/data/vehiculos_repository.dart';

class _TokenStorageVacio extends TokenStorage {
  @override
  Future<String?> leerToken() async => null;
}

class _ApiClientCaptura extends ApiClient {
  _ApiClientCaptura() : super(tokenStorage: _TokenStorageVacio());

  Object? ultimoBody;
  Map<String, dynamic> respuesta = _respuestaUnidad();

  @override
  Future<dynamic> patch(String path, {Object? body}) async {
    ultimoBody = body;
    return respuesta;
  }
}

Map<String, dynamic> _respuestaUnidad({double? intervalo = 5000}) => {
  'id': 'unidad-1',
  'tipoUnidad': 'Vehículo',
  'placas': 'TEST-001',
  'numeroEconomico': null,
  'etiquetaUnidad': 'TEST-001',
  'tipoCombustible': 'Diésel',
  'modelo': 'Unidad de prueba',
  'intervaloServicio': intervalo,
  'lecturaUltimoServicio': null,
  'fechaUltimoServicio': null,
  'activo': true,
  'unidadPadreId': null,
  'ubicacion': null,
};

void main() {
  test('PATCH omite campos no tocados', () async {
    final client = _ApiClientCaptura();
    final repo = ApiVehiculosRepository(client);

    await repo.actualizar(
      id: 'unidad-1',
      cambios: const ActualizacionVehiculo(
        modelo: CampoActualizacion.valor('Editada'),
      ),
    );

    final body = client.ultimoBody! as Map<String, dynamic>;
    expect(body, {'modelo': 'Editada'});
    expect(body, isNot(contains('placas')));
    expect(body, isNot(contains('intervaloServicio')));
  });

  test('PATCH incluye null explícito para campos eliminables', () async {
    final client = _ApiClientCaptura()
      ..respuesta = _respuestaUnidad(intervalo: null);
    final repo = ApiVehiculosRepository(client);

    await repo.actualizar(
      id: 'unidad-1',
      cambios: const ActualizacionVehiculo(
        placas: CampoActualizacion.valor(null),
        numeroEconomico: CampoActualizacion.valor('TEST-001'),
        intervaloServicio: CampoActualizacion.valor(null),
        ubicacion: CampoActualizacion.valor(null),
        unidadPadreId: CampoActualizacion.valor(null),
      ),
    );

    final body = client.ultimoBody! as Map<String, dynamic>;
    expect(body['placas'], isNull);
    expect(body['numeroEconomico'], 'TEST-001');
    expect(body['intervaloServicio'], isNull);
    expect(body['ubicacion'], isNull);
    expect(body['unidadPadreId'], isNull);
  });
}
