import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/estadistica_carga_provider.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/carga.dart';
import 'package:indi_combustible/models/cierre_dia.dart';
import 'package:indi_combustible/models/estadistica_carga_dia.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/screens/chofer/estadisticas_carga_screen.dart';
import 'package:indi_combustible/theme/app_theme.dart';

import 'mocks/mock_auditoria_repository.dart';
import 'mocks/mock_auth_repository.dart';
import 'mocks/mock_evidencias_repository.dart';
import 'mocks/mock_incidencias_repository.dart';
import 'mocks/mock_operaciones_repository.dart';
import 'mocks/mock_vehiculos_repository.dart';
import 'test_helpers.dart';

class _Sesion extends SessionController {
  _Sesion(this._perfil);
  final Perfil? _perfil;
  @override
  Perfil? build() => _perfil;
}

// ---------------------------------------------------------------------------
// Model tests
// ---------------------------------------------------------------------------
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('EstadisticaCargaDia', () {
    test('desdeRegistros con datos válidos calcula métricas', () {
      final ahora = DateTime.now();
      final carga1 = Carga(
        id: 'c1',
        choferId: 'u1',
        vehiculoId: 'v1',
        folioAutorizacion: 'FA-1',
        litrosCargados: 40,
        kmAlCargar: 1000,
        gasolinera: 'PEMEX',
        creadaEn: ahora,
      );
      final carga2 = Carga(
        id: 'c2',
        choferId: 'u1',
        vehiculoId: 'v1',
        folioAutorizacion: 'FA-2',
        litrosCargados: 30,
        kmAlCargar: 1200,
        gasolinera: 'BP',
        creadaEn: ahora.add(const Duration(hours: 2)),
      );
      final cierre = CierreDia(
        id: 'ci1',
        choferId: 'u1',
        cargaId: 'c1',
        kmFinal: 1380,
        fotoTableroPath: '/tmp/f.jpg',
        registradaEn: ahora.add(const Duration(hours: 6)),
      );

      final stats = EstadisticaCargaDia.desdeRegistros(
        vehiculoId: 'v1',
        fecha: ahora,
        cargas: [carga1, carga2],
        cierres: [cierre],
      );

      expect(stats.totalCargas, 2);
      expect(stats.litrosTotales, 70);
      expect(stats.kmRecorridos, 380); // 1380 - 1000
      expect(stats.rendimiento, closeTo(5.43, 0.01)); // 380 / 70
      expect(stats.esAnomalo, isFalse);
    });

    test('desdeRegistros sin cierres deja rendimiento null', () {
      final carga = Carga(
        id: 'c1',
        choferId: 'u1',
        vehiculoId: 'v1',
        folioAutorizacion: 'FA-1',
        litrosCargados: 40,
        kmAlCargar: 1000,
        gasolinera: 'PEMEX',
        creadaEn: DateTime.now(),
      );

      final stats = EstadisticaCargaDia.desdeRegistros(
        vehiculoId: 'v1',
        fecha: DateTime.now(),
        cargas: [carga],
        cierres: const [],
      );

      expect(stats.totalCargas, 1);
      expect(stats.kmRecorridos, isNull);
      expect(stats.rendimiento, isNull);
    });

    test('desdeRegistros vacío tiene isEmpty true', () {
      final stats = EstadisticaCargaDia.desdeRegistros(
        vehiculoId: '',
        fecha: DateTime.now(),
        cargas: const [],
        cierres: const [],
      );

      expect(stats.isEmpty, isTrue);
      expect(stats.totalCargas, 0);
      expect(stats.litrosTotales, 0);
    });

    test('marca esAnomalo cuando rendimiento < 2 km/L', () {
      final ahora = DateTime.now();
      final carga = Carga(
        id: 'c1',
        choferId: 'u1',
        vehiculoId: 'v1',
        folioAutorizacion: 'FA-1',
        litrosCargados: 100,
        kmAlCargar: 1000,
        gasolinera: 'PEMEX',
        creadaEn: ahora,
      );
      final cierre = CierreDia(
        id: 'ci1',
        choferId: 'u1',
        cargaId: 'c1',
        kmFinal: 1150, // 150 km / 100 L = 1.5 km/L
        fotoTableroPath: '/tmp/f.jpg',
        registradaEn: ahora.add(const Duration(hours: 6)),
      );

      final stats = EstadisticaCargaDia.desdeRegistros(
        vehiculoId: 'v1',
        fecha: ahora,
        cargas: [carga],
        cierres: [cierre],
      );

      expect(stats.rendimiento, closeTo(1.5, 0.01));
      expect(stats.esAnomalo, isTrue);
    });

    test('marca esAnomalo cuando rendimiento > 15 km/L', () {
      final ahora = DateTime.now();
      final carga = Carga(
        id: 'c1',
        choferId: 'u1',
        vehiculoId: 'v1',
        folioAutorizacion: 'FA-1',
        litrosCargados: 10,
        kmAlCargar: 1000,
        gasolinera: 'PEMEX',
        creadaEn: ahora,
      );
      final cierre = CierreDia(
        id: 'ci1',
        choferId: 'u1',
        cargaId: 'c1',
        kmFinal: 1160, // 160 km / 10 L = 16 km/L
        fotoTableroPath: '/tmp/f.jpg',
        registradaEn: ahora.add(const Duration(hours: 6)),
      );

      final stats = EstadisticaCargaDia.desdeRegistros(
        vehiculoId: 'v1',
        fecha: ahora,
        cargas: [carga],
        cierres: [cierre],
      );

      expect(stats.rendimiento, closeTo(16.0, 0.01));
      expect(stats.esAnomalo, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Provider tests
  // ---------------------------------------------------------------------------
  group('estadisticaCargaHoyProvider', () {
    test('retorna vacío cuando no hay sesión', () {
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
          operacionesRepositoryProvider.overrideWithValue(
            MockOperacionesRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final stats = container.read(estadisticaCargaHoyProvider);
      expect(stats.isEmpty, isTrue);
    });

    test('retorna vacío cuando el chofer no tiene cargas hoy', () {
      final repo = MockOperacionesRepository();
      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
          operacionesRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(
            () => _Sesion(
              const Perfil(
                id: 'userA',
                usuario: 'test',
                nombre: 'Test',
                correo: 'test@test.com',
                rol: RolUsuario.chofer,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final stats = container.read(estadisticaCargaHoyProvider);
      expect(stats.isEmpty, isTrue);
    });

    test('calcula métricas cuando hay cargas de hoy', () async {
      final repo = MockOperacionesRepository();
      // Registrar una carga directamente en el mock
      await repo.registrarCarga(
        choferId: 'userA',
        vehiculoId: 'veh-1',
        folioAutorizacion: 'FA-100',
        litrosCargados: 45,
        kmAlCargar: 5000,
        gasolinera: 'PEMEX Centro',
      );

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
          operacionesRepositoryProvider.overrideWithValue(repo),
          sessionProvider.overrideWith(
            () => _Sesion(
              const Perfil(
                id: 'userA',
                usuario: 'test',
                nombre: 'Test',
                correo: 'test@test.com',
                rol: RolUsuario.chofer,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final stats = container.read(estadisticaCargaHoyProvider);
      expect(stats.isEmpty, isFalse);
      expect(stats.totalCargas, 1);
      expect(stats.litrosTotales, 45);
      expect(stats.vehiculoId, 'veh-1');
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests
  // ---------------------------------------------------------------------------
  group('EstadisticasCargaScreen', () {
    Future<void> pumpScreen(
      WidgetTester tester, {
      bool conCargas = false,
      MockOperacionesRepository? repo,
    }) async {
      final mockRepo = repo ?? MockOperacionesRepository();
      if (conCargas) {
        mockRepo.precargarCarga(
          Carga(
            id: 'carga-1',
            choferId: 'userA',
            vehiculoId: 'veh-1',
            folioAutorizacion: 'FA-100',
            litrosCargados: 50,
            kmAlCargar: 8000,
            gasolinera: 'PEMEX',
            creadaEn: DateTime.now(),
          ),
        );
      }

      final container = ProviderContainer(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
          fotoPickerProvider.overrideWithValue(FakeFotoPicker()),
          ticketOcrServiceProvider.overrideWithValue(
            const FakeTicketOcrService(),
          ),
          recordatorioServiceProvider.overrideWithValue(
            FakeRecordatorioService(),
          ),
          exportadorServiceProvider.overrideWithValue(FakeExportadorService()),
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
          evidenciasRepositoryProvider.overrideWithValue(
            MockEvidenciasRepository(),
          ),
          operacionesRepositoryProvider.overrideWithValue(mockRepo),
          vehiculosRepositoryProvider.overrideWithValue(
            MockVehiculosRepository(),
          ),
          incidenciasRepositoryProvider.overrideWithValue(
            MockIncidenciasRepository(),
          ),
          auditoriaRepositoryProvider.overrideWithValue(
            MockAuditoriaRepository(),
          ),
          sessionProvider.overrideWith(
            () => _Sesion(
              const Perfil(
                id: 'userA',
                usuario: 'test',
                nombre: 'Test',
                correo: 'test@test.com',
                rol: RolUsuario.chofer,
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final router = GoRouter(
        initialLocation: RoutePaths.choferEstadisticasCarga,
        routes: [
          GoRoute(
            path: RoutePaths.choferEstadisticasCarga,
            builder: (context, state) => const EstadisticasCargaScreen(),
          ),
          GoRoute(
            path: RoutePaths.chofer,
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Chofer Home'))),
          ),
          GoRoute(
            path: RoutePaths.choferTipoOperacion,
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('Tipo Operacion'))),
          ),
        ],
      );
      addTearDown(router.dispose);

      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.light,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('muestra estado vacío cuando no hay cargas', (tester) async {
      await pumpScreen(tester);

      expect(
        find.text('Aún no has registrado ninguna carga hoy.'),
        findsOneWidget,
      );
      expect(find.text('Registrar carga'), findsOneWidget);
      expect(find.byIcon(Icons.local_gas_station_outlined), findsOneWidget);
    });

    testWidgets('muestra métricas cuando hay cargas', (tester) async {
      await pumpScreen(tester, conCargas: true);

      expect(find.text('Estadísticas de carga'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // totalCargas
      expect(find.text('50 L'), findsWidgets); // litros totales
    });

    testWidgets('muestra header con vehículo', (tester) async {
      await pumpScreen(tester, conCargas: true);

      expect(find.byIcon(Icons.directions_car_rounded), findsOneWidget);
    });

    testWidgets('muestra tile de carga individual', (tester) async {
      await pumpScreen(tester, conCargas: true);

      expect(find.text('50 L'), findsWidgets);
      expect(find.text('PEMEX'), findsOneWidget);
    });

    testWidgets('botón "Registrar carga" navega a tipo operacion', (
      tester,
    ) async {
      await pumpScreen(tester);

      await tester.tap(find.text('Registrar carga'));
      await tester.pumpAndSettle();

      expect(find.text('Tipo Operacion'), findsOneWidget);
    });

    testWidgets('renders sin overflow en mobile', (tester) async {
      await pumpScreen(tester, conCargas: true);

      expect(tester.takeException(), isNull);
    });

    testWidgets('renders sin overflow en desktop', (tester) async {
      await pumpScreen(tester, conCargas: true);
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      await tester.pump();

      expect(tester.takeException(), isNull);
    });

    testWidgets('muestra AppBar con título semántico', (tester) async {
      await pumpScreen(tester);

      expect(find.text('Estadísticas de carga'), findsOneWidget);
    });
  });
}
