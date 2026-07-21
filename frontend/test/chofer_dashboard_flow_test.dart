import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

      await tester.ensureVisible(find.text('Mi consumo'));
      await tester.tap(find.text('Mi consumo'));
      await tester.pumpAndSettle();

      // Sin cargas registradas todavía (mock fresco): renderiza el hero en
      // cero y el estado vacío, en vez de tronar por listas vacías.
      expect(find.text('Mi consumo'), findsWidgets);
      expect(find.text('LITROS CONSUMIDOS'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.byType(IosSegmentedControl<PeriodoDashboard>), findsOneWidget);
      expect(
        find.text('No registraste cargas en este periodo.'),
        findsOneWidget,
      );
    },
  );
}
