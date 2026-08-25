import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/auth_s_shape_header.dart';
import 'package:indi_combustible/widgets/auth_screen_shell.dart';

void main() {
  testWidgets('en escritorio, la tarjeta nunca excede la ventana', (
    tester,
  ) async {
    for (final alto in [1200.0, 700.0, 500.0, 400.0]) {
      tester.view.physicalSize = Size(900, alto);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AuthScreenShell(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('¡Bienvenido!'),
                const SizedBox(height: 32),
                ElevatedButton(onPressed: () {}, child: const Text('Ingresar')),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'alto=$alto');
      final tarjeta = tester.getRect(
        find.byKey(const Key('auth-screen-shell-card')),
      );
      expect(tarjeta.top, greaterThanOrEqualTo(0));
      expect(tarjeta.bottom, lessThanOrEqualTo(alto));
    }
  });

  testWidgets('el header sólido conserva textos largos sin overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: AuthScreenShell(
          titulo: 'Regístrate',
          subtitulo:
              'Primero tus datos personales, esto puede tomar unos minutos.',
          mostrarMarca: false,
          logoSize: 48,
          compactLogoSize: 36,
          child: const SizedBox(height: 400, child: Text('formulario')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(AuthSShapeHeader),
        matching: find.byType(ClipPath),
      ),
      findsNothing,
    );
    expect(find.textContaining('Primero tus datos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('el titulo de login queda debajo del header en movil', (
    tester,
  ) async {
    for (final viewport in const [
      Size(360, 640),
      Size(390, 844),
      Size(412, 915),
    ]) {
      tester.view.physicalSize = viewport;
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: const TextScaler.linear(1.0),
            ),
            child: AuthScreenShell(
              centrarContenido: false,
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Iniciar sesión'),
                  SizedBox(height: 20),
                  TextField(),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final header = tester.getRect(
        find.byKey(const Key('auth-responsive-header')),
      );
      final title = tester.getRect(find.text('Iniciar sesión'));
      expect(title.top, greaterThanOrEqualTo(header.bottom + 12));
      expect(tester.takeException(), isNull, reason: 'viewport=$viewport');
    }
    tester.view.reset();
  });
}
