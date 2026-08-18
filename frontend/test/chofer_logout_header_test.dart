import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/data/auth_repository.dart';
import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/widgets/header_glass_button.dart';

import 'mocks/mock_auth_repository.dart';
import 'test_helpers.dart';

void main() {
  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('las acciones del encabezado comparten medidas en $themeMode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = makeTestContainer();
      addTearDown(container.dispose);
      await _iniciarComoChofer(tester, container, themeMode: themeMode);

      final cerrar = find.byTooltip('Cerrar sesión');
      final opciones = find.byTooltip('Más opciones');
      final botonCerrar = find.ancestor(
        of: cerrar,
        matching: find.byType(HeaderGlassButton),
      );
      final botonOpciones = find.ancestor(
        of: opciones,
        matching: find.byType(HeaderGlassButton),
      );
      expect(tester.getSize(botonCerrar), const Size.square(48));
      expect(tester.getSize(botonOpciones), const Size.square(48));
      expect(tester.getSize(find.byIcon(Icons.logout)), const Size.square(24));
      expect(
        tester.getSize(find.byIcon(Icons.more_vert)),
        const Size.square(24),
      );
      expect(
        tester.getCenter(botonCerrar).dy,
        tester.getCenter(botonOpciones).dy,
      );
      expect(
        tester.getTopLeft(botonOpciones).dx -
            tester.getTopRight(botonCerrar).dx,
        12,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('el encabezado muestra cierre y conserva las otras opciones', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoChofer(tester, container);

    expect(find.byIcon(Icons.logout), findsOneWidget);
    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
    expect(find.byTooltip('Más opciones'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Más opciones'));
    await tester.pumpAndSettle();
    expect(find.text('Acerca de'), findsOneWidget);
    expect(find.text('Ayuda y soporte'), findsOneWidget);
    expect(find.text('Cerrar sesión'), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Acerca de'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cancelar el cierre conserva la sesión', (tester) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoChofer(tester, container);

    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Cancelar')),
    );
    await tester.pumpAndSettle();

    expect(container.read(sessionProvider), isNotNull);
    expect(container.read(appRouterProvider).state.uri.path, RoutePaths.chofer);
  });

  testWidgets('confirmar cierra una sola vez y dirige al login', (
    tester,
  ) async {
    final auth = _AuthContado();
    final container = makeTestContainer(
      overridesExtra: [authRepositoryProvider.overrideWithValue(auth)],
    );
    addTearDown(container.dispose);
    await _iniciarComoChofer(tester, container);

    final boton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Cerrar sesión'),
        matching: find.byType(IconButton),
      ),
    );
    boton.onPressed!();
    boton.onPressed!();
    await tester.pumpAndSettle();
    expect(find.text('¿Cerrar sesión?'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Cerrar sesión'),
      ),
    );
    await tester.pumpAndSettle();

    expect(auth.cierres, 1);
    expect(container.read(sessionProvider), isNull);
    expect(container.read(appRouterProvider).state.uri.path, RoutePaths.login);
  });
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
