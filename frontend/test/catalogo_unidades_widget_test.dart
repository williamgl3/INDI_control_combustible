import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/screens/administrativo/tabs/vehiculos_tab.dart';
import 'package:indi_combustible/theme/app_theme.dart';

import 'mocks/mock_vehiculos_repository.dart';

void main() {
  const perfilAdministrativo = Perfil(
    id: 'admin-catalogo-widget',
    usuario: 'admin_catalogo_widget',
    nombre: 'Administrativo',
    correo: 'admin.catalogo@example.com',
    rol: RolUsuario.administrativo,
  );
  late MockVehiculosRepository repo;

  setUp(() async {
    repo = MockVehiculosRepository();
    final maquina = await repo.crear(
      tipoUnidad: 'Maquinaria',
      numeroEconomico: 'M-1',
      tipoCombustible: 'Diésel',
      modelo: 'Excavadora',
    );
    await repo.cambiarEstado(id: maquina.id, activo: false);
    await repo.crear(
      tipoUnidad: 'Marimba',
      placas: 'MAR-1',
      numeroEconomico: 'G-1',
      tipoCombustible: 'Diésel',
      modelo: 'Tanque móvil',
    );
    await repo.crear(
      tipoUnidad: 'Pipa',
      placas: 'PIP-1',
      numeroEconomico: 'G-2',
      tipoCombustible: 'Diésel',
      modelo: 'Pipa',
    );
    await repo.crear(
      tipoUnidad: 'Vehículo',
      placas: 'MAG-1',
      tipoCombustible: 'Magna',
      modelo: 'Vehículo Magna',
    );
  });

  Future<void> montar(
    WidgetTester tester, {
    Size size = const Size(1200, 800),
    ThemeMode mode = ThemeMode.light,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .iniciarSesion(perfilAdministrativo);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const Scaffold(body: VehiculosTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('muestra las tres vistas y conserva la categoría Pipa', (
    tester,
  ) async {
    await montar(tester);
    expect(find.text('2 unidades en esta categoría'), findsOneWidget);
    await tester.tap(find.text('Marimbas y pipas'));
    await tester.pumpAndSettle();
    expect(find.text('2 unidades en esta categoría'), findsOneWidget);
    expect(find.text('Marimba'), findsOneWidget);
    expect(find.text('Pipa'), findsWidgets);
  });

  testWidgets('administración muestra maquinaria inactiva', (tester) async {
    await montar(tester);
    await tester.tap(find.text('Maquinaria'));
    await tester.pumpAndSettle();
    expect(find.text('INACTIVO'), findsOneWidget);
  });

  testWidgets('restablece combustible inexistente al cambiar de categoría', (
    tester,
  ) async {
    await montar(tester);
    await tester.tap(find.text('Todos los combustibles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Magna').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maquinaria'));
    await tester.pumpAndSettle();
    expect(find.text('Todos los combustibles'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no produce overflow a 320 px en tema oscuro', (tester) async {
    await montar(tester, size: const Size(320, 760), mode: ThemeMode.dark);
    expect(tester.takeException(), isNull);
    expect(find.text('Catálogo de unidades'), findsOneWidget);
  });

  for (final width in [480.0, 768.0]) {
    testWidgets('catálogo se adapta sin overflow a ${width.toInt()} px', (
      tester,
    ) async {
      await montar(tester, size: Size(width, 800));
      expect(tester.takeException(), isNull);
      expect(find.text('Catálogo de unidades'), findsOneWidget);
    });
  }
}
