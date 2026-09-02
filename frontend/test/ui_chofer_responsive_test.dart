import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/widgets/sidebar_chofer.dart';

import 'test_helpers.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(768, 1024),
    const Size(1024, 768),
    const Size(1440, 900),
  ]) {
    for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'login y panel del chofer se adaptan a ${size.width.toInt()} px en $themeMode',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          final container = makeTestContainer();
          addTearDown(container.dispose);
          await pumpTestApp(tester, container: container, themeMode: themeMode);
          expect(tester.takeException(), isNull);

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

          final cta = find.byKey(const ValueKey('accion-solicitar-carga'));
          expect(cta, findsOneWidget);
          final anchoCta = tester.getSize(cta).width;
          if (size.width < 700) {
            expect(find.byType(SidebarChofer), findsNothing);
          } else {
            expect(find.byType(SidebarChofer), findsOneWidget);
          }
          expect(anchoCta, greaterThanOrEqualTo(44));
          expect(anchoCta, lessThan(size.width));
          expect(find.text('Actividad reciente'), findsOneWidget);
          expect(
            find.text('Aún no tienes solicitudes de carga.'),
            findsOneWidget,
          );
          expect(
            find.text('Crea tu primera solicitud para comenzar.'),
            findsNothing,
          );
          expect(
            find.widgetWithText(FloatingActionButton, 'Solicitar carga'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
