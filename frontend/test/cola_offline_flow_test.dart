import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/cola_solicitudes_offline.dart';
import 'package:indi_combustible/core/connectivity_provider.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/theme/app_theme.dart';

import 'test_helpers.dart';

Future<void> _elegirVehiculo(
  WidgetTester tester,
  String etiquetaVehiculo,
) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(etiquetaVehiculo).last);
  await tester.pumpAndSettle();
}

/// Igual que `pumpTestApp` de `test_helpers.dart`, pero además arranca
/// `observarReconexionParaSincronizar` (normalmente solo se llama desde
/// `_AppConRouter` en `main.dart`, que estas pruebas no montan) — sin
/// esto no habría forma de simular "la app detecta que volvió la señal y
/// sincroniza sola".
Future<GoRouter> _pumpAppConSincronizacion(
  WidgetTester tester, {
  required ProviderContainer container,
}) async {
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (context, ref, _) {
          observarReconexionParaSincronizar(ref);
          return MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  router.go(RoutePaths.login);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  setUp(() {
    // `ColaSolicitudesOffline` usa shared_preferences — sin esto, las
    // llamadas al canal de plataforma real fallarían en el entorno de
    // test.
    SharedPreferences.setMockInitialValues({});
  });

  test('incidencia pendiente conserva la identidad del supervisor', () {
    final pendiente = IncidenciaPendienteOffline(
      idLocal: 'incidencia-local',
      usuarioId: 'supervisor-1',
      vehiculoId: 'unidad-1',
      descripcion: 'Incidencia ficticia',
      creadaEn: DateTime.utc(2026, 8, 12),
    );

    final restaurada = IncidenciaPendienteOffline.fromJson(pendiente.toJson());

    expect(restaurada.usuarioId, 'supervisor-1');
    expect(restaurada.vehiculoId, 'unidad-1');
  });

  testWidgets('sin conexión, solicitar carga se encola y se sincroniza sola al '
      'reconectar', (tester) async {
    final controlConectividad = StreamController<bool>.broadcast();
    addTearDown(controlConectividad.close);

    final container = makeTestContainer(
      overridesExtra: [
        conectividadProvider.overrideWith((ref) => controlConectividad.stream),
      ],
    );
    addTearDown(container.dispose);

    await _pumpAppConSincronizacion(tester, container: container);

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

    // Se marca sin conexión (el provider ya está suscrito tras el pump
    // de arriba, así que el evento sí llega).
    controlConectividad.add(false);
    await tester.pump();
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('accion-solicitar-carga')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Vehículo Ligero'));
    await tester.pumpAndSettle();
    await _elegirVehiculo(tester, 'ABC-123-A');
    await tester.ensureVisible(find.text('Tomar foto del tablero'));
    await tester.tap(find.text('Tomar foto del tablero'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('L · toca para escribir'));
    await tester.tap(find.text('L · toca para escribir'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(TextField),
      ),
      '40',
    );
    await tester.tap(
      find.descendant(of: find.byType(Dialog), matching: find.text('Listo')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Actividad'),
      'Actividad de prueba',
    );
    await tester.ensureVisible(find.text('Enviar solicitud'));
    await tester.tap(find.text('Enviar solicitud'));
    await tester.pumpAndSettle();

    // Se detecta sin conexión de entrada: se encola directo, sin llegar
    // a intentar la petición real.
    expect(find.text('Sin conexión'), findsOneWidget);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('1 operación guardada sin conexión'),
      findsOneWidget,
    );

    final repo = container.read(operacionesRepositoryProvider);
    final chofer1 = container
        .read(authRepositoryProvider)
        .listarChoferes()
        .firstWhere((c) => c.usuario == 'chofer1');
    expect(repo.solicitudesDeChofer(chofer1.id), isEmpty);

    // Se reconecta — `observarReconexionParaSincronizar` debe disparar
    // la sincronización sola. `MockOperacionesRepository.enviarSolicitud`
    // tiene un `Future.delayed` interno; sin nada en pantalla animando
    // (a diferencia del botón "Enviar solicitud", que sigue pintando el
    // spinner), `pumpAndSettle()` se detendría antes de que el timer
    // termine — se avanza el reloj falso explícitamente primero.
    controlConectividad.add(true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(repo.solicitudesDeChofer(chofer1.id), hasLength(1));
    expect(
      find.textContaining('solicitud guardada sin conexión'),
      findsNothing,
    );
  });
}
