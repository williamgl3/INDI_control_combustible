import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/token_storage.dart';
import 'package:indi_combustible/data/api_client.dart';
import 'package:indi_combustible/data/api_recorridos_marimba_repository.dart';
import 'package:indi_combustible/models/despacho_marimba.dart';
import 'package:indi_combustible/models/panel_marimba.dart';

class _ApiCapturable extends ApiClient {
  _ApiCapturable() : super(tokenStorage: TokenStorage());

  String? ruta;
  Map<String, dynamic>? cuerpo;
  Map<String, String>? campos;
  Map<String, String?>? archivos;
  dynamic respuestaGet;

  @override
  Future<dynamic> get(String path) async {
    ruta = path;
    return respuestaGet;
  }

  @override
  Future<dynamic> post(String path, {Object? body}) async {
    ruta = path;
    cuerpo = body as Map<String, dynamic>;
    return _recorridoJson;
  }

  @override
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> campos,
    Map<String, String?> archivos = const {},
    Map<String, List<String>> archivosMultiples = const {},
  }) async {
    ruta = path;
    this.campos = campos;
    this.archivos = archivos;
    return path.endsWith('/cerrar') ? _recorridoJson : _despachoJson(null);
  }
}

final _recorridoJson = <String, dynamic>{
  'id': 'recorrido-1',
  'marimbaId': 'marimba-1',
  'tipoCombustible': 'Diésel',
  'operadorId': 'supervisor-1',
  'frente': 'Frente norte',
  'litrosIniciales': 900,
  'estado': 'abierto',
  'iniciadoEn': '2026-08-12T12:00:00.000Z',
};

Map<String, dynamic> _despachoJson(bool? declarada) => {
  'id': 'despacho-1',
  'marimbaId': 'marimba-1',
  'vehiculoDestinoId': 'maquinaria-1',
  'operadorTexto': 'Operador',
  'litrosSuministrados': '20.25',
  'registradoPor': 'supervisor-1',
  'creadoEn': '2026-08-12T12:30:00.000Z',
  'cantidadDeclarada': declarada,
};

void main() {
  test('el resumen usa su endpoint administrativo', () async {
    final api = _ApiCapturable()..respuestaGet = <Object>[];
    await ApiRecorridosMarimbaRepository(api).listarResumenUnidades();
    expect(api.ruta, '/recorridos-marimba/panel/unidades');
  });

  test(
    'el historial envía filtros y paginación sin opcionales inválidos',
    () async {
      final api = _ApiCapturable()
        ..respuestaGet = {
          'items': <Object>[],
          'page': 2,
          'limit': 20,
          'total': 0,
          'totalPages': 0,
        };
      await ApiRecorridosMarimbaRepository(api).listarRecorridosAdministrativos(
        const FiltrosRecorridosMarimba(
          categoria: 'Pipa',
          tipoCombustible: 'Magna',
          estado: 'cerrado',
          requiereRevision: true,
          page: 2,
          limit: 20,
        ),
      );
      expect(api.ruta, contains('categoria=Pipa'));
      expect(api.ruta, contains('tipoCombustible=Magna'));
      expect(api.ruta, contains('estado=cerrado'));
      expect(api.ruta, contains('requiereRevision=true'));
      expect(api.ruta, contains('page=2&limit=20'));
      expect(api.ruta, isNot(contains('responsableId=null')));
      expect(api.ruta, isNot(contains('fechaDesde=null')));
    },
  );
  test('la apertura usa el contrato actual sin inventario enviado', () async {
    final api = _ApiCapturable();
    final repo = ApiRecorridosMarimbaRepository(api);

    await repo.abrirRecorrido(
      marimbaId: 'marimba-1',
      tipoCombustible: 'Diésel',
      frente: 'Frente norte',
      kmInicio: 10,
    );

    expect(api.cuerpo, {
      'marimbaId': 'marimba-1',
      'tipoCombustible': 'Diésel',
      'frente': 'Frente norte',
      'kmInicio': 10.0,
    });
    expect(api.cuerpo, isNot(contains('cargaId')));
    expect(api.cuerpo, isNot(contains('litrosIniciales')));
  });

  test('el despacho medido conserva lecturas y fotos independientes', () async {
    final api = _ApiCapturable();
    final repo = ApiRecorridosMarimbaRepository(api);

    await repo.agregarDespacho(
      recorridoId: 'recorrido-1',
      tipoCombustible: 'Magna',
      vehiculoDestinoId: 'maquinaria-1',
      operadorTexto: 'Operador',
      horometro: 42,
      fotoHorometroPath: 'horometro.jpg',
      medidorInicial: 100.25,
      medidorFinal: 120.5,
      fotoMedidorPath: 'medidor.jpg',
      fotoEvidenciaPath: 'despacho.jpg',
    );

    expect(api.campos!['litrosSuministrados'], isNull);
    expect(api.campos!['medidorInicial'], '100.25');
    expect(api.campos!['medidorFinal'], '120.5');
    expect(api.archivos, {
      'fotoHorometro': 'horometro.jpg',
      'fotoMedidor': 'medidor.jpg',
      'fotoEvidencia': 'despacho.jpg',
    });
  });

  test(
    'el despacho declarado omite medidores y envía litros manuales',
    () async {
      final api = _ApiCapturable();
      final repo = ApiRecorridosMarimbaRepository(api);

      await repo.agregarDespacho(
        recorridoId: 'recorrido-1',
        tipoCombustible: 'Diésel',
        vehiculoDestinoId: 'maquinaria-1',
        operadorTexto: 'Operador',
        horometro: 42,
        fotoHorometroPath: 'horometro.jpg',
        litrosDeclarados: 18.75,
        fotoEvidenciaPath: 'despacho.jpg',
      );

      expect(api.campos!['litrosSuministrados'], '18.75');
      expect(api.campos!['medidorInicial'], isNull);
      expect(api.campos!['medidorFinal'], isNull);
      expect(api.archivos!['fotoMedidor'], isNull);
    },
  );

  test('un registro histórico conserva cantidad declarada nula', () {
    final despacho = DespachoMarimba.fromJson(_despachoJson(null));
    expect(despacho.cantidadDeclarada, isNull);
    expect(despacho.toJson()['cantidadDeclarada'], isNull);
  });

  test('cantidad declarada distingue true y false', () {
    expect(
      DespachoMarimba.fromJson(_despachoJson(true)).cantidadDeclarada,
      isTrue,
    );
    expect(
      DespachoMarimba.fromJson(_despachoJson(false)).cantidadDeclarada,
      isFalse,
    );
  });
}
