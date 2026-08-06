import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/router/route_paths.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('login con credenciales inválidas muestra error y no navega', (
    tester,
  ) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await pumpTestApp(tester, container: container);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Usuario'),
      'usuarioinexistente',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'passwordmalo',
    );
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('login con credenciales mock válidas navega a /chofer', (
    tester,
  ) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await pumpTestApp(tester, container: container);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Usuario'),
      'chofer1',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'chofer123',
    );
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Hola, Juan'), findsOneWidget);
  });

  testWidgets('acceso de administrador abre modal y navega a /administrativo', (
    tester,
  ) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await pumpTestApp(tester, container: container);

    await tester.ensureVisible(find.text('Entrar como administrador'));
    await tester.tap(find.text('Entrar como administrador'));
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    await tester.enterText(
      find.descendant(
        of: dialog,
        matching: find.widgetWithText(
          TextFormField,
          'Usuario del administrador',
        ),
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

    expect(find.text('Panel administrativo'), findsOneWidget);
  });

  testWidgets(
    'registro de chofer con datos válidos crea sesión y navega a /chofer',
    (tester) async {
      final container = makeTestContainer();
      addTearDown(container.dispose);
      final router = await pumpTestApp(tester, container: container);

      router.go(RoutePaths.registroChofer);
      await tester.pumpAndSettle();

      // Paso 1: datos personales.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre(s)'),
        'Luis',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido paterno'),
        'Gómez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido materno'),
        'Ruiz',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'luis.gomez@example.com',
      );
      await tester.ensureVisible(find.text('Siguiente'));
      await tester.tap(find.text('Siguiente'));
      await tester.pumpAndSettle();

      // Paso 2: cuenta.
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Usuario'),
        'luis.gomez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'password123',
      );

      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Luis'), findsOneWidget);
    },
  );

  testWidgets(
    'recuperar password con usuario existente muestra pantalla de confirmación',
    (tester) async {
      final container = makeTestContainer();
      addTearDown(container.dispose);
      final router = await pumpTestApp(tester, container: container);

      router.go(RoutePaths.recuperarPassword);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Usuario o correo'),
        'chofer1',
      );
      await tester.ensureVisible(find.text('Enviar instrucciones'));
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Si la cuenta existe, enviamos instrucciones para restablecer '
          'tu contraseña.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Volver a iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('INDI Combustible'), findsOneWidget);
    },
  );

  testWidgets('recuperar password con usuario inexistente muestra error', (
    tester,
  ) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    final router = await pumpTestApp(tester, container: container);

    router.go(RoutePaths.recuperarPassword);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Usuario o correo'),
      'no-existe-nadie',
    );
    await tester.ensureVisible(find.text('Enviar instrucciones'));
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(
      find.text('No encontramos una cuenta con ese usuario o correo.'),
      findsOneWidget,
    );
  });
}
