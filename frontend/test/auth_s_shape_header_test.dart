import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/theme/app_colors.dart';
import 'package:indi_combustible/widgets/auth_s_shape_header.dart';
import 'package:indi_combustible/widgets/logo_glass.dart';

void main() {
  testWidgets(
    'header auth usa el mismo primary que el botón y no agrega borde',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SizedBox(
              height: 260,
              child: AuthSShapeHeader(
                height: 260,
                leftHeightFactor: 0.94,
                rightHeightFactor: 0.80,
              ),
            ),
          ),
        ),
      );

      expect(find.text('INDI Combustible'), findsOneWidget);
      expect(find.text('Control de combustible en obra'), findsOneWidget);
      expect(find.byType(IndiLogo), findsOneWidget);
      expect(find.byType(ClipPath), findsNothing);
      final header = tester.widget<Container>(
        find.byKey(const Key('auth-s-shape-header')),
      );
      expect(header.color, AppColors.light.primary);
      expect(header.decoration, isNull);
      final buttonColor = Theme.of(
        tester.element(find.byType(AuthSShapeHeader)),
      ).elevatedButtonTheme.style?.backgroundColor?.resolve({});
      expect(buttonColor, AppColors.light.primary);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('variante compacta conserva logo y título sin overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            height: 168,
            child: AuthSShapeHeader(
              height: 168,
              leftHeightFactor: 0.94,
              rightHeightFactor: 0.80,
              compact: true,
              title: 'Recuperar contraseña',
              subtitle: 'Instrucciones de recuperación',
            ),
          ),
        ),
      ),
    );

    expect(find.text('INDI Combustible'), findsOneWidget);
    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(find.text('Control de combustible en obra'), findsNothing);
    expect(find.text('Instrucciones de recuperación'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('SafeArea y escalado de texto no generan overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 24),
            textScaler: TextScaler.linear(1.3),
          ),
          child: const Scaffold(
            body: AuthSShapeHeader(
              height: 310,
              leftHeightFactor: 0.94,
              rightHeightFactor: 0.80,
              showBrand: false,
              logoSize: 48,
              title: 'Recuperar contraseña',
              subtitle:
                  'Ingresa tu usuario o correo y te enviaremos instrucciones.',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Recuperar contraseña'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
