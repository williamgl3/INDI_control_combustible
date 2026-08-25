import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';

import 'test_helpers.dart';

void main() {
  for (final caso in <(Size, double)>[
    (const Size(390, 844), 1),
    (const Size(412, 915), 1),
    (const Size(844, 390), 1.3),
    (const Size(390, 844), 2),
  ]) {
    testWidgets(
      'la accion no cubre tarjetas en ${caso.$1} con texto ${caso.$2}',
      (tester) async {
        await _configurarVista(tester, caso.$1, caso.$2);
        final container = makeTestContainer();
        addTearDown(container.dispose);
        await _iniciarChofer(tester, container);
        await _crearSolicitudes(tester, container, 6);

        final tarjetas = find.byKey(
          const ValueKey('actividad-con-datos'),
          skipOffstage: false,
        );
        expect(tarjetas, findsOneWidget);
        final ultima = find.byKey(const ValueKey('solicitud-sol-5'));
        await tester.scrollUntilVisible(
          ultima,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();

        final accion = find.byKey(const ValueKey('accion-solicitar-carga'));
        expect(accion, findsOneWidget);
        final rectAccion = tester.getRect(accion);
        final rectUltima = tester.getRect(ultima);
        final rectViewport = tester.getRect(find.byType(Scrollable).first);
        // getRect(ultima) devuelve también la porción del hijo que el
        // viewport recorta. Compara sólo los píxeles realmente visibles.
        final rectUltimaVisible = rectUltima.intersect(rectViewport);
        expect(
          rectAccion.overlaps(rectUltimaVisible),
          isFalse,
          reason:
              'acción=$rectAccion, tarjeta visible=$rectUltimaVisible, '
              'viewport=$rectViewport',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('el estado vacio muestra una sola llamada a la accion', (
    tester,
  ) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarChofer(tester, container);

    expect(find.text('Solicitar carga'), findsOneWidget);
    expect(find.byKey(const ValueKey('accion-solicitar-carga')), findsNothing);
    expect(
      find.byKey(const ValueKey('solicitar-desde-estado-vacio')),
      findsOneWidget,
    );
  });

  testWidgets('reducir movimiento conserva layout y termina sin timers', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await _iniciarChofer(tester, container);
    await _crearSolicitudes(tester, container, 1);

    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('accion-solicitar-carga')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}

Future<void> _configurarVista(
  WidgetTester tester,
  Size size,
  double escala,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = escala;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Future<void> _iniciarChofer(
  WidgetTester tester,
  ProviderContainer container,
) async {
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
}

Future<void> _crearSolicitudes(
  WidgetTester tester,
  ProviderContainer container,
  int cantidad,
) async {
  final perfil = container.read(sessionProvider)!;
  final repo = container.read(operacionesRepositoryProvider);
  final vehiculo = container.read(vehiculosRepositoryProvider).todos.first;
  for (var indice = 0; indice < cantidad; indice++) {
    final futuro = repo.enviarSolicitud(
      idempotencyKey: 'idem-$indice',
      payloadFingerprint: 'fingerprint-$indice',
      choferId: perfil.id,
      vehiculo: vehiculo,
      litrosSolicitados: 37.25 + indice,
      actividad: 'Actividad $indice',
      fechaProgramada: DateTime(2099, 12, 29 + indice),
    );
    // El repositorio simula 400 ms de latencia. Hay que avanzar el reloj
    // falso más allá de ese límite antes de esperar el Future; de lo
    // contrario el test queda suspendido sin que exista otro pump que
    // pueda completar el temporizador.
    await tester.pump(const Duration(milliseconds: 401));
    await futuro;
  }
  container.read(operacionesTickProvider.notifier).state++;
  await tester.pumpAndSettle();
}
