import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/data/auth_repository.dart';
import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/router/route_paths.dart';

import 'mocks/mock_auth_repository.dart';
import 'test_helpers.dart';

void main() {
  testWidgets(
    'la sidebar amplia agrupa destinos completos y conserva uno activo',
    (tester) async {
      await _fijarSuperficie(tester, const Size(1440, 900));
      final container = makeTestContainer();
      addTearDown(container.dispose);
      await _iniciarComoAdmin(tester, container);

      final sidebar = find.byKey(const ValueKey('sidebar-administrativo'));
      expect(tester.getSize(sidebar).width, 240);
      expect(find.text('OPERACIÓN'), findsOneWidget);
      expect(find.text('CONTROL'), findsOneWidget);
      expect(find.text('ADMINISTRACIÓN'), findsOneWidget);
      for (final etiqueta in const [
        'Dashboard',
        'Autorizaciones',
        'Concentrado',
        'Finanzas',
        'Vehículos',
        'Mantenimiento',
        'Marimba/Pipa',
        'Choferes',
        'Auditoría',
      ]) {
        expect(
          find.descendant(of: sidebar, matching: find.text(etiqueta)),
          findsOneWidget,
        );
      }

      final seleccionados = find.descendant(
        of: sidebar,
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      );
      expect(seleccionados, findsOneWidget);
      expect(find.text('Sección activa'), findsNothing);
      expect(find.byTooltip('Tema'), findsOneWidget);
      expect(find.byTooltip('Notificaciones'), findsOneWidget);
      expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
      expect(find.byTooltip('Más opciones'), findsOneWidget);
      await tester.tap(
        find.descendant(of: sidebar, matching: find.text('Finanzas')),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(appRouterProvider).state.uri.queryParameters['seccion'],
        'finanzas',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('la sidebar se contrae, conserva iconos y ofrece tooltips', (
    tester,
  ) async {
    await _fijarSuperficie(tester, const Size(1440, 900));
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoAdmin(tester, container);

    await tester.tap(find.byTooltip('Contraer navegación'));
    await tester.pumpAndSettle();

    final sidebar = find.byKey(const ValueKey('sidebar-administrativo'));
    expect(tester.getSize(sidebar).width, 76);
    expect(find.byTooltip('Expandir navegación'), findsOneWidget);
    for (final etiqueta in const [
      'Dashboard',
      'Autorizaciones',
      'Concentrado',
      'Finanzas',
      'Vehículos',
      'Mantenimiento',
      'Marimba/Pipa',
      'Choferes',
      'Auditoría',
    ]) {
      expect(
        find.descendant(
          of: sidebar,
          matching: find.byWidgetPredicate(
            (widget) => widget is Tooltip && widget.message == etiqueta,
          ),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('el avatar y el nombre abren el perfil administrativo', (
    tester,
  ) async {
    await _fijarSuperficie(tester, const Size(1440, 900));
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoAdmin(tester, container);

    final router = container.read(appRouterProvider);
    await tester.tap(find.byKey(const ValueKey('sidebar-admin-perfil-avatar')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, RoutePaths.administrativoPerfil);
    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('admin1'), findsOneWidget);

    router.go(RoutePaths.administrativo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Torres'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, RoutePaths.administrativoPerfil);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('sidebar-administrativo')),
        matching: find.byWidgetPredicate(
          (widget) => widget is Semantics && widget.properties.selected == true,
        ),
      ),
      findsOneWidget,
    );
  });

  for (final caso in const [
    (Size(1024, 768), ThemeMode.light),
    (Size(768, 1024), ThemeMode.dark),
  ]) {
    testWidgets('la navegación compacta no desborda en ${caso.$1}', (
      tester,
    ) async {
      await _fijarSuperficie(tester, caso.$1);
      final container = makeTestContainer();
      addTearDown(container.dispose);
      await _iniciarComoAdmin(tester, container, themeMode: caso.$2);

      expect(
        tester
            .getSize(find.byKey(const ValueKey('sidebar-administrativo')))
            .width,
        76,
      );
      expect(find.byTooltip('Expandir navegación'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('notificaciones usa panel lateral y Escape lo cierra', (
    tester,
  ) async {
    await _fijarSuperficie(tester, const Size(1440, 900));
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoAdmin(tester, container);

    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('panel-notificaciones-lateral')),
      findsOneWidget,
    );
    expect(find.text('No tienes notificaciones nuevas.'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('panel-notificaciones-lateral')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('móvil usa navegación inferior y hoja de notificaciones', (
    tester,
  ) async {
    await _fijarSuperficie(tester, const Size(390, 844));
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoAdmin(tester, container);

    expect(find.byKey(const ValueKey('sidebar-administrativo')), findsNothing);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.byTooltip('Notificaciones'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('hoja-notificaciones-movil')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('móvil conserva Perfil dentro de Más', (tester) async {
    await _fijarSuperficie(tester, const Size(390, 844));
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarComoAdmin(tester, container);

    await tester.tap(find.text('Más'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mi perfil'));
    await tester.pumpAndSettle();

    expect(
      container.read(appRouterProvider).state.uri.path,
      RoutePaths.administrativoPerfil,
    );
    expect(find.text('DATOS PERSONALES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'el cierre visible confirma, evita duplicados y dirige al login',
    (tester) async {
      await _fijarSuperficie(tester, const Size(1440, 900));
      final auth = _AuthContado();
      final container = makeTestContainer(
        overridesExtra: [authRepositoryProvider.overrideWithValue(auth)],
      );
      addTearDown(container.dispose);
      await _iniciarComoAdmin(tester, container);

      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Cancelar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(auth.cierres, 0);
      expect(container.read(sessionProvider), isNotNull);
      expect(
        container.read(appRouterProvider).state.uri.path,
        RoutePaths.administrativo,
      );

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
      expect(
        container.read(appRouterProvider).state.uri.path,
        RoutePaths.login,
      );
    },
  );
}

Future<void> _fijarSuperficie(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _iniciarComoAdmin(
  WidgetTester tester,
  ProviderContainer container, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await pumpTestApp(tester, container: container, themeMode: themeMode);
  await tester.ensureVisible(find.text('Entrar como administrador'));
  await tester.tap(find.text('Entrar como administrador'));
  await tester.pumpAndSettle();
  final dialog = find.byType(Dialog);
  await tester.enterText(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextFormField, 'Usuario del administrador'),
    ),
    'admin1',
  );
  await tester.enterText(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextFormField, 'Contraseña'),
    ),
    'admin1234',
  );
  await tester.tap(
    find.descendant(of: dialog, matching: find.text('Ingresar')),
  );
  await tester.pumpAndSettle();
}

class _AuthContado extends MockAuthRepository implements AuthRepository {
  int cierres = 0;

  @override
  Future<void> logout() async {
    cierres++;
  }
}
