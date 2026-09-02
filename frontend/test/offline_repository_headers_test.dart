import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/data/api_client.dart';
import 'package:indi_combustible/data/api_incidencias_repository.dart';
import 'package:indi_combustible/data/api_operaciones_repository.dart';
import 'package:indi_combustible/data/api_recorridos_marimba_repository.dart';

import 'test_helpers.dart';

class _ApiCapturable extends ApiClient {
  _ApiCapturable() : super(tokenStorage: FakeTokenStorage());

  final headersPorRuta = <String, Map<String, String>>{};

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, String> headers = const {},
  }) async {
    headersPorRuta[path] = headers;
    return _recorrido;
  }

  @override
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> campos,
    Map<String, String> headers = const {},
    Map<String, String?> archivos = const {},
    Map<String, List<String>> archivosMultiples = const {},
    Map<String, Uint8List?> archivosBytes = const {},
  }) async {
    headersPorRuta[path] = headers;
    if (path == '/cargas') return _carga;
    if (path == '/cierres-dia') return _cierre;
    if (path == '/incidencias') return _incidencia;
    if (path.endsWith('/cerrar')) return _recorrido;
    return _despacho;
  }
}

const _key = '00000000-0000-4000-8000-000000000321';

final _carga = <String, dynamic>{
  'id': 'carga-1',
  'choferId': 'u1',
  'vehiculoId': 'v1',
  'folioAutorizacion': 'F-1',
  'litrosCargados': 10,
  'kmAlCargar': 20,
  'gasolinera': 'Estacion',
  'creadaEn': '2026-08-25T10:00:00.000Z',
};
final _cierre = <String, dynamic>{
  'id': 'cierre-1',
  'choferId': 'u1',
  'cargaId': 'carga-1',
  'kmFinal': 30,
  'fotoTableroPath': 'foto.jpg',
  'registradaEn': '2026-08-25T18:00:00.000Z',
};
final _incidencia = <String, dynamic>{
  'id': 'incidencia-1',
  'vehiculoId': 'v1',
  'choferId': 'u1',
  'descripcion': 'Falla',
  'estado': 'abierta',
  'creadaEn': '2026-08-25T10:00:00.000Z',
};
final _recorrido = <String, dynamic>{
  'id': 'recorrido-1',
  'marimbaId': 'm1',
  'tipoCombustible': 'Diesel',
  'operadorId': 'u1',
  'frente': 'Norte',
  'litrosIniciales': 100,
  'estado': 'abierto',
  'iniciadoEn': '2026-08-25T10:00:00.000Z',
};
final _despacho = <String, dynamic>{
  'id': 'despacho-1',
  'marimbaId': 'm1',
  'vehiculoDestinoId': 'v2',
  'operadorTexto': 'Operador',
  'litrosSuministrados': 10,
  'registradoPor': 'u1',
  'creadoEn': '2026-08-25T11:00:00.000Z',
};

void main() {
  test(
    'las seis operaciones nuevas del contrato envian la misma key',
    () async {
      final api = _ApiCapturable();
      final operaciones = ApiOperacionesRepository(api);
      final incidencias = ApiIncidenciasRepository(api);
      final recorridos = ApiRecorridosMarimbaRepository(api);

      await operaciones.registrarCargaIdempotente(
        idempotencyKey: _key,
        choferId: 'u1',
        vehiculoId: 'v1',
        folioAutorizacion: 'F-1',
        litrosCargados: 10,
        kmAlCargar: 20,
        gasolinera: 'Estacion',
        fotoTicketPath: 'ticket.jpg',
        fotoTableroPath: 'tablero.jpg',
      );
      await operaciones.cerrarDiaIdempotente(
        idempotencyKey: _key,
        choferId: 'u1',
        cargaId: 'carga-1',
        kmFinal: 30,
        fotoTableroPath: 'tablero.jpg',
      );
      await incidencias.reportarIdempotente(
        idempotencyKey: _key,
        vehiculoId: 'v1',
        descripcion: 'Falla',
        fotoPath: 'foto.jpg',
      );
      await recorridos.abrirRecorridoIdempotente(
        idempotencyKey: _key,
        marimbaId: 'm1',
        tipoCombustible: 'Diesel',
        frente: 'Norte',
      );
      await recorridos.agregarDespachoIdempotente(
        idempotencyKey: _key,
        recorridoId: 'recorrido-1',
        tipoCombustible: 'Diesel',
        vehiculoDestinoId: 'v2',
        operadorTexto: 'Operador',
        horometro: 1,
        fotoHorometroPath: 'foto.jpg',
        litrosDeclarados: 10,
      );
      await recorridos.cerrarRecorridoIdempotente(
        idempotencyKey: _key,
        recorridoId: 'recorrido-1',
        fotoCierrePath: 'cierre.jpg',
        existenciaFisica: 90,
        fotoNivelPath: 'nivel.jpg',
      );

      expect(api.headersPorRuta, hasLength(6));
      expect(
        api.headersPorRuta.values,
        everyElement(containsPair('Idempotency-Key', _key)),
      );
    },
  );
}
