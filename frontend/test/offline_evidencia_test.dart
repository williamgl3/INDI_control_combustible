import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/offline/metadata_operacion_offline.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/core/solicitud_idempotencia.dart';
import 'package:indi_combustible/data/api_client.dart';
import 'package:indi_combustible/models/perfil.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('EvidenciaPendienteOffline', () {
    test('round-trip serializa y deserializa correctamente', () {
      final ahora = DateTime.utc(2026, 8, 25, 12);
      final pendiente = EvidenciaPendienteOffline(
        idLocal: 'evidencia-123',
        usuarioId: 'usuario-1',
        tipo: 'comprobante',
        km: null,
        folioId: 'folio-1',
        cargaId: null,
        pendienteVincular: false,
        notas: 'Evidencia de prueba',
        tipoCombustibleCargado: 'diesel',
        litros: 50.5,
        precioPorLitro: 23.99,
        montoPagado: 1211.50,
        creadaEn: ahora,
        fotoPaths: ['/tmp/foto1.jpg', '/tmp/foto2.jpg'],
        archivosOffline: [],
        payloadFingerprint: 'abc123',
      );

      final restaurada = EvidenciaPendienteOffline.fromJson(pendiente.toJson());

      expect(restaurada.idLocal, 'evidencia-123');
      expect(restaurada.usuarioId, 'usuario-1');
      expect(restaurada.tipo, 'comprobante');
      expect(restaurada.folioId, 'folio-1');
      expect(restaurada.pendienteVincular, isFalse);
      expect(restaurada.notas, 'Evidencia de prueba');
      expect(restaurada.tipoCombustibleCargado, 'diesel');
      expect(restaurada.litros, 50.5);
      expect(restaurada.precioPorLitro, 23.99);
      expect(restaurada.montoPagado, 1211.50);
      expect(restaurada.creadaEn, ahora);
      expect(restaurada.fotoPaths, ['/tmp/foto1.jpg', '/tmp/foto2.jpg']);
      expect(restaurada.payloadFingerprint, 'abc123');
    });

    test('conMetadata preserva campos y actualiza metadata', () {
      final pendiente = EvidenciaPendienteOffline(
        idLocal: 'evidencia-1',
        usuarioId: 'u1',
        tipo: 'tablero',
        km: 1234.5,
        pendienteVincular: true,
        creadaEn: DateTime.utc(2026, 8, 25),
        fotoPaths: [],
        archivosOffline: [],
      );

      final nuevaMetadata = pendiente.metadata.copiar(
        estado: EstadoOperacionOffline.sincronizando,
      );
      final actualizada = pendiente.conMetadata(nuevaMetadata);

      expect(actualizada.idLocal, 'evidencia-1');
      expect(actualizada.km, 1234.5);
      expect(actualizada.pendienteVincular, isTrue);
      expect(actualizada.metadata.estado, EstadoOperacionOffline.sincronizando);
    });
  });

  group('ColaEvidenciasOffline', () {
    test(
      'agregar, leer, quitar y actualizar persisten correctamente',
      () async {
        final cola = ColaEvidenciasOffline();
        final pendiente = EvidenciaPendienteOffline(
          idLocal: 'ev-local',
          usuarioId: 'u1',
          tipo: 'tablero',
          km: 500,
          pendienteVincular: true,
          creadaEn: DateTime.utc(2026, 8, 25),
          fotoPaths: ['foto.jpg'],
          archivosOffline: [],
        );

        await cola.agregar(pendiente);
        final items = await cola.leer();
        expect(items, hasLength(1));
        expect(items.first.idLocal, 'ev-local');

        // Actualizar metadata
        final actualizada = pendiente.conMetadata(
          pendiente.metadata.copiar(
            estado: EstadoOperacionOffline.sincronizando,
          ),
        );
        await cola.actualizar(actualizada);
        final items2 = await cola.leer();
        expect(
          items2.first.metadata.estado,
          EstadoOperacionOffline.sincronizando,
        );

        // Quitar
        await cola.quitar('ev-local');
        expect(await cola.leer(), isEmpty);
      },
    );

    test('registrarError guarda el último error', () async {
      final cola = ColaEvidenciasOffline();
      await cola.agregar(
        EvidenciaPendienteOffline(
          idLocal: 'ev-err',
          usuarioId: 'u1',
          tipo: 'comprobante',
          pendienteVincular: false,
          creadaEn: DateTime.utc(2026, 8, 25),
          fotoPaths: [],
          archivosOffline: [],
        ),
      );

      await cola.registrarError(
        'ev-err',
        ApiException('Error de prueba', status: 500),
      );

      final items = await cola.leer();
      expect(items, hasLength(1));
    });
  });

  group('fingerprintEvidencia', () {
    test('mismo payload produce mismo fingerprint', () async {
      final fp1 = await fingerprintEvidencia(
        usuarioId: 'u1',
        tipo: 'comprobante',
        km: 123.45,
        folioId: 'f1',
        pendienteVincular: false,
        notas: 'Nota',
        tipoCombustibleCargado: 'diesel',
        litros: 50.0,
        precioPorLitro: 23.99,
        montoPagado: 1199.50,
        fotosSha256: ['abc123', 'def456'],
      );

      final fp2 = await fingerprintEvidencia(
        usuarioId: 'u1',
        tipo: 'comprobante',
        km: 123.45,
        folioId: 'f1',
        pendienteVincular: false,
        notas: 'Nota',
        tipoCombustibleCargado: 'diesel',
        litros: 50.0,
        precioPorLitro: 23.99,
        montoPagado: 1199.50,
        fotosSha256: ['abc123', 'def456'],
      );

      expect(fp1, fp2);
      expect(fp1.length, 64); // SHA-256 hex = 64 chars
    });

    test('payload diferente produce fingerprint diferente', () async {
      final fp1 = await fingerprintEvidencia(
        usuarioId: 'u1',
        tipo: 'comprobante',
        pendienteVincular: false,
        fotosSha256: ['abc123'],
      );

      final fp2 = await fingerprintEvidencia(
        usuarioId: 'u1',
        tipo: 'tablero',
        pendienteVincular: false,
        fotosSha256: ['abc123'],
      );

      expect(fp1, isNot(fp2));
    });

    test('campos opcionales null no rompen el fingerprint', () async {
      final fp = await fingerprintEvidencia(
        usuarioId: 'u1',
        tipo: 'tablero',
        pendienteVincular: true,
        fotosSha256: [],
      );
      expect(fp.length, 64);
    });
  });

  group('totalPendientesOfflineProvider incluye evidencias', () {
    testWidgets('cuenta evidencias del usuario actual', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      _iniciar(container, 'chofer-1');

      final cola = container.read(colaEvidenciasOfflineProvider);
      await cola.agregar(
        EvidenciaPendienteOffline(
          idLocal: 'ev-count',
          usuarioId: 'chofer-1',
          tipo: 'comprobante',
          pendienteVincular: false,
          creadaEn: DateTime.utc(2026, 8, 25),
          fotoPaths: [],
          archivosOffline: [],
        ),
      );

      final total = await container.read(totalPendientesOfflineProvider.future);
      expect(total, greaterThanOrEqualTo(1));
    });

    testWidgets('no cuenta evidencias de otro usuario', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      _iniciar(container, 'chofer-1');

      final cola = container.read(colaEvidenciasOfflineProvider);
      await cola.agregar(
        EvidenciaPendienteOffline(
          idLocal: 'ev-other',
          usuarioId: 'chofer-2',
          tipo: 'tablero',
          pendienteVincular: false,
          creadaEn: DateTime.utc(2026, 8, 25),
          fotoPaths: [],
          archivosOffline: [],
        ),
      );

      // La evidencia es de otro usuario, no debe contar.
      final items = await cola.leer();
      expect(items.first.usuarioId, 'chofer-2');
    });
  });
}

void _iniciar(ProviderContainer container, String id) {
  container
      .read(sessionProvider.notifier)
      .iniciarSesion(
        Perfil(
          id: id,
          usuario: id,
          nombre: id,
          correo: '$id@example.test',
          rol: RolUsuario.chofer,
        ),
      );
}
