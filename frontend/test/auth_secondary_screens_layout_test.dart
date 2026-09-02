import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/widgets/logo_glass.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('registro usa encabezado propio y comienza bajo la curva', (
    tester,
  ) async {
    await _setSurface(tester, const Size(390, 844));
    final container = makeTestContainer();
    addTearDown(container.dispose);
    final router = await pumpTestApp(tester, container: container);

    router.go(RoutePaths.registroChofer);
    await tester.pumpAndSettle();

    expect(find.text('INDI Combustible'), findsNothing);
    expect(find.text('Control de combustible en obra'), findsNothing);
    expect(find.text('Regístrate'), findsOneWidget);
    expect(find.text('Primero tus datos personales.'), findsOneWidget);
    expect(find.byTooltip('Volver'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics && widget.properties.label == 'Logo de INDI',
      ),
      findsOneWidget,
    );
    expect(tester.widget<IndiLogo>(find.byType(IndiLogo)).width, 100);

    final header = tester.getRect(
      find.byKey(const Key('auth-responsive-header')),
    );
    final indicador = tester.getRect(
      find.byKey(const Key('registro-indicador-pasos')),
    );
    expect(indicador.top - header.bottom, inInclusiveRange(24, 32));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'recuperación no repite marca ni centra artificialmente el campo',
    (tester) async {
      await _setSurface(tester, const Size(390, 844));
      final container = makeTestContainer();
      addTearDown(container.dispose);
      final router = await pumpTestApp(tester, container: container);

      router.go(RoutePaths.recuperarPassword);
      await tester.pumpAndSettle();

      expect(find.text('INDI Combustible'), findsNothing);
      expect(find.text('Control de combustible en obra'), findsNothing);
      expect(find.text('Recuperar contraseña'), findsOneWidget);
      expect(
        find.text(
          'Ingresa tu usuario o correo y te enviaremos instrucciones '
          'para restablecer tu contraseña.',
        ),
        findsOneWidget,
      );

      final header = tester.getRect(
        find.byKey(const Key('auth-responsive-header')),
      );
      final field = tester.getRect(
        find.widgetWithText(TextFormField, 'Usuario o correo'),
      );
      expect(field.top - header.bottom, inInclusiveRange(24, 32));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('variantes compactas conservan logo y título sin repetir marca', (
    tester,
  ) async {
    await _setSurface(tester, const Size(360, 640));
    final container = makeTestContainer();
    addTearDown(container.dispose);
    final router = await pumpTestApp(tester, container: container);

    router.go(RoutePaths.recuperarPassword);
    await tester.pumpAndSettle();

    expect(find.text('INDI Combustible'), findsNothing);
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(tester.widget<IndiLogo>(find.byType(IndiLogo)).width, 78);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setSurface(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}
