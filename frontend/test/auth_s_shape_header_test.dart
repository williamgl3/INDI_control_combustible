import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/auth_s_shape_header.dart';
import 'package:indi_combustible/widgets/wave_clipper.dart';

void main() {
  test(
    'la curva S permanece dentro del encabezado y responde a sus factores',
    () {
      const size = Size(400, 240);
      const clipper = SShapeHeaderClipper(
        leftHeightFactor: 0.78,
        rightHeightFactor: 0.27,
      );

      final bounds = clipper.getClip(size).getBounds();
      expect(bounds.left, 0);
      expect(bounds.top, 0);
      expect(bounds.right, size.width);
      expect(bounds.bottom, lessThanOrEqualTo(size.height));
      expect(
        clipper.shouldReclip(
          const SShapeHeaderClipper(
            leftHeightFactor: 0.78,
            rightHeightFactor: 0.27,
          ),
        ),
        isFalse,
      );
      expect(
        clipper.shouldReclip(
          const SShapeHeaderClipper(
            leftHeightFactor: 0.8,
            rightHeightFactor: 0.27,
          ),
        ),
        isTrue,
      );
    },
  );

  testWidgets('el encabezado normal conserva marca, subtítulo y curva S', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: SizedBox(
            height: 260,
            child: AuthSShapeHeader(
              height: 260,
              leftHeightFactor: 0.78,
              rightHeightFactor: 0.27,
            ),
          ),
        ),
      ),
    );

    expect(find.text('INDI Combustible'), findsOneWidget);
    expect(find.text('Control de combustible en obra'), findsOneWidget);
    final clip = tester.widget<ClipPath>(
      find.byKey(const Key('auth-s-shape-blue-clip')),
    );
    expect(clip.clipper, isA<SShapeHeaderClipper>());
    final surfaceClip = tester.widget<ClipPath>(
      find.byKey(const Key('auth-s-shape-surface-clip')),
    );
    expect(surfaceClip.clipper, isA<SShapeSurfaceClipper>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('la variante compacta conserva logo y título sin desbordar', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: SizedBox(
            width: 320,
            height: 216,
            child: AuthSShapeHeader(
              height: 216,
              leftHeightFactor: 0.92,
              rightHeightFactor: 0.68,
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
    expect(
      tester.getRect(find.byKey(const Key('auth-header-content-zone'))).bottom,
      lessThan(
        tester.getRect(find.byKey(const Key('auth-header-wave-zone'))).top,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('SafeArea Android y texto 1.3 permanecen fuera de la curva', (
    tester,
  ) async {
    for (final header in <Widget>[
      const AuthSShapeHeader(
        height: 310,
        leftHeightFactor: 0.88,
        rightHeightFactor: 0.48,
      ),
      const AuthSShapeHeader(
        height: 310,
        leftHeightFactor: 0.96,
        rightHeightFactor: 0.78,
        showBrand: false,
        logoSize: 48,
        title: 'Recuperar contraseña',
        subtitle:
            'Ingresa tu usuario o correo y te enviaremos instrucciones '
            'para restablecer tu contraseña.',
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 24),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(body: SizedBox(height: 310, child: header)),
          ),
        ),
      );

      final content = tester.getRect(
        find.byKey(const Key('auth-header-content-zone')),
      );
      final wave = tester.getRect(
        find.byKey(const Key('auth-header-wave-zone')),
      );
      expect(content.bottom, lessThan(wave.top));
      expect(wave.top - content.bottom, 24);
      expect(tester.takeException(), isNull);
    }
  });
}
