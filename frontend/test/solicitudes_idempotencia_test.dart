import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/solicitud_idempotencia.dart';
import 'package:indi_combustible/data/api_client.dart';
import 'package:indi_combustible/data/api_operaciones_repository.dart';
import 'package:indi_combustible/models/perfil.dart';

import 'test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('genera UUID v4 distinto para cada intencion', () {
    final primera = nuevaIdempotencyKey();
    final segunda = nuevaIdempotencyKey();
    expect(primera, isNot(segunda));
    expect(RegExp(r'^[0-9a-f-]{36}$').hasMatch(primera), isTrue);
  });

  test('fingerprint es determinista, normaliza texto e incluye foto', () async {
    final directorio = await Directory.systemTemp.createTemp(
      'indi-idempotencia-',
    );
    addTearDown(() => directorio.delete(recursive: true));
    final foto = File('${directorio.path}${Platform.pathSeparator}tablero.jpg');
    await foto.writeAsBytes([0xff, 0xd8, 0xff, 1, 2, 3]);

    Future<String> calcular(String actividad) => fingerprintSolicitud(
      choferId: 'chofer-1',
      vehiculoId: 'vehiculo-1',
      litrosSolicitados: 40,
      esUrgente: false,
      motivoChofer: null,
      actividad: actividad,
      fechaProgramada: DateTime.utc(2026, 8, 22),
      fotoTableroPath: foto.path,
    );

    expect(
      await calcular('  Trabajo   normal '),
      await calcular('Trabajo normal'),
    );
    expect(
      await calcular('Trabajo diferente'),
      isNot(await calcular('Trabajo normal')),
    );
  });

  test(
    'cola conserva identidad y deduplica atomically por usuario y payload',
    () async {
      final cola = ColaSolicitudesOffline();
      SolicitudPendienteOffline pendiente(String id, String usuario) =>
          SolicitudPendienteOffline(
            idLocal: id,
            usuarioId: usuario,
            idempotencyKey: id,
            payloadFingerprint: 'f' * 64,
            vehiculoId: 'vehiculo-1',
            litrosSolicitados: 40,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'Trabajo',
            fechaProgramada: DateTime.utc(2026, 8, 22),
            fotoTableroPath: 'foto.jpg',
            creadaEn: DateTime.utc(2026, 8, 21),
          );

      final resultados = await Future.wait([
        cola.agregar(pendiente('00000000-0000-4000-8000-000000000001', 'u1')),
        cola.agregar(pendiente('00000000-0000-4000-8000-000000000002', 'u1')),
      ]);
      expect(resultados.where((valor) => valor), hasLength(1));
      expect(await cola.leer(), hasLength(1));

      expect(
        await cola.agregar(
          pendiente('00000000-0000-4000-8000-000000000003', 'u2'),
        ),
        isTrue,
      );
      final restauradas = await ColaSolicitudesOffline().leer();
      expect(restauradas, hasLength(2));
      expect(restauradas.first.idempotencyKey, isNotEmpty);
      expect(restauradas.first.estado, EstadoSolicitudOffline.pendiente);
    },
  );

  test('reintento actualiza estado sin cambiar identidad', () async {
    final cola = ColaSolicitudesOffline();
    final original = SolicitudPendienteOffline(
      idLocal: '00000000-0000-4000-8000-000000000004',
      usuarioId: 'u1',
      idempotencyKey: '00000000-0000-4000-8000-000000000004',
      payloadFingerprint: 'a' * 64,
      vehiculoId: 'v1',
      litrosSolicitados: 10,
      esUrgente: false,
      motivoChofer: null,
      actividad: 'A',
      fechaProgramada: DateTime.utc(2026, 8, 22),
      fotoTableroPath: 'foto.jpg',
      creadaEn: DateTime.utc(2026, 8, 21),
    );
    await cola.agregar(original);
    await cola.actualizar(
      original.copiar(
        estado: EstadoSolicitudOffline.enviadaSinConfirmar,
        intentos: 1,
        ultimoError: 'timeout',
      ),
    );
    final restaurada = (await cola.leer()).single;
    expect(restaurada.idempotencyKey, original.idempotencyKey);
    expect(restaurada.payloadFingerprint, original.payloadFingerprint);
    expect(restaurada.intentos, 1);
    expect(restaurada.estado, EstadoSolicitudOffline.enviadaSinConfirmar);
  });

  test(
    'cache remoto deduplica por id y conserva solicitudes distintas',
    () async {
      Map<String, dynamic> solicitud(String id, String fechaProgramada) => {
        'id': id,
        'choferId': 'chofer-1',
        'vehiculoId': 'vehiculo-1',
        'litrosSolicitados': 37.25,
        'estado': 'pendiente',
        'creadaEn': '2026-08-21T19:43:00.000Z',
        'actividad': 'Trabajo',
        'fechaProgramada': fechaProgramada,
      };

      final primera = solicitud('solicitud-1', '2099-12-29T06:00:00.000Z');
      final distinta = solicitud('solicitud-2', '2099-12-30T06:00:00.000Z');
      final clienteHttp = MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/solicitudes/mias')) {
          return http.Response(
            jsonEncode([primera, primera, distinta]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (path.endsWith('/cargas/abierta-hoy')) {
          return http.Response('null', 200);
        }
        return http.Response('[]', 200);
      });
      final repo = ApiOperacionesRepository(
        ApiClient(tokenStorage: FakeTokenStorage(), httpClient: clienteHttp),
      );

      await repo.cargarDatosIniciales(
        perfil: const Perfil(
          id: 'chofer-1',
          usuario: 'chofer',
          nombre: 'Chofer',
          correo: 'chofer@example.test',
          rol: RolUsuario.chofer,
        ),
      );

      final solicitudes = repo.solicitudesDeChofer('chofer-1');
      expect(
        solicitudes.map((s) => s.id),
        unorderedEquals(['solicitud-1', 'solicitud-2']),
      );
      expect(solicitudes, hasLength(2));
    },
  );
}
