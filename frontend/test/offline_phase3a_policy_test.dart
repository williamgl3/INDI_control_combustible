import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/offline/metadata_operacion_offline.dart';
import 'package:indi_combustible/core/offline/politica_retry_offline.dart';
import 'package:indi_combustible/data/api_client.dart';

class _RandomMaximo implements Random {
  @override
  bool nextBool() => true;

  @override
  double nextDouble() => 0.999999;

  @override
  int nextInt(int max) => max - 1;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('idLocal e idempotencyKey son identidades UUID v4 separadas', () {
    final pendiente = ComprobarCargaPendienteOffline(
      idLocal: nuevaIdempotencyKeyOffline(),
      choferId: 'u1',
      vehiculoId: 'v1',
      folioAutorizacion: 'F-1',
      litrosCargados: 10,
      kmAlCargar: 20,
      gasolinera: 'Estacion',
      fotoTicketPath: 'ticket.jpg',
      fotoTableroPath: 'tablero.jpg',
      creadaEn: DateTime.utc(2026, 8, 25),
    );

    expect(esUuidV4(pendiente.idLocal), isTrue);
    expect(esUuidV4(pendiente.idempotencyKey), isTrue);
    expect(pendiente.idLocal, isNot(pendiente.idempotencyKey));
  });

  test('round-trip conserva toda la metadata de retry', () {
    final metadata = MetadataOperacionOffline.nueva().copiar(
      estado: EstadoOperacionOffline.errorTransitorio,
      intentos: 4,
      ultimoIntento: DateTime.utc(2026, 8, 25, 10),
      proximoIntento: DateTime.utc(2026, 8, 25, 10, 5),
      ultimoError: 'temporal',
      ultimoStatus: 503,
      ultimoCodigo: 'TEMPORAL',
      requiereLogin: true,
    );

    final restaurada = MetadataOperacionOffline.fromJson(metadata.toJson());

    expect(restaurada.idempotencyKey, metadata.idempotencyKey);
    expect(restaurada.estado, EstadoOperacionOffline.errorTransitorio);
    expect(restaurada.intentos, 4);
    expect(restaurada.ultimoIntento, metadata.ultimoIntento);
    expect(restaurada.proximoIntento, metadata.proximoIntento);
    expect(restaurada.ultimoError, 'temporal');
    expect(restaurada.ultimoStatus, 503);
    expect(restaurada.ultimoCodigo, 'TEMPORAL');
    expect(restaurada.requiereLogin, isTrue);
  });

  test('legacy genera y persiste UUID una sola vez sin usar idLocal', () async {
    const idLocalLegacy = 'offline-1724590000000000';
    final legacy = {
      'idLocal': idLocalLegacy,
      'choferId': 'u1',
      'vehiculoId': 'v1',
      'folioAutorizacion': 'F-1',
      'litrosCargados': 10,
      'kmAlCargar': 20,
      'gasolinera': 'Estacion',
      'fotoTicketPath': 'ticket.jpg',
      'fotoTableroPath': 'tablero.jpg',
      'litrosDetectadosOcr': null,
      'creadaEn': '2026-08-25T10:00:00.000Z',
    };
    SharedPreferences.setMockInitialValues({
      'cola_comprobar_carga_offline': [jsonEncode(legacy)],
    });

    final primera = (await ColaComprobarCargaOffline().leer()).single;
    final segunda = (await ColaComprobarCargaOffline().leer()).single;

    expect(esUuidV4(primera.idempotencyKey), isTrue);
    expect(primera.idempotencyKey, isNot(idLocalLegacy));
    expect(segunda.idempotencyKey, primera.idempotencyKey);
    expect(segunda.idLocal, idLocalLegacy);
  });

  test('legacy sin propietario queda en revision y no se reasigna', () async {
    final json = {
      'idLocal': 'offline-legacy',
      'vehiculoId': 'v1',
      'descripcion': 'Falla',
      'creadaEn': '2026-08-25T10:00:00.000Z',
      'fotoPath': null,
    };
    SharedPreferences.setMockInitialValues({
      'cola_incidencias_offline': [jsonEncode(json)],
    });

    final pendiente = (await ColaIncidenciasOffline().leer()).single;

    expect(pendiente.usuarioId, isEmpty);
    expect(pendiente.metadata.estado, EstadoOperacionOffline.requiereRevision);
    expect(pendiente.metadata.ultimoCodigo, 'LEGACY_USUARIO_DESCONOCIDO');
  });

