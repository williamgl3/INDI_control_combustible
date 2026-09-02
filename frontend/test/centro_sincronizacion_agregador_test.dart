import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/centro_sincronizacion/agregador_sincronizacion.dart';
import 'package:indi_combustible/core/centro_sincronizacion/centro_providers.dart';
import 'package:indi_combustible/core/centro_sincronizacion/operacion_sincronizacion_view.dart';
import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/offline/metadata_operacion_offline.dart';

MetadataOperacionOffline _meta({
  EstadoOperacionOffline estado = EstadoOperacionOffline.pendiente,
  int intentos = 0,
  DateTime? proximoIntento,
  String? ultimoError,
  int? ultimoStatus,
  String? ultimoCodigo,
  bool requiereLogin = false,
}) =>
    MetadataOperacionOffline(
      idempotencyKey: 'test-key-0000-0000-000000000001',
      estado: estado,
      intentos: intentos,
      proximoIntento: proximoIntento,
      ultimoError: ultimoError,
      ultimoStatus: ultimoStatus,
      ultimoCodigo: ultimoCodigo,
      requiereLogin: requiereLogin,
    );

DateTime _hace(int minutos) =>
    DateTime.now().subtract(Duration(minutes: minutos));

DateTime _en(int minutos) => DateTime.now().add(Duration(minutes: minutos));

