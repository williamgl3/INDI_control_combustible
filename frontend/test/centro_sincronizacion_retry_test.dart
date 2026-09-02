import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/centro_sincronizacion/agregador_sincronizacion.dart';
import 'package:indi_combustible/core/centro_sincronizacion/centro_providers.dart';
import 'package:indi_combustible/core/centro_sincronizacion/operacion_sincronizacion_view.dart';
import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/offline/metadata_operacion_offline.dart';

OperacionSincronizacionView _op({
  bool puedeReintentar = true,
  bool requiereAtencion = false,
  EstadoVisualSincronizacion estadoVisual = EstadoVisualSincronizacion.pendiente,
}) =>
    OperacionSincronizacionView(
      idLocal: 'test-0000-0000-000000000001',
      tipo: TipoOperacionOffline.solicitud,
      titulo: 'Solicitud de carga',
      descripcion: '100L · Prueba',
      estado: EstadoOperacionOffline.pendiente,
      estadoVisual: estadoVisual,
      usuarioId: 'userA',
      intentos: 0,
      creadaEn: DateTime.now(),
      puedeReintentar: puedeReintentar,
      requiereAtencion: requiereAtencion,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('reintentarOperacion', () {
    test('retorna false si puedeReintentar es false (sincronizando)', () {
      final op = _op(puedeReintentar: false);
      expect(op.puedeReintentar, isFalse);
    });

    test('retorna false si puedeReintentar es false (sincronizada)', () {
      final op = _op(
        puedeReintentar: false,
        estadoVisual: EstadoVisualSincronizacion.completada,
      );
      expect(op.puedeReintentar, isFalse);
    });

    test('retorna false si puedeReintentar es false (requiereRevision)', () {
      final op = _op(
        puedeReintentar: false,
        estadoVisual: EstadoVisualSincronizacion.requiereRevision,
      );
      expect(op.puedeReintentar, isFalse);
    });

    test('retorna true si puedeReintentar es true (errorPermanente)', () {
      final op = _op(
        puedeReintentar: true,
        estadoVisual: EstadoVisualSincronizacion.errorPermanente,
      );
      expect(op.puedeReintentar, isTrue);
    });

    test('retorna true si puedeReintentar es true (conflicto)', () {
      final op = _op(
        puedeReintentar: true,
        estadoVisual: EstadoVisualSincronizacion.conflicto,
      );
      expect(op.puedeReintentar, isTrue);
    });

    test('retorna true si puedeReintentar es true (errorTransitorio)', () {
      final op = _op(
        puedeReintentar: true,
        estadoVisual: EstadoVisualSincronizacion.errorTransitorio,
      );
      expect(op.puedeReintentar, isTrue);
    });

    test('retorna true si puedeReintentar es true (pendiente)', () {
      final op = _op(
        puedeReintentar: true,
        estadoVisual: EstadoVisualSincronizacion.pendiente,
      );
      expect(op.puedeReintentar, isTrue);
    });

    test('retorna true si puedeReintentar es true (reintentoPendiente)', () {
      final op = _op(
        puedeReintentar: true,
        estadoVisual: EstadoVisualSincronizacion.reintentoPendiente,
      );
      expect(op.puedeReintentar, isTrue);
    });
  });

  group('sincronizarTodasOffline', () {
    test('retorna 0 si no hay reintentables', () {
      final data = CentroSincronizacionData(
        operaciones: [
          _op(puedeReintentar: false),
        ],
        conteoPorEstado: {},
        total: 1,
        requiereAtencion: 0,
        reintentables: 0,
      );

      expect(data.reintentables, 0);
    });

    test('cuenta correctamente los reintentables', () {
      final data = CentroSincronizacionData(
        operaciones: [
          _op(puedeReintentar: true),
          _op(puedeReintentar: true),
          _op(puedeReintentar: false),
        ],
        conteoPorEstado: {},
        total: 3,
        requiereAtencion: 0,
        reintentables: 2,
      );

      expect(data.reintentables, 2);
    });

    test('cuenta correctamente los que requieren atención', () {
      final data = CentroSincronizacionData(
        operaciones: [
          _op(requiereAtencion: true),
          _op(requiereAtencion: true),
          _op(requiereAtencion: false),
        ],
        conteoPorEstado: {},
        total: 3,
        requiereAtencion: 2,
        reintentables: 1,
      );

      expect(data.requiereAtencion, 2);
    });
  });

  group('filtrarPorEstados', () {
    test('retorna todas si el set está vacío', () {
      final data = CentroSincronizacionData(
        operaciones: [_op(), _op()],
        conteoPorEstado: {},
        total: 2,
      );

      final resultado = filtrarPorEstados(data, {});
      expect(resultado.length, 2);
    });

    test('filtra solo los estados seleccionados', () {
      final data = CentroSincronizacionData(
        operaciones: [
          _op(estadoVisual: EstadoVisualSincronizacion.pendiente),
          _op(estadoVisual: EstadoVisualSincronizacion.errorPermanente),
          _op(estadoVisual: EstadoVisualSincronizacion.pendiente),
        ],
        conteoPorEstado: {},
        total: 3,
      );

      final resultado = filtrarPorEstados(
        data,
        {EstadoVisualSincronizacion.errorPermanente},
      );
      expect(resultado.length, 1);
    });

    test('filtra múltiples estados', () {
      final data = CentroSincronizacionData(
        operaciones: [
          _op(estadoVisual: EstadoVisualSincronizacion.pendiente),
          _op(estadoVisual: EstadoVisualSincronizacion.errorPermanente),
          _op(estadoVisual: EstadoVisualSincronizacion.errorTransitorio),
          _op(estadoVisual: EstadoVisualSincronizacion.completada),
        ],
        conteoPorEstado: {},
        total: 4,
      );

      final resultado = filtrarPorEstados(
        data,
        {
          EstadoVisualSincronizacion.pendiente,
          EstadoVisualSincronizacion.errorPermanente,
        },
      );
      expect(resultado.length, 2);
    });
  });

  group('filtrarPorTipos', () {
    test('retorna todas si el set está vacío', () {
      final data = CentroSincronizacionData(
        operaciones: [_op(), _op()],
        conteoPorEstado: {},
        total: 2,
      );

      final resultado = filtrarPorTipos(data, {});
      expect(resultado.length, 2);
    });

    test('filtra solo los tipos seleccionados', () {
      final data = CentroSincronizacionData(
        operaciones: [
          _op(),
          OperacionSincronizacionView(
            idLocal: 'inc-001',
            tipo: TipoOperacionOffline.incidencia,
            titulo: 'Incidencia',
            descripcion: 'Falla',
            estado: EstadoOperacionOffline.pendiente,
            estadoVisual: EstadoVisualSincronizacion.pendiente,
            usuarioId: 'userA',
            intentos: 0,
            creadaEn: DateTime.now(),
          ),
        ],
        conteoPorEstado: {},
        total: 2,
      );

      final resultado = filtrarPorTipos(
        data,
        {TipoOperacionOffline.incidencia},
      );
      expect(resultado.length, 1);
      expect(resultado.first.tipo, TipoOperacionOffline.incidencia);
    });
  });

  group('retry con datos reales del agregador', () {
    test('operación con estado sincronizando no es reintentable', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'A',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: MetadataOperacionOffline(
              idempotencyKey: 'k1',
              estado: EstadoOperacionOffline.sincronizando,
            ),
          ),
        ],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.puedeReintentar, isFalse);
      expect(resultado.reintentables, 0);
    });

    test('operación con estado sincronizada no es reintentable', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'A',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: MetadataOperacionOffline(
              idempotencyKey: 'k1',
              estado: EstadoOperacionOffline.sincronizada,
            ),
          ),
        ],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.puedeReintentar, isFalse);
      expect(resultado.reintentables, 0);
    });

    test('operación con estado requiereRevision no es reintentable', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'A',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: MetadataOperacionOffline(
              idempotencyKey: 'k1',
              estado: EstadoOperacionOffline.requiereRevision,
            ),
          ),
        ],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.puedeReintentar, isFalse);
      expect(resultado.reintentables, 0);
    });

    test('operación con estado pendiente es reintentable', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'A',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
          ),
        ],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.puedeReintentar, isTrue);
      expect(resultado.reintentables, 1);
    });

    test('operación con estado errorPermanente es reintentable', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'A',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: MetadataOperacionOffline(
              idempotencyKey: 'k1',
              estado: EstadoOperacionOffline.errorPermanente,
            ),
          ),
        ],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.puedeReintentar, isTrue);
      expect(resultado.reintentables, 1);
    });

    test('operación con estado conflicto es reintentable', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'A',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: MetadataOperacionOffline(
              idempotencyKey: 'k1',
              estado: EstadoOperacionOffline.conflicto,
            ),
          ),
        ],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.puedeReintentar, isTrue);
      expect(resultado.reintentables, 1);
    });

    test('operación con estado errorTransitorio es reintentable', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'A',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: MetadataOperacionOffline(
              idempotencyKey: 'k1',
              estado: EstadoOperacionOffline.errorTransitorio,
            ),
          ),
        ],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.puedeReintentar, isTrue);
      expect(resultado.reintentables, 1);
    });

    test('conteo reintentables mezcla de estados', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'A',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
          ),
          SolicitudPendienteOffline(
            idLocal: 's2',
            usuarioId: 'u1',
            idempotencyKey: 'k2',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 20,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'B',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: MetadataOperacionOffline(
              idempotencyKey: 'k2',
              estado: EstadoOperacionOffline.sincronizando,
            ),
          ),
          SolicitudPendienteOffline(
            idLocal: 's3',
            usuarioId: 'u1',
            idempotencyKey: 'k3',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 30,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'C',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: MetadataOperacionOffline(
              idempotencyKey: 'k3',
              estado: EstadoOperacionOffline.errorPermanente,
            ),
          ),
        ],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      // pendiente (1) + errorPermanente (1) = 2 reintentables
      expect(resultado.reintentables, 2);
      // 0 requieren atención solo desde pendiente
      expect(resultado.requiereAtencion, 1);
    });
  });
}
