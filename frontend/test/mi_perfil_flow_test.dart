import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_helpers.dart';

Future<void> _loginComoChofer1(WidgetTester tester) async {
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
}

void main() {
  testWidgets('cambiar contraseña con datos válidos muestra éxito', (
    tester,
  ) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await pumpTestApp(tester, container: container);
    await _loginComoChofer1(tester);

    // En escritorio, el avatar inferior es el acceso principal a Perfil.
    await tester.tap(find.byKey(const ValueKey('sidebar-chofer-perfil')));
    await tester.pumpAndSettle();

    // `findsWidgets` (no `findsOneWidget`): en viewports anchos aparece el
    // sidebar de escritorio, que también muestra el nombre del chofer
    // además del título de la propia pantalla de perfil.
    expect(find.text('Juan Pérez'), findsWidgets);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña actual'),
      'chofer123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña nueva'),
      'nuevaPassword123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Confirmar contraseña nueva'),
      'nuevaPassword123',
    );
    await tester.ensureVisible(find.text('Guardar nueva contraseña'));
    await tester.tap(find.text('Guardar nueva contraseña'));
    await tester.pumpAndSettle();

    expect(find.text('Contraseña actualizada.'), findsOneWidget);
  });

  testWidgets(
    'cambiar contraseña con la contraseña actual incorrecta muestra error',
    (tester) async {
      final container = makeTestContainer();
      addTearDown(container.dispose);
      await pumpTestApp(tester, container: container);
      await _loginComoChofer1(tester);

      await tester.tap(find.byKey(const ValueKey('sidebar-chofer-perfil')));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña actual'),
        'contraseñaIncorrecta',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña nueva'),
        'nuevaPassword123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña nueva'),
        'nuevaPassword123',
      );
      await tester.ensureVisible(find.text('Guardar nueva contraseña'));
      await tester.tap(find.text('Guardar nueva contraseña'));
      await tester.pumpAndSettle();

      expect(find.text('La contraseña actual no es correcta.'), findsOneWidget);
      expect(find.text('Contraseña actualizada.'), findsNothing);
    },
  );
}