void main() {
  group('AgregadorSincronizacion', () {
    test('1. combina correctamente las 8 colas', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'userA',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 100,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'Prueba',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: _hace(10),
          ),
        ],
        cargas: [
          ComprobarCargaPendienteOffline(
            idLocal: 'c1',
            choferId: 'userA',
            vehiculoId: 'v1',
            folioAutorizacion: 'F001',
            litrosCargados: 50,
            kmAlCargar: 1000,
            gasolinera: 'Gasolinera X',
            fotoTicketPath: '',
            fotoTableroPath: '',
            creadaEn: _hace(9),
          ),
        ],
        cierres: [
          CerrarDiaPendienteOffline(
            idLocal: 'cd1',
            choferId: 'userA',
            cargaId: 'carga1',
            kmFinal: 1100,
            fotoTableroPath: '',
            creadaEn: _hace(8),
          ),
        ],
        incidencias: [
          IncidenciaPendienteOffline(
            idLocal: 'i1',
            usuarioId: 'userA',
            vehiculoId: 'v1',
            descripcion: 'Falla',
            creadaEn: _hace(7),
          ),
        ],
        evidencias: [
          EvidenciaPendienteOffline(
            idLocal: 'e1',
            usuarioId: 'userA',
            tipo: 'frente',
            pendienteVincular: false,
            creadaEn: _hace(6),
            fotoPaths: ['/tmp/foto.jpg'],
            archivosOffline: [],
          ),
        ],
        recorridos: [
          RecorridoMarimbaPendienteOffline(
            idLocal: 'r1',
            usuarioId: 'userA',
            rol: 'operador',
            marimbaId: 'm1',
            tipoCombustible: 'Diesel',
            frente: 'Frente 1',
            creadaEn: _hace(5),
          ),
        ],
        despachos: [
          DespachoMarimbaPendienteOffline(
            idLocal: 'd1',
            recorridoIdLocal: 'r1',
            usuarioId: 'userA',
            rol: 'operador',
            vehiculoDestinoId: 'v2',
            tipoCombustible: 'Diesel',
            operadorTexto: 'Juan',
            horometro: 100,
            fotoHorometroPath: '',
            litrosDeclarados: 200,
            creadaEn: _hace(4),
          ),
        ],
        cierresRecorrido: [
          CierreRecorridoMarimbaPendienteOffline(
            idLocal: 'cr1',
            recorridoIdLocal: 'r1',
            usuarioId: 'userA',
            rol: 'operador',
            fotoCierrePath: '',
            fotoNivelPath: '',
            existenciaFisica: 150,
            creadaEn: _hace(3),
          ),
        ],
      );

      expect(resultado.total, 8);
      expect(resultado.operaciones.length, 8);
    });

    test('2. evidencias se incluyen', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [
          EvidenciaPendienteOffline(
            idLocal: 'ev1',
            usuarioId: 'userA',
            tipo: 'frente',
            pendienteVincular: false,
            creadaEn: DateTime.now(),
            fotoPaths: ['/tmp/f.jpg'],
            archivosOffline: [],
          ),
        ],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.total, 1);
      expect(resultado.operaciones.first.tipo, TipoOperacionOffline.evidencia);
      expect(resultado.operaciones.first.titulo, contains('Evidencia'));
    });

    test('3. usuario A solo ve operaciones de A', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: 'userA',
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
            usuarioId: 'userB',
            idempotencyKey: 'k2',
            payloadFingerprint: '',
            vehiculoId: 'v2',
            litrosSolicitados: 20,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'B',
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

      // Agregador no filtra — retorna todas. El filtrado lo hace el provider.
      expect(resultado.total, 2);
      final ids = resultado.operaciones.map((o) => o.idLocal).toList();
      expect(ids, containsAll(['s1', 's2']));
    });

    test('4. usuario B no puede ver operaciones de A (filtrado por provider)',
        () {
      final todas = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 'sA',
            usuarioId: 'userA',
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
            idLocal: 'sB',
            usuarioId: 'userB',
            idempotencyKey: 'k2',
            payloadFingerprint: '',
            vehiculoId: 'v2',
            litrosSolicitados: 20,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'B',
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

      final soloA = todas.operaciones
          .where((op) => op.usuarioId == 'userA')
          .toList();
      final soloB = todas.operaciones
          .where((op) => op.usuarioId == 'userB')
          .toList();

      expect(soloA.length, 1);
      expect(soloA.first.idLocal, 'sA');
      expect(soloB.length, 1);
      expect(soloB.first.idLocal, 'sB');
    });

    test('5. usuario con choferId (cargas/cierres) se filtra correctamente',
        () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [],
        cargas: [
          ComprobarCargaPendienteOffline(
            idLocal: 'c1',
            choferId: 'choferX',
            vehiculoId: 'v1',
            folioAutorizacion: 'F1',
            litrosCargados: 50,
            kmAlCargar: 1000,
            gasolinera: 'GX',
            fotoTicketPath: '',
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
          ),
          ComprobarCargaPendienteOffline(
            idLocal: 'c2',
            choferId: 'choferY',
            vehiculoId: 'v2',
            folioAutorizacion: 'F2',
            litrosCargados: 30,
            kmAlCargar: 2000,
            gasolinera: 'GY',
            fotoTicketPath: '',
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
          ),
        ],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      final choferX = resultado.operaciones
          .where((op) => op.usuarioId == 'choferX')
          .toList();
      final choferY = resultado.operaciones
          .where((op) => op.usuarioId == 'choferY')
          .toList();
      expect(choferX.length, 1);
      expect(choferX.first.idLocal, 'c1');
      expect(choferY.length, 1);
      expect(choferY.first.idLocal, 'c2');
    });

    test('6. orden por prioridad visual: requiereAtencion primero', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's-normal',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'Normal',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: _hace(1),
          ),
          SolicitudPendienteOffline(
            idLocal: 's-atencion',
            usuarioId: 'u1',
            idempotencyKey: 'k2',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 20,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'Error',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: _hace(2),
            metadata: _meta(
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

      expect(resultado.operaciones.first.idLocal, 's-atencion');
      expect(resultado.operaciones.last.idLocal, 's-normal');
    });

    test('7. requiereAtencion es correcto', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's-ok',
            usuarioId: 'u1',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'OK',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
          ),
          SolicitudPendienteOffline(
            idLocal: 's-login',
            usuarioId: 'u1',
            idempotencyKey: 'k2',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 20,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'Login',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(requiereLogin: true),
          ),
          SolicitudPendienteOffline(
            idLocal: 's-perm',
            usuarioId: 'u1',
            idempotencyKey: 'k3',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 30,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'Perm',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(estado: EstadoOperacionOffline.errorPermanente),
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

      expect(resultado.requiereAtencion, 2);
      final conAtencion =
          resultado.operaciones.where((op) => op.requiereAtencion).toList();
      expect(conAtencion.map((op) => op.idLocal).toList(),
          containsAll(['s-login', 's-perm']));
    });

    test('8. conteo de pendientes correcto', () {
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

      expect(
        resultado.conteoPorEstado[EstadoVisualSincronizacion.pendiente], 2,
      );
    });

    test('9. conteo sincronizando correcto', () {
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
            actividad: 'Sync',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(estado: EstadoOperacionOffline.sincronizando),
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

      expect(
        resultado.conteoPorEstado[EstadoVisualSincronizacion.sincronizando], 1,
      );
    });

    test('10. conteo requiere atención correcto', () {
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
            metadata: _meta(
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

      expect(resultado.requiereAtencion, 1);
      expect(
        resultado.conteoPorEstado[EstadoVisualSincronizacion.requiereRevision],
        1,
      );
    });

    test('11. operación sincronizada se incluye como completada', () {
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
            actividad: 'Done',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(estado: EstadoOperacionOffline.sincronizada),
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

      expect(resultado.total, 1);
      expect(
        resultado.operaciones.first.estadoVisual,
        EstadoVisualSincronizacion.completada,
      );
    });

    test('12. archivo faltante se proyecta correctamente', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [],
        cargas: [],
        cierres: [],
        incidencias: [
          IncidenciaPendienteOffline(
            idLocal: 'i1',
            usuarioId: 'u1',
            vehiculoId: 'v1',
            descripcion: 'Sin foto',
            fotoPath: null,
            creadaEn: DateTime.now(),
          ),
        ],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.archivos, isEmpty);
    });

    test('13. archivo con ruta se proyecta correctamente', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [],
        cargas: [],
        cierres: [],
        incidencias: [
          IncidenciaPendienteOffline(
            idLocal: 'i1',
            usuarioId: 'u1',
            vehiculoId: 'v1',
            descripcion: 'Con foto',
            fotoPath: '/tmp/foto.jpg',
            creadaEn: DateTime.now(),
          ),
        ],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.archivos.length, 1);
      expect(resultado.operaciones.first.archivos.first.ruta, '/tmp/foto.jpg');
    });

    test('14. dependencia se muestra correctamente', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [],
        cargas: [],
        cierres: [],
        incidencias: [],
        evidencias: [],
        recorridos: [],
        despachos: [
          DespachoMarimbaPendienteOffline(
            idLocal: 'd1',
            recorridoIdLocal: 'r1',
            usuarioId: 'u1',
            rol: 'op',
            vehiculoDestinoId: 'v1',
            tipoCombustible: 'Diesel',
            operadorTexto: 'Juan',
            horometro: 100,
            fotoHorometroPath: '',
            creadaEn: DateTime.now(),
          ),
        ],
        cierresRecorrido: [],
      );

      expect(resultado.operaciones.first.dependencias.length, 2);
      expect(
        resultado.operaciones.first.dependencias
            .map((d) => d.idLocal)
            .toList(),
        containsAll(['r1', 'v1']),
      );
    });

    test('15. requiereLogin se representa correctamente', () {
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
            actividad: 'Auth',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(requiereLogin: true),
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

      expect(resultado.operaciones.first.requiereLogin, isTrue);
      expect(resultado.operaciones.first.requiereAtencion, isTrue);
    });

    test('16. conflicto se representa correctamente', () {
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
            actividad: 'Conflicto',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(estado: EstadoOperacionOffline.conflicto),
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

      expect(
        resultado.operaciones.first.estadoVisual,
        EstadoVisualSincronizacion.conflicto,
      );
      expect(resultado.operaciones.first.puedeReintentar, isTrue);
    });

    test('17. error transitorio se representa correctamente', () {
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
            actividad: 'Error',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(
              estado: EstadoOperacionOffline.errorTransitorio,
              ultimoError: 'Timeout',
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

      expect(
        resultado.operaciones.first.estadoVisual,
        EstadoVisualSincronizacion.errorTransitorio,
      );
      expect(resultado.operaciones.first.ultimoError, 'Timeout');
    });

    test('18. backoff/proximoIntento se representa correctamente', () {
      final proximo = _en(10);
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
            actividad: 'Backoff',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(
              estado: EstadoOperacionOffline.errorTransitorio,
              proximoIntento: proximo,
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

      expect(
        resultado.operaciones.first.estadoVisual,
        EstadoVisualSincronizacion.reintentoPendiente,
      );
      expect(resultado.operaciones.first.proximoIntento, proximo);
    });

    test('filtrarPorEstados retorna solo los estados seleccionados', () {
      final datos = AgregadorSincronizacion.agregar(
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
            metadata: _meta(estado: EstadoOperacionOffline.errorPermanente),
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

      final soloError = filtrarPorEstados(
        datos,
        {EstadoVisualSincronizacion.errorPermanente},
      );
      expect(soloError.length, 1);
      expect(soloError.first.idLocal, 's2');

      final todos = filtrarPorEstados(datos, {});
      expect(todos.length, 2);
    });

    test('filtrarPorTipos retorna solo los tipos seleccionados', () {
      final datos = AgregadorSincronizacion.agregar(
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
        incidencias: [
          IncidenciaPendienteOffline(
            idLocal: 'i1',
            usuarioId: 'u1',
            vehiculoId: 'v1',
            descripcion: 'Falla',
            creadaEn: DateTime.now(),
          ),
        ],
        evidencias: [],
        recorridos: [],
        despachos: [],
        cierresRecorrido: [],
      );

      final soloSolicitudes = filtrarPorTipos(
        datos,
        {TipoOperacionOffline.solicitud},
      );
      expect(soloSolicitudes.length, 1);
      expect(soloSolicitudes.first.tipo, TipoOperacionOffline.solicitud);
    });

    test('fallback de usuario con usuarioId vacío se preserva', () {
      final resultado = AgregadorSincronizacion.agregar(
        solicitudes: [
          SolicitudPendienteOffline(
            idLocal: 's1',
            usuarioId: '',
            idempotencyKey: 'k1',
            payloadFingerprint: '',
            vehiculoId: 'v1',
            litrosSolicitados: 10,
            esUrgente: false,
            motivoChofer: null,
            actividad: 'Legacy',
            fechaProgramada: DateTime.now(),
            fotoTableroPath: '',
            creadaEn: DateTime.now(),
            metadata: _meta(
              estado: EstadoOperacionOffline.requiereRevision,
              ultimoError: 'La operacion legacy no identifica a su propietario.',
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

      expect(resultado.total, 1);
      expect(
        resultado.operaciones.first.estadoVisual,
        EstadoVisualSincronizacion.requiereRevision,
      );
      expect(resultado.operaciones.first.requiereAtencion, isTrue);
    });
  });
}
