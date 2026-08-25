import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/screens/administrativo/tabs/dashboard_calculo.dart';
import 'package:indi_combustible/widgets/ios_segmented_control.dart';

import 'test_helpers.dart';

void main() {
  testWidgets(
    'el dashboard del chofer renderiza sin datos sin crashear y muestra las '
    'tarjetas esperadas',
    (tester) async {
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

      // El dashboard ya no es una pestaña del bottom nav — se accede
      // directamente por ruta.
      final router = container.read(appRouterProvider);
      router.go(RoutePaths.choferDashboard);
      await tester.pumpAndSettle();

      // Sin cargas registradas todavía (mock fresco): renderiza el hero en
      // cero y el estado vacío, en vez de tronar por listas vacías.
      expect(find.text('Mi consumo'), findsWidgets);
      expect(find.text('LITROS CONSUMIDOS'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(
        find.byType(IosSegmentedControl<PeriodoDashboard>),
        findsOneWidget,
      );
      expect(
        find.text('Todavía no registras cargas en este periodo.'),
        findsOneWidget,
      );
    },
  );
}
