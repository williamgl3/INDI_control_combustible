import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/screens/login/login_screen.dart';
import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/auth_screen_shell.dart';

void main() {
  testWidgets('login conserva campos y acciones en escritorio y tablet', (
    tester,
  ) async {
    for (final size in const [
      Size(1440, 900),
      Size(1024, 768),
      Size(768, 1024),
    ]) {
      await tester.pumpWidget(const SizedBox.shrink());
      await _pumpLogin(tester, size: size);

      final header = tester.getRect(
        find.byKey(const Key('auth-responsive-header')),
      );
      final usuario = tester.getRect(
        find.widgetWithText(TextFormField, 'Usuario'),
      );
      expect(usuario.top, greaterThan(header.bottom), reason: 'size=$size');

      await tester.ensureVisible(find.text('Ingresar'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'size=$size');
    }
  });

  testWidgets('login separa el primer campo del encabezado en móvil', (
    tester,
  ) async {
    await _pumpLogin(tester, size: const Size(390, 844));

    final header = tester.getRect(
      find.byKey(const Key('auth-responsive-header')),
    );
    final usuario = tester.getRect(
      find.widgetWithText(TextFormField, 'Usuario'),
    );

    expect(usuario.top - header.bottom, greaterThanOrEqualTo(24));
    expect(usuario.top, greaterThan(header.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('login usa encabezado compacto y permite alcanzar sus acciones', (
    tester,
  ) async {
    await _pumpLogin(tester, size: const Size(320, 568));

    expect(
      tester.getSize(find.byKey(const Key('auth-responsive-header'))).height,
      216,
    );
    expect(find.text('Control de combustible en obra'), findsNothing);

    final ingresar = find.text('Ingresar');
    await tester.ensureVisible(ingresar);
    await tester.pumpAndSettle();
    expect(ingresar, findsOneWidget);
    expect(tester.getRect(ingresar).bottom, lessThanOrEqualTo(568));
    expect(tester.takeException(), isNull);
  });

  testWidgets('login mantiene campo enfocado y botón accesibles con teclado', (
    tester,
  ) async {
    await _pumpLogin(
      tester,
      size: const Size(360, 640),
      viewInsets: const EdgeInsets.only(bottom: 260),
    );

    final password = find.widgetWithText(TextFormField, 'Contraseña');
    await tester.tap(password);
    await tester.pumpAndSettle();
    await tester.ensureVisible(password);
    await tester.pumpAndSettle();

    final scrollRect = tester.getRect(
      find.byKey(const Key('auth-form-scroll')),
    );
    final passwordRect = tester.getRect(password);
    expect(passwordRect.top, greaterThanOrEqualTo(scrollRect.top));
    expect(passwordRect.bottom, lessThanOrEqualTo(scrollRect.bottom));

    await tester.ensureVisible(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.text('Ingresar')).bottom,
      lessThanOrEqualTo(scrollRect.bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('encabezado compacto respeta animaciones deshabilitadas', (
    tester,
  ) async {
    await _pumpShell(
      tester,
      size: const Size(360, 640),
      disableAnimations: true,
      child: const TextField(decoration: InputDecoration(labelText: 'Campo')),
    );

    final header = tester.widget<AnimatedContainer>(
      find.byKey(const Key('auth-responsive-header')),
    );
    expect(header.duration, Duration.zero);
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'login admite texto 1.3 sin overflow en tema ${brightness.name}',
      (tester) async {
        await _pumpLogin(
          tester,
          size: const Size(390, 844),
          brightness: brightness,
          textScaler: const TextScaler.linear(1.3),
        );

        await tester.ensureVisible(find.text('Ingresar'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  required Size size,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return _pumpShell(
    tester,
    size: size,
    viewInsets: viewInsets,
    brightness: brightness,
    textScaler: textScaler,
    child: const LoginScreen(),
    directChild: true,
  );
}

Future<void> _pumpShell(
  WidgetTester tester, {
  required Size size,
  required Widget child,
  EdgeInsets viewInsets = EdgeInsets.zero,
  Brightness brightness = Brightness.light,
  TextScaler textScaler = TextScaler.noScaling,
  bool disableAnimations = false,
  bool directChild = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final mediaQuery = MediaQueryData(
    size: size,
    viewInsets: viewInsets,
    textScaler: textScaler,
    disableAnimations: disableAnimations,
  );
  final theme = brightness == Brightness.dark
      ? AppTheme.dark()
      : AppTheme.light();

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: mediaQuery,
          child: directChild ? child : AuthScreenShell(child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}
