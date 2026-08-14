import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/data/recorridos_marimba_repository.dart';
import 'package:indi_combustible/models/despacho_marimba.dart';
import 'package:indi_combustible/models/panel_marimba.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/recorrido_marimba.dart';

class _Repo implements RecorridosMarimbaRepository {
  int resumenConsultas = 0;
  int historialConsultas = 0;
  Completer<List<ResumenUnidadMarimba>>? resumenPendiente;
  List<Completer<List<ResumenUnidadMarimba>>> resumenesPendientes = [];
  Object? errorResumen;
  Object? errorHistorial;

  @override
  Future<List<ResumenUnidadMarimba>> listarResumenUnidades() async {
    resumenConsultas++;
    if (errorResumen case final error?) throw error;
    if (resumenesPendientes.isNotEmpty) {
      return resumenesPendientes.removeAt(0).future;
    }
    return resumenPendiente?.future ?? [_unidad];
  }

  @override
  Future<PaginaRecorridosMarimba> listarRecorridosAdministrativos(
    FiltrosRecorridosMarimba filtros,
  ) async {
    historialConsultas++;
    if (errorHistorial case final error?) throw error;
    return PaginaRecorridosMarimba(
      items: [_recorrido],
      total: 1,
      page: filtros.page,
      limit: filtros.limit,
      totalPages: 1,
    );
  }

  @override
  Future<RecorridoMarimba?> buscarRecorrido(String id) async => _recorrido;
  @override
  Future<List<DespachoMarimba>> listarDespachosDeRecorrido(String id) async =>
      [];
  @override
  Future<List<RecorridoMarimba>> listarRecorridos({
    String? marimbaId,
    bool? requiereRevision,
  }) async => [];
  @override
  Future<double> saldoDeMarimba(String id, String combustible) async => 0;
  @override
  Future<RecorridoMarimba> abrirRecorrido({
    required String marimbaId,
    required String tipoCombustible,
    required String frente,
    double? kmInicio,
    double? horasEquipoMenorInicio,
  }) => throw UnimplementedError();
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
  }) => throw UnimplementedError();
  @override
  Future<RecorridoMarimba> cerrarRecorrido({
    required String recorridoId,
    double? kmCierre,
    double? horasEquipoMenorCierre,
    required String fotoCierrePath,
    required double existenciaFisica,
    required String fotoNivelPath,
    String? observaciones,
  }) => throw UnimplementedError();
}

const _unidad = ResumenUnidadMarimba(
  id: 'm',
  tipoUnidad: 'Marimba',
  activo: true,
  saldoMagna: '0',
  saldoDiesel: null,
  requiereRevision: false,
);
final _recorrido = RecorridoMarimba(
  id: 'r',
  marimbaId: 'm',
  operadorId: 'u',
  frente: 'Norte',
  litrosIniciales: 100,
  iniciadoEn: DateTime.utc(2026),
);
Perfil _perfil(String id) => Perfil(
  id: id,
  usuario: id,
  nombre: 'Administración',
  correo: '$id@example.com',
  rol: RolUsuario.administrativo,
);

ProviderContainer _container(_Repo repo) {
  final container = ProviderContainer(
    overrides: [recorridosMarimbaRepositoryProvider.overrideWithValue(repo)],
  );
  container.read(sessionProvider.notifier).iniciarSesion(_perfil('admin-1'));
  return container;
}

void main() {
  test(
    'dos consumidores comparten la consulta y las fuentes son independientes',
    () async {
      final repo = _Repo();
      final container = _container(repo);
      addTearDown(container.dispose);
      final a = container.read(resumenUnidadesMarimbaProvider.future);
      final b = container.read(resumenUnidadesMarimbaProvider.future);
      final historial = await container.read(
        recorridosAdministrativosMarimbaProvider(
          const FiltrosRecorridosMarimba(),
        ).future,
      );
      expect(await Future.wait([a, b]), hasLength(2));
      expect(repo.resumenConsultas, 1);
      expect(repo.historialConsultas, 1);
      expect(historial.items, hasLength(1));
      container.invalidate(resumenUnidadesMarimbaProvider);
      await container.read(resumenUnidadesMarimbaProvider.future);
      expect(repo.resumenConsultas, 2);
      expect(repo.historialConsultas, 1);
    },
  );

  test('un error del resumen no elimina un historial válido', () async {
    final repo = _Repo()..errorResumen = StateError('inventario');
    final container = _container(repo);
    addTearDown(container.dispose);
    await expectLater(
      container.read(resumenUnidadesMarimbaProvider.future),
      throwsStateError,
    );
    expect(
      (await container.read(
        recorridosAdministrativosMarimbaProvider(
          const FiltrosRecorridosMarimba(),
        ).future,
      )).items,
      hasLength(1),
    );
  });

  test('un error del historial no elimina un resumen válido', () async {
    final repo = _Repo()..errorHistorial = StateError('historial');
    final container = _container(repo);
    addTearDown(container.dispose);
    expect(
      await container.read(resumenUnidadesMarimbaProvider.future),
      hasLength(1),
    );
    await expectLater(
      container.read(
        recorridosAdministrativosMarimbaProvider(
          const FiltrosRecorridosMarimba(),
        ).future,
      ),
      throwsStateError,
    );
  });

  test(
    'cerrar o cambiar sesión impide publicar una respuesta anterior',
    () async {
      final respuestaAnterior = Completer<List<ResumenUnidadMarimba>>();
      final respuestaNueva = Completer<List<ResumenUnidadMarimba>>();
      const unidadAnterior = ResumenUnidadMarimba(
        id: 'anterior',
        tipoUnidad: 'Marimba',
        activo: true,
        requiereRevision: false,
      );
      const unidadNueva = ResumenUnidadMarimba(
        id: 'nueva',
        tipoUnidad: 'Pipa',
        activo: true,
        requiereRevision: false,
      );
      final repo = _Repo()
        ..resumenesPendientes = [respuestaAnterior, respuestaNueva];
      final container = _container(repo);
      addTearDown(container.dispose);
      container.listen(resumenUnidadesMarimbaProvider, (_, _) {});
      container.read(resumenUnidadesMarimbaProvider.future);
      expect(repo.resumenConsultas, 1);
      container.read(sessionProvider.notifier).cerrarSesion();
      container
          .read(sessionProvider.notifier)
          .iniciarSesion(_perfil('admin-2'));
      final nuevaCarga = container.read(resumenUnidadesMarimbaProvider.future);
      expect(repo.resumenConsultas, 2);

      respuestaAnterior.complete([unidadAnterior]);
      await respuestaAnterior.future;
      respuestaNueva.complete([unidadNueva]);

      expect(await nuevaCarga, [unidadNueva]);
      expect(container.read(resumenUnidadesMarimbaProvider).valueOrNull, [
        unidadNueva,
      ]);
      expect(
        container.read(resumenUnidadesMarimbaProvider).valueOrNull,
        isNot(contains(unidadAnterior)),
      );
    },
  );
}
