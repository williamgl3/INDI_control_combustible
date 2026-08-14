import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/data/recorridos_marimba_repository.dart';
import 'package:indi_combustible/models/despacho_marimba.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/panel_marimba.dart';
import 'package:indi_combustible/models/recorrido_marimba.dart';

/// Fake en memoria — registra el orden real de las llamadas, para
/// comprobar que el sincronizador respeta la dependencia recorrido →
/// despachos → cierre en vez de mandarlos en cualquier orden.
class _FakeRecorridosMarimbaRepository implements RecorridosMarimbaRepository {
  final llamadas = <String>[];
  int _contadorId = 0;

  @override
  Future<RecorridoMarimba> abrirRecorrido({
    required String marimbaId,
    required String tipoCombustible,
    required String frente,
    double? kmInicio,
    double? horasEquipoMenorInicio,
  }) async {
    llamadas.add('abrir:$frente');
    return RecorridoMarimba(
      id: 'servidor-recorrido-${_contadorId++}',
      marimbaId: marimbaId,
      operadorId: 'op-1',
      frente: frente,
      litrosIniciales: 3000,
      kmInicio: kmInicio,
      horasEquipoMenorInicio: horasEquipoMenorInicio,
      iniciadoEn: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<double> saldoDeMarimba(
    String marimbaId,
    String tipoCombustible,
  ) async => 3000;

  @override
  Future<DespachoMarimba> agregarDespacho({
    required String recorridoId,
    required String tipoCombustible,
    required String vehiculoDestinoId,
    required String operadorTexto,
    required double horometro,
    required String fotoHorometroPath,
    double? litrosDeclarados,
    double? medidorInicial,
    double? medidorFinal,
    String? fotoMedidorPath,
    String? fotoEvidenciaPath,
    String? ubicacion,
    String? observaciones,
  }) async {
    llamadas.add('despacho:$recorridoId:$vehiculoDestinoId');
    return DespachoMarimba(
      id: 'servidor-despacho-${_contadorId++}',
      marimbaId: 'marimba-1',
      operadorTexto: operadorTexto,
      litrosSuministrados:
          litrosDeclarados ?? (medidorFinal! - medidorInicial!),
      registradoPor: 'op-1',
      creadoEn: DateTime(2026, 1, 1),
      recorridoId: recorridoId,
    );
  }

  @override
  Future<RecorridoMarimba> cerrarRecorrido({
    required String recorridoId,
    double? kmCierre,
    double? horasEquipoMenorCierre,
    required String fotoCierrePath,
    required double existenciaFisica,
    required String fotoNivelPath,
    String? observaciones,
  }) async {
    llamadas.add('cerrar:$recorridoId');
    return RecorridoMarimba(
      id: recorridoId,
      marimbaId: 'marimba-1',
      operadorId: 'op-1',
      frente: 'BANCO EL HUIZACHITO',
      litrosIniciales: 3000,
      estado: EstadoRecorridoMarimba.cerrado,
      iniciadoEn: DateTime(2026, 1, 1),
      cerradoEn: DateTime(2026, 1, 1, 6),
    );
  }

  @override
  Future<RecorridoMarimba?> buscarRecorrido(String id) async => null;

  @override
  Future<List<DespachoMarimba>> listarDespachosDeRecorrido(
    String recorridoId,
  ) async => [];

  @override
  Future<List<RecorridoMarimba>> listarRecorridos({
    String? marimbaId,
    bool? requiereRevision,
  }) async => [];

  @override
  Future<List<ResumenUnidadMarimba>> listarResumenUnidades() async => [];

  @override
  Future<PaginaRecorridosMarimba> listarRecorridosAdministrativos(
    FiltrosRecorridosMarimba filtros,
  ) async => const PaginaRecorridosMarimba(
    items: [],
    total: 0,
    page: 1,
    limit: 25,
    totalPages: 0,
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'un recorrido con 2 despachos y un cierre, todos creados sin conexión, '
    'se sincronizan en el orden correcto: recorrido → despachos → cierre',
    (tester) async {
      final fake = _FakeRecorridosMarimbaRepository();
      final container = ProviderContainer(
        overrides: [
          recorridosMarimbaRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .iniciarSesion(
            const Perfil(
              id: 'supervisor-recorrido-1',
              usuario: 'supervisor_recorrido',
              nombre: 'Supervisor de recorrido',
              correo: 'supervisor.recorrido@example.com',
              rol: RolUsuario.supervisor,
            ),
          );

      const recorridoIdLocal = 'local-recorrido-1';
      final fotoHorometro = _crearArchivoTemporalFalso('horometro');
      final fotoEvidencia = _crearArchivoTemporalFalso('evidencia');
      final fotoCierre = _crearArchivoTemporalFalso('cierre');
      final fotoNivel = _crearArchivoTemporalFalso('nivel');

      // Pre-siembra las 3 colas directamente (sin pasar por una pantalla
      // que todavía no existe) — igual que si el operador hubiera abierto
      // el recorrido, agregado 2 despachos y cerrado, todo sin señal.
      await container
          .read(colaRecorridosMarimbaOfflineProvider)
          .agregar(
            RecorridoMarimbaPendienteOffline(
              idLocal: recorridoIdLocal,
              usuarioId: 'supervisor-recorrido-1',
              rol: 'supervisor',
              marimbaId: 'marimba-1',
              tipoCombustible: 'Diésel',
              frente: 'BANCO EL HUIZACHITO',
              creadaEn: DateTime(2026, 1, 1),
            ),
          );
      await container
          .read(colaDespachosMarimbaOfflineProvider)
          .agregar(
            DespachoMarimbaPendienteOffline(
              idLocal: 'local-despacho-1',
              recorridoIdLocal: recorridoIdLocal,
              usuarioId: 'supervisor-recorrido-1',
              rol: 'supervisor',
              vehiculoDestinoId: 'Excavadora 336-01',
              tipoCombustible: 'Diésel',
              operadorTexto: 'Juan Perez',
              horometro: 100,
              fotoHorometroPath: fotoHorometro,
              litrosDeclarados: 1500,
              fotoEvidenciaPath: fotoEvidencia,
              creadaEn: DateTime(2026, 1, 1),
            ),
          );
      await container
          .read(colaDespachosMarimbaOfflineProvider)
          .agregar(
            DespachoMarimbaPendienteOffline(
              idLocal: 'local-despacho-2',
              recorridoIdLocal: recorridoIdLocal,
              usuarioId: 'supervisor-recorrido-1',
              rol: 'supervisor',
              vehiculoDestinoId: 'Excavadora 336-02',
              tipoCombustible: 'Diésel',
              operadorTexto: 'Luis Ramirez',
              horometro: 200,
              fotoHorometroPath: fotoHorometro,
              litrosDeclarados: 1450,
              fotoEvidenciaPath: fotoEvidencia,
              creadaEn: DateTime(2026, 1, 1),
            ),
          );
      await container
          .read(colaCierresRecorridoMarimbaOfflineProvider)
          .agregar(
            CierreRecorridoMarimbaPendienteOffline(
              idLocal: 'local-cierre-1',
              recorridoIdLocal: recorridoIdLocal,
              usuarioId: 'supervisor-recorrido-1',
              rol: 'supervisor',
              // Ruta falsa a propósito: `sincronizarSolicitudesOffline`
              // descarta un pendiente si su foto ya no existe en disco.
              // Se usa un archivo real y vacío como sustituto, mismo
              // patrón que `FakeFotoPicker` en `test_helpers.dart`.
              fotoCierrePath: fotoCierre,
              fotoNivelPath: fotoNivel,
              existenciaFisica: 50,
              creadaEn: DateTime(2026, 1, 1),
            ),
          );

      late WidgetRef refCapturado;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              refCapturado = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await sincronizarSolicitudesOffline(refCapturado);
      await sincronizarSolicitudesOffline(refCapturado);

      expect(fake.llamadas, [
        'abrir:BANCO EL HUIZACHITO',
        'despacho:servidor-recorrido-0:Excavadora 336-01',
        'despacho:servidor-recorrido-0:Excavadora 336-02',
        'cerrar:servidor-recorrido-0',
      ]);

      expect(
        await container.read(colaRecorridosMarimbaOfflineProvider).leer(),
        isEmpty,
      );
      expect(
        await container.read(colaDespachosMarimbaOfflineProvider).leer(),
        isEmpty,
      );
      expect(
        await container.read(colaCierresRecorridoMarimbaOfflineProvider).leer(),
        isEmpty,
      );
    },
  );

  testWidgets(
    'una evidencia ausente conserva el despacho y bloquea el cierre',
    (tester) async {
      final fake = _FakeRecorridosMarimbaRepository();
      final container = ProviderContainer(
        overrides: [
          recorridosMarimbaRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .iniciarSesion(
            const Perfil(
              id: 'supervisor-recorrido-1',
              usuario: 'supervisor_recorrido',
              nombre: 'Supervisor de recorrido',
              correo: 'supervisor.recorrido@example.com',
              rol: RolUsuario.supervisor,
            ),
          );

      await container
          .read(colaRecorridosMarimbaOfflineProvider)
          .agregar(
            RecorridoMarimbaPendienteOffline(
              idLocal: 'local-recorrido-error',
              idServidor: 'recorrido-servidor',
              usuarioId: 'supervisor-recorrido-1',
              rol: 'supervisor',
              marimbaId: 'marimba-1',
              tipoCombustible: 'Magna',
              frente: 'Frente de prueba',
              creadaEn: DateTime(2026, 1, 1),
            ),
          );
      await container
          .read(colaDespachosMarimbaOfflineProvider)
          .agregar(
            DespachoMarimbaPendienteOffline(
              idLocal: 'despacho-sin-archivo',
              recorridoIdLocal: 'local-recorrido-error',
              usuarioId: 'supervisor-recorrido-1',
              rol: 'supervisor',
              vehiculoDestinoId: 'maquinaria-1',
              tipoCombustible: 'Magna',
              operadorTexto: 'Operador',
              horometro: 10,
              fotoHorometroPath: 'archivo-que-no-existe.jpg',
              litrosDeclarados: 20,
              fotoEvidenciaPath: 'otra-evidencia-ausente.jpg',
              creadaEn: DateTime(2026, 1, 1),
            ),
          );
      await container
          .read(colaCierresRecorridoMarimbaOfflineProvider)
          .agregar(
            CierreRecorridoMarimbaPendienteOffline(
              idLocal: 'cierre-bloqueado',
              recorridoIdLocal: 'local-recorrido-error',
              usuarioId: 'supervisor-recorrido-1',
              rol: 'supervisor',
              fotoCierrePath: _crearArchivoTemporalFalso('cierre-bloqueado'),
              fotoNivelPath: _crearArchivoTemporalFalso('nivel-bloqueado'),
              existenciaFisica: 20,
              creadaEn: DateTime(2026, 1, 1),
            ),
          );

      late WidgetRef refCapturado;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              refCapturado = ref;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      await sincronizarSolicitudesOffline(refCapturado);

      final despachos = await container
          .read(colaDespachosMarimbaOfflineProvider)
          .leer();
      expect(despachos, hasLength(1));
      expect(despachos.single.intentos, 1);
      expect(despachos.single.ultimoError, contains('evidencia'));
      expect(
        await container.read(colaCierresRecorridoMarimbaOfflineProvider).leer(),
        hasLength(1),
      );
      expect(fake.llamadas, isEmpty);
    },
  );
}

/// Síncrono a propósito — igual que `FakeFotoPicker` en `test_helpers.dart`:
/// una escritura real (`await ...writeAsBytes`) no se resuelve dentro de la
/// zona fake-async de `flutter_test` y cuelga la prueba indefinidamente.
String _crearArchivoTemporalFalso(String nombre) {
  final directorio = Directory.systemTemp.createTempSync('marimba_test');
  final archivo = File('${directorio.path}/$nombre.jpg');
  archivo.writeAsBytesSync([0]);
  return archivo.path;
}