  test('clasificador conserva todos los errores contractuales', () {
    const clasificador = ClasificadorHttpOffline();
    final casos = <ApiException, EstadoOperacionOffline>{
      ApiException('sin red', categoriaTransporte: CategoriaTransporte.sinRed):
          EstadoOperacionOffline.errorTransitorio,
      ApiException('timeout', categoriaTransporte: CategoriaTransporte.timeout):
          EstadoOperacionOffline.errorTransitorio,
      ApiException('408', status: 408): EstadoOperacionOffline.errorTransitorio,
      ApiException('429', status: 429): EstadoOperacionOffline.errorTransitorio,
      ApiException('500', status: 500): EstadoOperacionOffline.errorTransitorio,
      ApiException('503', status: 503): EstadoOperacionOffline.errorTransitorio,
      ApiException('403', status: 403): EstadoOperacionOffline.errorPermanente,
      ApiException('404', status: 404): EstadoOperacionOffline.requiereRevision,
      ApiException('422', status: 422): EstadoOperacionOffline.errorPermanente,
      ApiException(
        'mismatch',
        status: 409,
        codigo: 'IDEMPOTENCY_KEY_PAYLOAD_MISMATCH',
      ): EstadoOperacionOffline.conflicto,
    };

    for (final caso in casos.entries) {
      expect(clasificador.clasificar(caso.key).estado, caso.value);
    }
    final sesion = clasificador.clasificar(ApiException('401', status: 401));
    expect(sesion.estado, EstadoOperacionOffline.errorTransitorio);
    expect(sesion.requiereLogin, isTrue);
  });

  test('401, 403, 404, 408, 409, 422, 429 y 5xx no eliminan', () async {
    final errores = [
      ApiException('401', status: 401),
      ApiException('403', status: 403),
      ApiException('404', status: 404),
      ApiException('408', status: 408),
      ApiException(
        'mismatch',
        status: 409,
        codigo: 'IDEMPOTENCY_KEY_PAYLOAD_MISMATCH',
      ),
      ApiException('422', status: 422),
      ApiException('429', status: 429),
      ApiException('500', status: 500),
      ApiException('503', status: 503),
      ApiException('timeout', categoriaTransporte: CategoriaTransporte.timeout),
    ];

    for (var indice = 0; indice < errores.length; indice++) {
      SharedPreferences.setMockInitialValues({});
      final cola = ColaComprobarCargaOffline();
      final pendiente = ComprobarCargaPendienteOffline(
        idLocal: 'local-$indice',
        choferId: 'u1',
        vehiculoId: 'v1',
        folioAutorizacion: 'F-$indice',
        litrosCargados: 10,
        kmAlCargar: 20,
        gasolinera: 'Estacion',
        fotoTicketPath: 'ticket.jpg',
        fotoTableroPath: 'tablero.jpg',
        creadaEn: DateTime.utc(2026, 8, 25),
      );
      await cola.agregar(pendiente);

      await cola.registrarError(pendiente.idLocal, errores[indice]);

      final conservada = (await cola.leer()).single;
      expect(conservada.idempotencyKey, pendiente.idempotencyKey);
      expect(conservada.metadata.intentos, 1);
      if (errores[indice].status == 401) {
        expect(conservada.metadata.requiereLogin, isTrue);
      }
      if (errores[indice].status == 409) {
        expect(conservada.metadata.estado, EstadoOperacionOffline.conflicto);
      }
    }
  });

  test('backoff usa full jitter, cap, Retry-After y suspende automatico', () {
    final ahora = DateTime.utc(2026, 8, 25, 10);
    final politica = PoliticaBackoffOffline(
      random: _RandomMaximo(),
      reloj: () => ahora,
    );

    expect(
      politica.proximoIntento(intentos: 1),
      ahora.add(const Duration(seconds: 4)),
    );
    expect(
      politica.proximoIntento(intentos: 9),
      ahora.add(const Duration(seconds: 900)),
    );
    expect(
      politica.proximoIntento(
        intentos: 1,
        retryAfter: const Duration(minutes: 2),
      ),
      ahora.add(const Duration(minutes: 2)),
    );
    expect(politica.proximoIntento(intentos: 10), isNull);
  });
}
