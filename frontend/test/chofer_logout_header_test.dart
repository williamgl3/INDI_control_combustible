import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/data/auth_repository.dart';
import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks/mock_auth_repository.dart';
import 'test_helpers.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final caso in <(Size, ThemeMode)>[
    (const Size(360, 640), ThemeMode.light),
    (const Size(412, 915), ThemeMode.dark),
    (const Size(768, 1024), ThemeMode.light),
    (const Size(1024, 768), ThemeMode.dark),
    (const Size(1440, 900), ThemeMode.light),
  ]) {
    testWidgets('un solo menu accesible sin overflow en ${caso.$1}', (
      tester,
    ) async {
      await _configurarVista(tester, caso.$1);
      final container = makeTestContainer();
      addTearDown(container.dispose);
      await _iniciarComoChofer(tester, container, themeMode: caso.$2);

      expect(find.byTooltip('Cerrar sesión'), findsNothing);
      expect(find.byTooltip('Abrir menú'), findsOneWidget);
      expect(find.byIcon(Icons.menu), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('chofer-header-menu-button'))),
        const Size.square(48),
      );

      await tester.tap(find.byTooltip('Abrir menú'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('chofer-menu-Mi consumo')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('chofer-menu-Mis solicitudes')),
        findsOneWidget,
      );
      expect(find.text('Acerca de'), findsOneWidget);
      expect(find.text('Cerrar sesión'), findsOneWidget);
      expect(find.byKey(const ValueKey('chofer-menu-Perfil')), findsNothing);
      expect(find.text('Cambiar tema'), findsNothing);
      expect(find.text('Ayuda y soporte'), findsNothing);
      expect(find.byType(PopupMenuDivider), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('menu conserva ruta y cierra con Escape, fuera y Atrás', (
    tester,
  ) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoChofer(tester, container);
    final ruta = container.read(appRouterProvider).state.uri.path;

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    expect(container.read(appRouterProvider).state.uri.path, ruta);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chofer-menu-Mi consumo')), findsNothing);

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(8, 500));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chofer-menu-Mi consumo')), findsNothing);

    await tester.tap(find.byTooltip('Abrir menú'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chofer-menu-Mi consumo')), findsNothing);
    expect(container.read(appRouterProvider).state.uri.path, ruta);
  });

  testWidgets('acciones reales reutilizan acerca de', (tester) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoChofer(tester, container);

    await _elegir(tester, 'Acerca de');
    expect(find.text('INDI Combustible'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(container.read(appRouterProvider).state.uri.path, RoutePaths.chofer);
  });

  testWidgets('cancelar logout conserva sesion', (tester) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoChofer(tester, container);

    await _elegir(tester, 'Cerrar sesión');
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider), isNotNull);
    expect(container.read(appRouterProvider).state.uri.path, RoutePaths.chofer);
  });

  testWidgets('confirmar logout ejecuta una vez y navega a login', (
    tester,
  ) async {
    final auth = _AuthContado();
    final container = makeTestContainer(
      overridesExtra: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    await _iniciarComoChofer(tester, container);

    await _elegir(tester, 'Cerrar sesión');
    final confirmar = find.descendant(
      of: find.byType(Dialog),
      matching: find.text('Cerrar sesión'),
    );
    await tester.tap(confirmar);
    await tester.tap(confirmar, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(auth.cierres, 1);
    expect(container.read(sessionProvider), isNull);
    expect(container.read(appRouterProvider).state.uri.path, RoutePaths.login);
  });

  testWidgets('logout advierte y conserva la cola offline por usuario', (
    tester,
  ) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoChofer(tester, container);
    final usuarioId = container.read(sessionProvider)!.id;
    final cola = container.read(colaSolicitudesOfflineProvider);
    await cola.agregar(
      SolicitudPendienteOffline(
        idLocal: '00000000-0000-4000-8000-000000000099',
        usuarioId: usuarioId,
        idempotencyKey: '00000000-0000-4000-8000-000000000099',
        payloadFingerprint: 'a' * 64,
        vehiculoId: 'vehiculo-prueba',
        litrosSolicitados: 20,
        esUrgente: false,
        motivoChofer: null,
        actividad: 'Prueba offline',
        fechaProgramada: DateTime.utc(2026, 8, 22),
        fotoTableroPath: 'foto-local.jpg',
        creadaEn: DateTime.utc(2026, 8, 21),
      ),
    );
    container.read(operacionesTickProvider.notifier).state++;

    await _elegir(tester, 'Cerrar sesión');
    expect(
      find.textContaining('Se conservarán asociadas a esta cuenta'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(await cola.leer(), hasLength(1));
  });
}

Future<void> _elegir(WidgetTester tester, String etiqueta) async {
  await tester.tap(find.byTooltip('Abrir menú'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(etiqueta));
  await tester.pumpAndSettle();
}

Future<void> _configurarVista(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _iniciarComoChofer(
  WidgetTester tester,
  ProviderContainer container, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await pumpTestApp(tester, container: container, themeMode: themeMode);
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Usuario'),
    'chofer1',
  );
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Contraseña'),
    'chofer123',
  );
  await tester.tap(find.text('Ingresar'));
  await tester.pumpAndSettle();
  expect(container.read(sessionProvider), isNotNull);
}

class _AuthContado extends MockAuthRepository implements AuthRepository {
  int cierres = 0;

  @override
  Future<void> logout() async {
    cierres++;
  }
}
