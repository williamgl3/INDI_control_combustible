import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:indi_combustible/core/token_storage.dart';
import 'package:indi_combustible/data/api_client.dart';

/// Fake en memoria de [TokenStorage] — evita depender del canal de
/// plataforma real de `flutter_secure_storage` en estos tests puros.
class _FakeTokenStorage extends TokenStorage {
  String? token;
  String? refreshToken;

  @override
  Future<void> guardarToken(String t) async => token = t;

  @override
  Future<String?> leerToken() async => token;

  @override
  Future<void> borrarToken() async => token = null;

  @override
  Future<void> guardarRefreshToken(String t) async => refreshToken = t;

  @override
  Future<String?> leerRefreshToken() async => refreshToken;

  @override
  Future<void> borrarRefreshToken() async => refreshToken = null;
}

void main() {
  test(
    'un 401 dispara un refresh y reintenta la petición original una sola vez',
    () async {
      final storage = _FakeTokenStorage()
        ..token = 'token-viejo'
        ..refreshToken = 'refresh-viejo';
      var intentosDato = 0;
      var intentosRefresh = 0;

      final mockHttp = MockClient((request) async {
        if (request.url.path == '/refresh') {
          intentosRefresh++;
          return http.Response(
            jsonEncode({'token': 'token-nuevo', 'refreshToken': 'refresh-nuevo'}),
            200,
          );
        }
        if (request.url.path == '/dato') {
          intentosDato++;
          if (intentosDato == 1) {
            return http.Response(jsonEncode({'error': 'Token expirado'}), 401);
          }
          // La segunda vez debe llevar el token ya renovado.
          expect(request.headers['Authorization'], 'Bearer token-nuevo');
          return http.Response(jsonEncode({'ok': true}), 200);
        }
        return http.Response('not found', 404);
      });

      final client = ApiClient(tokenStorage: storage, httpClient: mockHttp);
      final data = await client.get('/dato');

      expect(data, {'ok': true});
      expect(intentosDato, 2);
      expect(intentosRefresh, 1);
      expect(storage.token, 'token-nuevo');
      expect(storage.refreshToken, 'refresh-nuevo');
    },
  );

  test(
    'si el refresh también falla, limpia la sesión y propaga el 401 original',
    () async {
      final storage = _FakeTokenStorage()
        ..token = 'token-viejo'
        ..refreshToken = 'refresh-vencido';

      final mockHttp = MockClient((request) async {
        if (request.url.path == '/refresh') {
          return http.Response(
            jsonEncode({'error': 'Refresh token inválido'}),
            401,
          );
        }
        return http.Response(jsonEncode({'error': 'Token expirado'}), 401);
      });

      final client = ApiClient(tokenStorage: storage, httpClient: mockHttp);

      await expectLater(
        client.get('/dato'),
        throwsA(isA<ApiException>()),
      );
      expect(storage.token, isNull);
      expect(storage.refreshToken, isNull);
    },
  );

  test('sin refresh token guardado, un 401 no intenta refrescar', () async {
    final storage = _FakeTokenStorage()..token = 'token-viejo';
    var llamadasRefresh = 0;

    final mockHttp = MockClient((request) async {
      if (request.url.path == '/refresh') {
        llamadasRefresh++;
      }
      return http.Response(jsonEncode({'error': 'Token expirado'}), 401);
    });

    final client = ApiClient(tokenStorage: storage, httpClient: mockHttp);
    await expectLater(client.get('/dato'), throwsA(isA<ApiException>()));
    expect(llamadasRefresh, 0);
  });
}
