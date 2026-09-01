import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/data/incidencias_repository.dart';
import 'package:indi_combustible/data/operaciones_repository.dart';
import 'package:indi_combustible/models/carga.dart';
import 'package:indi_combustible/models/incidencia_vehiculo.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/solicitud_autorizacion.dart';

import 'mocks/mock_operaciones_repository.dart';

class _IncidenciasContador extends IncidenciasRepository {
  int envios = 0;

  @override
  List<IncidenciaVehiculo> get misIncidencias => const [];

  @override
  List<IncidenciaVehiculo> get todasLasIncidencias => const [];

  @override
  Future<void> cargarMisIncidencias() async {}

  @override
  Future<void> cargarTodasLasIncidencias() async {}

  @override
  Future<IncidenciaVehiculo> reportar({
    required String vehiculoId,
    required String descripcion,
    String? fotoPath,
  }) async {
    envios++;
    throw StateError('No debe enviarse una incidencia sin su foto original.');
  }

  @override
  Future<IncidenciaVehiculo> resolver({
    required String id,
    String? comentario,
  }) => throw UnimplementedError();
}

class _OperacionesContador extends MockOperacionesRepository {
  final choferesEnviados = <String>[];

  @override
  Future<Carga> registrarCarga({
    required String choferId,
    required String vehiculoId,
    required String folioAutorizacion,
    List<String>? foliosAdicionales,
    required double litrosCargados,
    required double kmAlCargar,
    required String gasolinera,
    String? fotoTicketPath,
    String? fotoTableroPath,
    double? litrosDetectadosOcr,
    List<SolicitudPartida>? partidas,
    List<ComprobanteEstacionCarga>? comprobantes,
  }) async {
    choferesEnviados.add(choferId);
    return Carga(
      id: 'carga-${choferesEnviados.length}',
      choferId: choferId,
      vehiculoId: vehiculoId,
      folioAutorizacion: folioAutorizacion,
      foliosAdicionales: foliosAdicionales ?? const [],
      litrosCargados: litrosCargados,
      kmAlCargar: kmAlCargar,
      gasolinera: gasolinera,
      creadaEn: DateTime.utc(2026, 8, 25),
      fotoTicketPath: fotoTicketPath,
      fotoTableroPath: fotoTableroPath,
      litrosDetectadosOcr: litrosDetectadosOcr,
    );
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('incidencia con foto faltante se conserva y no se envia', (
    tester,
  ) async {
    final repo = _IncidenciasContador();
    final container = ProviderContainer(
      overrides: [incidenciasRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    _iniciar(container, 'usuario-a');
    final cola = container.read(colaIncidenciasOfflineProvider);
    await cola.agregar(
      IncidenciaPendienteOffline(
        idLocal: 'incidencia-local',
        usuarioId: 'usuario-a',
        vehiculoId: 'v1',
        descripcion: 'Falla',
        creadaEn: DateTime.utc(2026, 8, 25),
        fotoPath: '${Directory.systemTemp.path}/foto-inexistente-3a.jpg',
      ),
    );
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await sincronizarSolicitudesOffline(ref);

    final conservada = (await cola.leer()).single;
    expect(repo.envios, 0);
    expect(conservada.metadata.ultimoCodigo, 'ARCHIVO_OFFLINE_FALTANTE');
  });

  testWidgets('comprobar carga sincroniza solo al usuario actual', (
    tester,
  ) async {
    final repo = _OperacionesContador();
    final container = ProviderContainer(
      overrides: [operacionesRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    _iniciar(container, 'usuario-a');
    final ticket = File('${Directory.systemTemp.path}/ticket-3a.jpg')
      ..writeAsBytesSync([1]);
    final tablero = File('${Directory.systemTemp.path}/tablero-3a.jpg')
      ..writeAsBytesSync([2]);
    addTearDown(() {
      if (ticket.existsSync()) ticket.deleteSync();
      if (tablero.existsSync()) tablero.deleteSync();
    });
    final cola = container.read(colaComprobarCargaOfflineProvider);
    for (final usuario in ['usuario-a', 'usuario-b']) {
      await cola.agregar(
        ComprobarCargaPendienteOffline(
          idLocal: 'carga-$usuario',
          choferId: usuario,
          vehiculoId: 'vehiculo-ligero-1',
          folioAutorizacion: 'F-$usuario',
          litrosCargados: 10,
          kmAlCargar: 20,
          gasolinera: 'Estacion',
          fotoTicketPath: ticket.path,
          fotoTableroPath: tablero.path,
          creadaEn: DateTime.utc(2026, 8, 25),
        ),
      );
    }
    late WidgetRef ref;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (_, widgetRef, _) {
            ref = widgetRef;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    await sincronizarSolicitudesOffline(ref);

    expect(repo.choferesEnviados, ['usuario-a']);
    expect((await cola.leer()).single.choferId, 'usuario-b');
  });

  testWidgets('total pendiente cuenta solamente al usuario actual', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    _iniciar(container, 'usuario-a');
    final cola = container.read(colaIncidenciasOfflineProvider);
    for (final usuario in ['usuario-a', 'usuario-b']) {
      await cola.agregar(
        IncidenciaPendienteOffline(
          idLocal: 'incidencia-$usuario',
          usuarioId: usuario,
          vehiculoId: 'v1',
          descripcion: 'Falla',
          creadaEn: DateTime.utc(2026, 8, 25),
        ),
      );
    }

    expect(await container.read(totalPendientesOfflineProvider.future), 1);
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
