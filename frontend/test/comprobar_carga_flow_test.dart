import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';

import 'test_helpers.dart';

/// Abre el diálogo "toca para escribir" de un [StepperNumerico] (buscado
/// por su etiqueta) y captura el valor exacto, en vez de tocar +/- muchas
/// veces.
Future<void> _fijarStepper(
  WidgetTester tester,
  String etiqueta,
  String valor,
) async {
  final campo = find.byKey(Key('stepper-valor-$etiqueta'));
  await tester.ensureVisible(campo);
  await tester.tap(campo);
  await tester.pumpAndSettle();
  final dialog = find.byType(Dialog);
  await tester.enterText(
    find.descendant(of: dialog, matching: find.byType(TextField)),
    valor,
  );
  await tester.tap(find.descendant(of: dialog, matching: find.text('Listo')));
  await tester.pumpAndSettle();
}

/// Abre el selector "¿Qué vehículo vas a usar?" (ver SelectorVehiculo) y
/// elige la unidad sembrada en el mock por su etiqueta visible.
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
    'chofer registra su carga (con fotos) y luego cierra su día, viendo el rendimiento',
    (tester) async {
      final container = makeTestContainer();
      addTearDown(container.dispose);
      await pumpTestApp(tester, container: container);

      // Login como chofer1 (tope semanal 500L, ya viene precargado en el mock).
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

      // Solicitar carga. chofer1 no tiene historial todavía, así que queda
      // pendiente de revisión manual (no se auto-aprueba).
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Solicitar carga'));
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
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Listo'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Actividad'),
        'Actividad de prueba',
      );
      await tester.ensureVisible(find.text('Enviar solicitud'));
      await tester.tap(find.text('Enviar solicitud'));
      await tester.pumpAndSettle();

      expect(find.text('En revisión'), findsOneWidget);
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();

      // El admin la resuelve desde su propia sesión (esto también ejercita
      // RevisarSolicitudDialog de punta a punta). "Cerrar sesión" del
      // chofer ahora está en la pestaña Perfil del bottom nav.
      await tester.tap(find.text('Perfil'));
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

      // Sin sesión, la app aterriza en la pantalla de bienvenida.
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
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

      await tester.ensureVisible(find.text('Revisar'));
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      final revisionDialog = find.byType(Dialog);
      await tester.tap(
        find.descendant(
          of: revisionDialog,
          matching: find.widgetWithText(ElevatedButton, 'Autorizar 40 L'),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byTooltip('Cerrar sesión'));
      await tester.tap(find.byTooltip('Cerrar sesión'));
      await tester.pumpAndSettle();
      // Confirmación antes de cerrar sesión (ver ConfirmarCerrarSesionDialog)
      // — el panel admin ahora también la pide, igual que el de chofer.
      await tester.tap(
        find.descendant(
          of: find.byType(Dialog),
          matching: find.text('Cerrar sesión'),
        ),
      );
      await tester.pumpAndSettle();

      // Sin sesión, la app aterriza en la pantalla de bienvenida.
      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      // De vuelta como chofer1, en una sesión nueva.
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

      expect(find.text('Carga aprobada'), findsOneWidget);
      await tester.tap(find.text('Carga aprobada'));
      await tester.pumpAndSettle();

      // Registro 1: fotos + litros + km al cargar + gasolinera.
      await tester.tap(find.text('Foto del tablero (km al cargar)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Foto del ticket de la gasolinera'));
      await tester.pumpAndSettle();

      await _fijarStepper(tester, 'Litros cargados', '40');
      expect(find.textContaining('coincide'), findsOneWidget);

      await _fijarStepper(tester, 'Km al cargar (según el tablero)', '1000');
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Gasolinera'),
        'Pemex Obra Norte',
      );

      await tester.ensureVisible(find.text('Enviar comprobación'));
      await tester.tap(find.text('Enviar comprobación'));
      await tester.pumpAndSettle();

      // Diálogo de revisión de fotos antes de enviar (ConfirmarFotosDialog).
      await tester.ensureVisible(find.text('Confirmar y enviar'));
      await tester.tap(find.text('Confirmar y enviar'));
      await tester.pumpAndSettle();

      // De vuelta en /chofer, debe verse la invitación a cerrar el día, y
      // el recordatorio de "cerrar mi día" debe haber quedado programado.
      expect(find.text('¿Ya terminaste tu día?'), findsOneWidget);
      final recordatorios =
          container.read(recordatorioServiceProvider)
              as FakeRecordatorioService;
      expect(recordatorios.programados, hasLength(1));

      await tester.tap(find.text('¿Ya terminaste tu día?'));
      await tester.pumpAndSettle();

      // Registro 2: foto + km final.
      await tester.tap(find.text('Foto del tablero (km final)'));
      await tester.pumpAndSettle();
      await _fijarStepper(tester, 'Km final del día', '1400');

      final botonCerrarDia = find.widgetWithText(
        ElevatedButton,
        'Cerrar mi día',
      );
      await tester.ensureVisible(botonCerrarDia);
      await tester.tap(botonCerrarDia);
      await tester.pumpAndSettle();

      expect(find.text('Día cerrado'), findsOneWidget);
      expect(find.text('400 km recorridos'), findsOneWidget);
      expect(find.text('10.0 km/L'), findsOneWidget);
      // Ya se cerró el día, así que el recordatorio se cancela.
      expect(recordatorios.programados, isEmpty);
      expect(recordatorios.cancelados, hasLength(1));

      await tester.tap(find.text('Volver al inicio'));
      await tester.pumpAndSettle();

      // Ya no debe ofrecer cerrar el día de nuevo (esa carga ya quedó cerrada).
      expect(find.text('¿Ya terminaste tu día?'), findsNothing);
    },
  );
}
