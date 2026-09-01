import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/providers.dart';

import 'test_helpers.dart';

/// Selecciona en el `DropdownButtonFormField` de [SelectorVehiculo] la
/// unidad sembrada en el mock por su etiqueta visible — mismo helper que
/// en `comprobar_carga_flow_test.dart`.
Future<void> _elegirVehiculo(
  WidgetTester tester,
  String etiquetaVehiculo,
) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(etiquetaVehiculo).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'chofer reporta una incidencia y el admin la ve en Mantenimiento',
    (tester) async {
      // La pestaña de Mantenimiento (tarjeta con ícono + texto + badge +
      // botón "Registrar servicio" en una sola fila) no cabe en el ancho
      // lógico angosto que resulta del tamaño de superficie por defecto
      // de flutter_test — se agranda la ventana a un ancho de
      // escritorio (>= AppBreakpoints.tablet), que además cambia el
      // panel admin a su layout con sidebar fijo en vez de bottom nav.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
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

      await tester.ensureVisible(
        find.byKey(const ValueKey('accion-solicitar-carga')),
      );
      await tester.tap(find.byKey(const ValueKey('accion-solicitar-carga')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vehículo Ligero'));
      await tester.pumpAndSettle();
      await _elegirVehiculo(tester, 'ABC-123-A');
      await tester.pumpAndSettle();

      // Sin historial todavía, el vehículo cae en "sin datos" — se ofrece
      // el atajo corto de reportar (no el aviso de mantenimiento vencido).
      await tester.ensureVisible(find.text('¿Problema con esta unidad?'));
      await tester.tap(find.text('¿Problema con esta unidad?'));
      await tester.pumpAndSettle();

      expect(find.text('Reportar falla o incidencia'), findsOneWidget);

      final dialog = find.byType(Dialog);
      await tester.enterText(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(TextFormField, 'Descripción'),
        ),
        'Se ponchó una llanta en el camino.',
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Reportar')),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();

      expect(find.text('Incidencia reportada.'), findsOneWidget);
      final mensajeContext = tester.element(find.byType(SnackBar));
      ScaffoldMessenger.of(mensajeContext).hideCurrentSnackBar();
      await tester.pumpAndSettle();

      // Vuelve a /chofer y entra como admin en una sesión nueva.
      // "Cerrar sesión" del chofer está en la pestaña Perfil del bottom nav.
      // Dos pantallas de por medio ahora (TipoOperacionScreen +
      // SolicitarCargaScreen), así que hacen falta dos "back".
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      final accesoPerfil = find.byKey(const ValueKey('sidebar-chofer-perfil'));
      await tester.ensureVisible(accesoPerfil);
      await tester.tap(accesoPerfil);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cerrar sesión'));
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();
      // Confirmación antes de cerrar sesión (ver ConfirmarCerrarSesionDialog).
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Cerrar sesión'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Entrar como administrador'));
      await tester.tap(find.text('Entrar como administrador'));
      await tester.pumpAndSettle();
      final loginDialog = find.byType(Dialog);
      await tester.enterText(
        find.descendant(
          of: loginDialog,
          matching: find.widgetWithText(
            TextFormField,
            'Usuario del administrador',
          ),
        ),
        'admin1',
      );
      await tester.enterText(
        find.descendant(
          of: loginDialog,
          matching: find.widgetWithText(TextFormField, 'Contraseña'),
        ),
        'admin1234',
      );
      await tester.tap(
        find.descendant(of: loginDialog, matching: find.text('Ingresar')),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Mantenimiento'));
      await tester.tap(find.text('Mantenimiento'));
      await tester.pumpAndSettle();

      // GroupedSection pinta su `header` en mayúsculas (ver
      // `grouped_section.dart`: `header!.toUpperCase()`).
      expect(find.text('INCIDENCIAS REPORTADAS (1)'), findsOneWidget);
      expect(find.text('Se ponchó una llanta en el camino.'), findsOneWidget);

      // El admin la marca como resuelta.
      await tester.ensureVisible(find.text('Resolver'));
      await tester.tap(find.text('Resolver'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Resolver'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('INCIDENCIAS REPORTADAS'), findsNothing);
      final incidenciasRepo = container.read(incidenciasRepositoryProvider);
      expect(incidenciasRepo.todasLasIncidencias.first.estado.name, 'resuelta');
    },
  );
}
