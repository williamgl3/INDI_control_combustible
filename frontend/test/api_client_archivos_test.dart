import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:indi_combustible/core/token_storage.dart';
import 'package:indi_combustible/data/api_client.dart';

class _TokenStorageMemoria extends TokenStorage {
  String? token;
  String? refreshToken;

  @override
  Future<String?> leerToken() async => token;
  @override
  Future<String?> leerRefreshToken() async => refreshToken;
  @override
  Future<void> guardarToken(String valor) async => token = valor;
  @override
  Future<void> guardarRefreshToken(String valor) async => refreshToken = valor;
  @override
  Future<void> borrarToken() async => token = null;
  @override
  Future<void> borrarRefreshToken() async => refreshToken = null;
}

const _id = '550e8400-e29b-41d4-a716-446655440000.jpg';

void main() {
  test('normaliza referencias históricas y privadas', () {
    expect(normalizarReferenciaArchivo('/uploads/$_id'), '/archivos/$_id');
    expect(normalizarReferenciaArchivo('/archivos/$_id'), '/archivos/$_id');
  });

  test('rechaza URL externa y no realiza petición', () async {
    var peticiones = 0;
    final client = ApiClient(
      tokenStorage: _TokenStorageMemoria()..token = 'token',
      httpClient: MockClient((_) async {
        peticiones++;
        return http.Response('', 200);
      }),
    );
    await expectLater(
      client.descargarArchivo('https://malicioso.example/$_id'),
      throwsA(isA<ApiException>()),
    );
    expect(peticiones, 0);
  });

  test('descarga bytes con Authorization sin imprimir el cuerpo', () async {
    final storage = _TokenStorageMemoria()..token = 'token-privado';
    final bytes = Uint8List.fromList([0, 1, 2, 200, 255]);
    final logs = <String>[];
    final debugAnterior = debugPrint;
    debugPrint = (mensaje, {wrapWidth}) {
      if (mensaje != null) logs.add(mensaje);
    };
    try {
      final client = ApiClient(
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/archivos/$_id');
          expect(request.headers['Authorization'], 'Bearer token-privado');
          return http.Response.bytes(
            bytes,
            200,
            headers: {'content-type': 'image/jpeg'},
          );
        }),
      );
      expect(await client.descargarArchivo('/uploads/$_id'), bytes);
      expect(logs.join('\n'), isNot(contains('[0, 1, 2, 200, 255]')));
    } finally {
      debugPrint = debugAnterior;
    }
  });

  test(
    'refresca una vez ante el primer 401 y reintenta con el token nuevo',
    () async {
      final storage = _TokenStorageMemoria()
        ..token = 'viejo'
        ..refreshToken = 'refresh-viejo';
      var descargas = 0;
      var refresh = 0;
      final client = ApiClient(
        tokenStorage: storage,
        httpClient: MockClient((request) async {
          if (request.url.path == '/refresh') {
            refresh++;
            return http.Response(
              jsonEncode({'token': 'nuevo', 'refreshToken': 'refresh-nuevo'}),
              200,
            );
          }
          descargas++;
          if (descargas == 1) {
            return http.Response(jsonEncode({'error': 'expirado'}), 401);
          }
          expect(request.headers['Authorization'], 'Bearer nuevo');
          return http.Response.bytes([1, 2, 3], 200);
        }),
      );
      expect(await client.descargarArchivo('/archivos/$_id'), [1, 2, 3]);
      expect(descargas, 2);
      expect(refresh, 1);
    },
  );

  test(
    'segundo 401 limpia sesión y mantiene el comportamiento existente',
    () async {
      final storage = _TokenStorageMemoria()
        ..token = 'viejo'
        ..refreshToken = 'refresh-viejo';
      var sesionesExpiradas = 0;
      final client = ApiClient(
        tokenStorage: storage,
        onSesionExpirada: () => sesionesExpiradas++,
        httpClient: MockClient((request) async {
          if (request.url.path == '/refresh') {
            return http.Response(
              jsonEncode({'token': 'nuevo', 'refreshToken': 'refresh-nuevo'}),
              200,
            );
          }
          return http.Response(jsonEncode({'error': 'rechazado'}), 401);
        }),
      );
      await expectLater(
        client.descargarArchivo('/archivos/$_id'),
        throwsA(isA<ApiException>()),
      );
      expect(storage.token, isNull);
      expect(storage.refreshToken, isNull);
      expect(sesionesExpiradas, 1);
    },
  );
}
