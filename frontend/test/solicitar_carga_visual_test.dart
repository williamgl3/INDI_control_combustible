import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/screens/chofer/solicitar_carga_screen.dart';
import 'package:indi_combustible/theme/app_theme.dart';

void main() {
  Future<void> montar(
    WidgetTester tester, {
    required bool cargando,
    double width = 320,
    ThemeMode themeMode = ThemeMode.light,
    double teclado = 0,
  }) async {
    tester.view.physicalSize = Size(width, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 700),
            viewInsets: EdgeInsets.only(bottom: teclado),
          ),
          child: Scaffold(
            bottomNavigationBar: BarraEnviarSolicitud(
              cargando: cargando,
              onEnviar: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('muestra un solo FilledButton sin contenedor decorado', (
    tester,
  ) async {
    await montar(tester, cargando: false);
    expect(
      find.widgetWithText(FilledButton, 'Enviar solicitud'),
      findsOneWidget,
    );
    expect(find.text('Enviar solicitud'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('enviar-solicitud-button')),
        matching: find.byType(Container),
      ),
      findsNothing,
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('enviar-solicitud-size')))
          .height,
      52,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('conserva 52 px al enviar y deshabilita la acción', (
    tester,
  ) async {
    await montar(tester, cargando: true, themeMode: ThemeMode.dark);
    final button = tester.widget<FilledButton>(
      find.byKey(const ValueKey('enviar-solicitud-button')),
    );
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const ValueKey('enviar-solicitud-size')))
          .height,
      52,
    );
  });

  testWidgets('no desborda a 320 px con teclado móvil abierto', (tester) async {
    await montar(tester, cargando: false, teclado: 300);
    expect(tester.takeException(), isNull);
  });

  for (final width in [480.0, 1200.0]) {
    testWidgets('el botón conserva una sola superficie a ${width.toInt()} px', (
      tester,
    ) async {
      await montar(tester, cargando: false, width: width);
      expect(
        find.widgetWithText(FilledButton, 'Enviar solicitud'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
}
