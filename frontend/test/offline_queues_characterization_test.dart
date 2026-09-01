import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/cola_solicitudes_offline.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('las ocho colas persisten y eliminan por idLocal', () async {
    final ahora = DateTime.utc(2026, 8, 25, 12);
    final solicitud = SolicitudPendienteOffline(
      idLocal: 'solicitud-local',
      usuarioId: 'usuario-1',
      idempotencyKey: '00000000-0000-4000-8000-000000000001',
      payloadFingerprint: 'a' * 64,
      vehiculoId: 'vehiculo-1',
      litrosSolicitados: 20,
      esUrgente: false,
      motivoChofer: null,
      actividad: 'Trabajo',
      fechaProgramada: ahora,
      fotoTableroPath: 'tablero.jpg',
      creadaEn: ahora,
    );
    final carga = ComprobarCargaPendienteOffline(
      idLocal: 'offline-1',
      choferId: 'usuario-1',
      vehiculoId: 'vehiculo-1',
      folioAutorizacion: 'F-1',
      litrosCargados: 20,
      kmAlCargar: 100,
      gasolinera: 'Estacion',
      fotoTicketPath: 'ticket.jpg',
      fotoTableroPath: 'tablero.jpg',
      creadaEn: ahora,
    );
    final cierre = CerrarDiaPendienteOffline(
      idLocal: 'offline-2',
      choferId: 'usuario-1',
      cargaId: 'carga-1',
      kmFinal: 120,
      fotoTableroPath: 'final.jpg',
      creadaEn: ahora,
    );
    final incidencia = IncidenciaPendienteOffline(
      idLocal: 'offline-3',
      usuarioId: 'usuario-1',
      vehiculoId: 'vehiculo-1',
      descripcion: 'Falla',
      creadaEn: ahora,
      fotoPath: 'falla.jpg',
    );
    final recorrido = RecorridoMarimbaPendienteOffline(
      idLocal: 'recorrido-1',
      usuarioId: 'usuario-1',
      rol: 'supervisor',
      marimbaId: 'marimba-1',
      tipoCombustible: 'diesel',
      frente: 'Norte',
      creadaEn: ahora,
    );
    final despacho = DespachoMarimbaPendienteOffline(
      idLocal: 'despacho-1',
      recorridoIdLocal: recorrido.idLocal,
      usuarioId: 'usuario-1',
      rol: 'supervisor',
      vehiculoDestinoId: 'destino-1',
      tipoCombustible: 'diesel',
      operadorTexto: 'Operador',
      horometro: 12,
      fotoHorometroPath: 'horometro.jpg',
      creadaEn: ahora,
    );
    final cierreRecorrido = CierreRecorridoMarimbaPendienteOffline(
      idLocal: 'cierre-1',
      recorridoIdLocal: recorrido.idLocal,
      usuarioId: 'usuario-1',
      rol: 'supervisor',
      fotoCierrePath: 'cierre.jpg',
      fotoNivelPath: 'nivel.jpg',
      existenciaFisica: 10,
      creadaEn: ahora,
    );

    final colaSolicitud = ColaSolicitudesOffline();
    final colaCarga = ColaComprobarCargaOffline();
    final colaCierre = ColaCerrarDiaOffline();
    final colaIncidencia = ColaIncidenciasOffline();
    final colaEvidencia = ColaEvidenciasOffline();
    final colaRecorrido = ColaRecorridosMarimbaOffline();
    final colaDespacho = ColaDespachosMarimbaOffline();
    final colaCierreRecorrido = ColaCierresRecorridoMarimbaOffline();

    expect(await colaSolicitud.agregar(solicitud), isTrue);
    await colaCarga.agregar(carga);
    await colaCierre.agregar(cierre);
    await colaIncidencia.agregar(incidencia);
    await colaEvidencia.agregar(
      EvidenciaPendienteOffline(
        idLocal: 'evidencia-local',
        usuarioId: 'usuario-1',
        tipo: 'comprobante',
        pendienteVincular: false,
        creadaEn: ahora,
        fotoPaths: [],
        archivosOffline: [],
      ),
    );
    await colaRecorrido.agregar(recorrido);
    await colaDespacho.agregar(despacho);
    await colaCierreRecorrido.agregar(cierreRecorrido);

    expect((await colaSolicitud.leer()).single.idLocal, solicitud.idLocal);
    expect((await colaCarga.leer()).single.idLocal, carga.idLocal);
    expect((await colaCierre.leer()).single.idLocal, cierre.idLocal);
    expect((await colaIncidencia.leer()).single.idLocal, incidencia.idLocal);
    expect(
      (await colaEvidencia.leer()).single.idLocal,
      'evidencia-local',
    );
    expect((await colaRecorrido.leer()).single.idLocal, recorrido.idLocal);
    expect((await colaDespacho.leer()).single.idLocal, despacho.idLocal);
    expect(
      (await colaCierreRecorrido.leer()).single.idLocal,
      cierreRecorrido.idLocal,
    );

    await colaSolicitud.quitar(solicitud.idLocal);
    await colaCarga.quitar(carga.idLocal);
    await colaCierre.quitar(cierre.idLocal);
    await colaIncidencia.quitar(incidencia.idLocal);
    await colaEvidencia.quitar('evidencia-local');
    await colaRecorrido.quitar(recorrido.idLocal);
    await colaDespacho.quitar(despacho.idLocal);
    await colaCierreRecorrido.quitar(cierreRecorrido.idLocal);

    expect(await colaSolicitud.leer(), isEmpty);
    expect(await colaCarga.leer(), isEmpty);
    expect(await colaCierre.leer(), isEmpty);
    expect(await colaIncidencia.leer(), isEmpty);
    expect(await colaEvidencia.leer(), isEmpty);
    expect(await colaRecorrido.leer(), isEmpty);
    expect(await colaDespacho.leer(), isEmpty);
    expect(await colaCierreRecorrido.leer(), isEmpty);
  });

  test('round-trip actual conserva payload, IDs y errores Marimba', () {
    final ahora = DateTime.utc(2026, 8, 25, 12);
    final pendiente = DespachoMarimbaPendienteOffline(
      idLocal: 'despacho-123',
      recorridoIdLocal: 'recorrido-123',
      usuarioId: 'usuario-1',
      rol: 'supervisor',
      vehiculoDestinoId: 'destino-1',
      tipoCombustible: 'diesel',
      operadorTexto: 'Operador',
      horometro: 123.5,
      fotoHorometroPath: 'horometro.jpg',
      litrosDeclarados: 30.25,
      ubicacion: 'Frente A',
      creadaEn: ahora,
    ).conError('HTTP 503');

    final restaurada = DespachoMarimbaPendienteOffline.fromJson(
      pendiente.toJson(),
    );

    expect(restaurada.idLocal, 'despacho-123');
    expect(restaurada.recorridoIdLocal, 'recorrido-123');
    expect(restaurada.creadaEn, ahora);
    expect(restaurada.litrosDeclarados, 30.25);
    expect(restaurada.intentos, 1);
    expect(restaurada.ultimoError, 'HTTP 503');
  });
}
