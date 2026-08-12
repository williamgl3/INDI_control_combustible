import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/data/recorridos_marimba_repository.dart';
import 'package:indi_combustible/models/despacho_marimba.dart';
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
    String? cargaId,
    required double litrosIniciales,
    double? kmInicio,
    double? horasEquipoMenorInicio,
  }) async {
    llamadas.add('abrir:$frente');
    return RecorridoMarimba(
      id: 'servidor-recorrido-${_contadorId++}',
      marimbaId: marimbaId,
      operadorId: 'op-1',
      frente: frente,
      litrosIniciales: litrosIniciales,
      kmInicio: kmInicio,
      horasEquipoMenorInicio: horasEquipoMenorInicio,
      iniciadoEn: DateTime(2026, 1, 1),
    );
  }

  @override
  Future<DespachoMarimba> agregarDespacho({
    required String recorridoId,
    required String tipoCombustible,
    String? vehiculoDestinoId,
    String? destinoTexto,
    required String operadorTexto,
    String? residenteTexto,
    double? litrosSolicitados,
    required double litrosSuministrados,
    double? lecturaMedidor,
    String? fotoEvidenciaPath,
  }) async {
    llamadas.add('despacho:$recorridoId:$destinoTexto');
    return DespachoMarimba(
      id: 'servidor-despacho-${_contadorId++}',
      marimbaId: 'marimba-1',
      operadorTexto: operadorTexto,
      litrosSuministrados: litrosSuministrados,
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
    double? existenciaFisica,
    String? fotoNivelPath,
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

      const recorridoIdLocal = 'local-recorrido-1';

      // Pre-siembra las 3 colas directamente (sin pasar por una pantalla
      // que todavía no existe) — igual que si el operador hubiera abierto
      // el recorrido, agregado 2 despachos y cerrado, todo sin señal.
      await container
          .read(colaRecorridosMarimbaOfflineProvider)
          .agregar(
            RecorridoMarimbaPendienteOffline(
              idLocal: recorridoIdLocal,
              marimbaId: 'marimba-1',
              tipoCombustible: 'Diésel',
              frente: 'BANCO EL HUIZACHITO',
              litrosIniciales: 3000,
              creadaEn: DateTime(2026, 1, 1),
            ),
          );
      await container
          .read(colaDespachosMarimbaOfflineProvider)
          .agregar(
            DespachoMarimbaPendienteOffline(
              idLocal: 'local-despacho-1',
              recorridoIdLocal: recorridoIdLocal,
              destinoTexto: 'Excavadora 336-01',
              operadorTexto: 'Juan Perez',
              litrosSuministrados: 1500,
              creadaEn: DateTime(2026, 1, 1),
            ),
          );
      await container
          .read(colaDespachosMarimbaOfflineProvider)
          .agregar(
            DespachoMarimbaPendienteOffline(
              idLocal: 'local-despacho-2',
              recorridoIdLocal: recorridoIdLocal,
              destinoTexto: 'Excavadora 336-02',
              operadorTexto: 'Luis Ramirez',
              litrosSuministrados: 1450,
              creadaEn: DateTime(2026, 1, 1),
            ),
          );
      await container
          .read(colaCierresRecorridoMarimbaOfflineProvider)
          .agregar(
            CierreRecorridoMarimbaPendienteOffline(
              idLocal: 'local-cierre-1',
              recorridoIdLocal: recorridoIdLocal,
              // Ruta falsa a propósito: `sincronizarSolicitudesOffline`
              // descarta un pendiente si su foto ya no existe en disco.
              // Se usa un archivo real y vacío como sustituto, mismo
              // patrón que `FakeFotoPicker` en `test_helpers.dart`.
              fotoCierrePath: _crearArchivoTemporalFalso(),
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
}

/// Síncrono a propósito — igual que `FakeFotoPicker` en `test_helpers.dart`:
/// una escritura real (`await ...writeAsBytes`) no se resuelve dentro de la
/// zona fake-async de `flutter_test` y cuelga la prueba indefinidamente.
String _crearArchivoTemporalFalso() {
  final directorio = Directory.systemTemp.createTempSync('marimba_test');
  final archivo = File('${directorio.path}/cierre.jpg');
  archivo.writeAsBytesSync([0]);
  return archivo.path;
}
