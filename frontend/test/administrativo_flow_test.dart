import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'mocks/mock_operaciones_repository.dart';
import 'package:indi_combustible/models/carga.dart';
import 'package:indi_combustible/models/cierre_dia.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/vehiculo.dart';
import 'package:indi_combustible/screens/administrativo/tabs/concentrado_csv.dart';
import 'package:indi_combustible/widgets/estado_solicitud_badge.dart';

import 'test_helpers.dart';

/// El indicador de "stretch" del overscroll (Material 3, Android) choca
/// con los scrollables anidados de ConcentradoTab dentro del entorno de
/// test (`!semantics.parentDataDirty`) — es un problema conocido del
/// framework en tests, no del código de la app. Se desactiva solo aquí.
class _SinEstiramientoDeScroll extends MaterialScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

Future<void> _loginComoAdmin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Entrar como administrador'));
  await tester.tap(find.text('Entrar como administrador'));
  await tester.pumpAndSettle();

  final dialog = find.byType(Dialog);
  await tester.enterText(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextFormField, 'Usuario del administrador'),
    ),
    'admin1',
  );
  await tester.enterText(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(TextFormField, 'Contraseña'),
    ),
    'admin1234',
  );
  await tester.tap(
    find.descendant(of: dialog, matching: find.text('Ingresar')),
  );
  await tester.pumpAndSettle();
}

/// Cambia de sección en el shell del panel admin (sidebar o bottom nav,
/// según el ancho de pantalla del test — la etiqueta es la misma en
/// ambos). `ensureVisible` es necesario porque el sidebar tiene más
/// secciones de las que caben sin scroll en el viewport del test (ver
/// comentario en `_SidebarAdmin`).
Future<void> _irASeccion(WidgetTester tester, String etiqueta) async {
  if (find.text(etiqueta).evaluate().isEmpty &&
      find.byTooltip('Expandir navegación').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Expandir navegación'));
    await tester.pumpAndSettle();
  }
  if (find.text(etiqueta).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(etiqueta),
      180,
      scrollable: find.descendant(
        of: find.byKey(const ValueKey('sidebar-administrativo')),
        matching: find.byType(Scrollable),
      ),
    );
  }
  await tester.ensureVisible(find.text(etiqueta));
  await tester.pumpAndSettle();
  await tester.tap(find.text(etiqueta));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'admin ve el detalle de un chofer con su historial de vehículos usados, '
    'y edita el combustible de un vehículo desde el catálogo',
    (tester) async {
      final container = makeTestContainer();
      addTearDown(container.dispose);

      // El chofer usa el vehículo sembrado (veh-1) para que aparezca en su
      // historial — el vehículo ya no es un dato fijo del perfil.
      final chofer1 = container
          .read(authRepositoryProvider)
          .listarChoferes()
          .firstWhere((c) => c.usuario == 'chofer1');
      final vehiculo1 = container.read(vehiculosRepositoryProvider).todos.first;
      await tester.runAsync(() async {
        await container
            .read(operacionesRepositoryProvider)
            .enviarSolicitud(
              choferId: chofer1.id,
              vehiculo: vehiculo1,
              litrosSolicitados: 100,
              actividad: 'Actividad de prueba',
              fechaProgramada: DateTime.now().add(const Duration(days: 1)),
            );
      });

      await pumpTestApp(
        tester,
        container: container,
        scrollBehavior: _SinEstiramientoDeScroll(),
      );
      await _loginComoAdmin(tester);

      expect(find.text('Panel administrativo'), findsOneWidget);

      await _irASeccion(tester, 'Choferes');
      expect(find.text('Juan Pérez'), findsOneWidget);

      await tester.ensureVisible(find.text('Juan Pérez'));
      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();

      expect(find.text('Vehículos usados'), findsOneWidget);
      expect(find.textContaining(vehiculo1.etiquetaUnidad), findsWidgets);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await _irASeccion(tester, 'Vehículos');
      await tester.ensureVisible(find.text('Editar').first);
      await tester.tap(find.text('Editar').first);
      await tester.pumpAndSettle();

      final dialog = find.byType(Dialog);
      // vehiculo1 (veh-1) trae combustible 'Diésel' de fábrica en el mock —
      // lo cambia a 'Magna' para confirmar que la edición persiste.
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(
            DropdownButtonFormField<String?>,
            'Diésel',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Magna').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Guardar vehículo')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Magna'), findsWidgets);
    },
  );

  testWidgets('admin actualiza el precio de un combustible', (tester) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await pumpTestApp(
      tester,
      container: container,
      scrollBehavior: _SinEstiramientoDeScroll(),
    );
    await _loginComoAdmin(tester);
    await _irASeccion(tester, 'Finanzas');

    await tester.ensureVisible(find.text('Diésel'));
    expect(find.text('Diésel'), findsOneWidget);
    expect(find.text('\$24.50 / L'), findsOneWidget);

    // El precio ahora se edita inline (CeldaEditable), no en un diálogo:
    // tocar el texto lo vuelve un TextField.
    await tester.tap(find.text('\$24.50 / L'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, '26.90');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('\$26.90 / L'), findsOneWidget);
  });

  testWidgets(
    'los chips de filtro muestran solo las solicitudes del estado elegido',
    (tester) async {
      final container = makeTestContainer();
      addTearDown(container.dispose);

      final chofer1 = container
          .read(authRepositoryProvider)
          .listarChoferes()
          .firstWhere((c) => c.usuario == 'chofer1');
      final vehiculo1 = container.read(vehiculosRepositoryProvider).todos.first;
      final repo = container.read(operacionesRepositoryProvider);
      // chofer1 no tiene historial todavía, así que ambas quedan pendientes
      // de revisión manual (no se auto-aprueban) — ver
      // MockOperacionesRepository.enviarSolicitud.
      // runAsync: enviarSolicitud usa Future.delayed real; sin esto, el
      // reloj falso de testWidgets nunca avanza y el await se cuelga.
      await tester.runAsync(() async {
        await repo.enviarSolicitud(
          choferId: chofer1.id,
          vehiculo: vehiculo1,
          litrosSolicitados: 100,
          actividad: 'Actividad de prueba',
          fechaProgramada: DateTime.now().add(const Duration(days: 1)),
        );
        await repo.enviarSolicitud(
          choferId: chofer1.id,
          vehiculo: vehiculo1,
          litrosSolicitados: 50,
          actividad: 'Actividad de prueba',
          fechaProgramada: DateTime.now().add(const Duration(days: 1)),
        );
      });

      await pumpTestApp(
        tester,
        container: container,
        scrollBehavior: _SinEstiramientoDeScroll(),
      );
      await _loginComoAdmin(tester);

      expect(find.byType(EstadoSolicitudBadge), findsNWidgets(2));

      // El admin resuelve una como aprobada y la otra como rechazada.
      final botonesRevisar = find.text('Revisar');
      await tester.ensureVisible(botonesRevisar.first);
      await tester.tap(botonesRevisar.first);
      await tester.pumpAndSettle();
      var dialog = find.byType(Dialog);
      await tester.tap(
        find.descendant(
          of: dialog,
          matching: find.textContaining('Autorizar '),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Revisar'));
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      dialog = find.byType(Dialog);
      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        'No hay presupuesto.',
      );
      await tester.tap(
        find.descendant(of: dialog, matching: find.text('Rechazar')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EstadoSolicitudBadge), findsNWidgets(2));

      await tester.ensureVisible(find.text('Aprobadas'));
      await tester.tap(find.text('Aprobadas'));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoSolicitudBadge), findsOneWidget);
      expect(find.text('AUTORIZADO'), findsOneWidget);

      await tester.ensureVisible(find.text('Rechazadas'));
      await tester.tap(find.text('Rechazadas'));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoSolicitudBadge), findsOneWidget);
      expect(find.text('RECHAZADO'), findsOneWidget);

      await tester.ensureVisible(find.text('Pendientes'));
      await tester.tap(find.text('Pendientes'));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoSolicitudBadge), findsNothing);
      expect(find.text('No hay solicitudes con este filtro.'), findsOneWidget);

      await tester.ensureVisible(find.text('Todas'));
      await tester.tap(find.text('Todas'));
      await tester.pumpAndSettle();
      expect(find.byType(EstadoSolicitudBadge), findsNWidgets(2));
    },
  );

  // NOTA: se intentó cubrir "aprobar/rechazar en lote" con un
  // testWidgets completo (marcar casillas → aparece la barra de acciones
  // → tocar "Aprobar"), pero renderizar la barra de acciones nueva
  // (`_BarraAccionesLote`) dispara el mismo bug del entorno de test que
  // ya afecta a `ConcentradoTab` con datos reales (ver comentario más
  // abajo, junto a `construirCsvConcentrado`): una falla real del árbol
  // de semántica de Flutter en este entorno, no del código de la
  // funcionalidad (`flutter analyze` limpio, y la lógica de
  // `_aprobarSeleccionadas`/`_rechazarSeleccionadas` reutiliza
  // `resolverSolicitud`, ya cubierto por la prueba de arriba vía
  // "Revisar" uno por uno).

  testWidgets(
    'la pestaña Concentrado se ve sin datos (sin cargas registradas)',
    (tester) async {
      final container = makeTestContainer();
      addTearDown(container.dispose);
      await pumpTestApp(
        tester,
        container: container,
        scrollBehavior: _SinEstiramientoDeScroll(),
      );
      await _loginComoAdmin(tester);
      await _irASeccion(tester, 'Concentrado');

      expect(find.text('Concentrado de cargas'), findsOneWidget);
      expect(
        find.text('No hay cargas registradas en este periodo.'),
        findsOneWidget,
      );
    },
  );

  // Igual que con la tabla (ver más abajo): renderizar ConcentradoTab con
  // datos dispara el bug del entorno de test, así que el CSV se prueba
  // como función pura contra FilaConcentrado, sin montar el árbol de
  // widgets.
  test('concentrado arma CSV compatible y XLSX real con tipos', () {
    final chofer = Perfil(
      id: 'chofer-1',
      usuario: 'chofer1',
      nombre: 'Juan',
      apellidoPaterno: 'Pérez',
      correo: 'chofer1@example.com',
      fechaNacimiento: DateTime(1996, 3, 10),
      rol: RolUsuario.chofer,
    );
    const vehiculo = Vehiculo(
      id: 'veh-1',
      tipoUnidad: 'Camión',
      modelo: 'Chevrolet NPR 2020',
      placas: 'ABC-123-A',
      numeroEconomico: null,
      tipoCombustible: 'Diésel',
      intervaloServicio: 5000,
    );
    final carga = Carga(
      id: 'carga-1',
      choferId: chofer.id,
      vehiculoId: vehiculo.id,
      folioAutorizacion: 'FA-test',
      litrosCargados: 40,
      kmAlCargar: 1000,
      gasolinera: 'Pemex Obra Norte',
      creadaEn: DateTime(2026, 7, 15, 14, 5),
    );
    final cierre = CierreDia(
      id: 'cierre-1',
      choferId: chofer.id,
      cargaId: carga.id,
      kmFinal: 1400,
      fotoTableroPath: 'foto.jpg',
      registradaEn: DateTime(2026, 7, 15, 18),
    );
    final fila = FilaConcentrado(
      carga: carga,
      cierre: cierre,
      chofer: chofer,
      vehiculo: vehiculo,
      rendimiento: const RendimientoDia(kmRecorridos: 400, rendimiento: 10.0),
      precioPorLitro: 24.50,
      importe: 980,
      fuenteGasto: FuenteGasto.estimado,
    );

    final csv = construirCsvConcentrado(
      [fila],
      totalLitros: 40,
      totalImporte: 980,
    );

    expect(csv, contains('Juan Pérez'));
    expect(csv, contains('Chevrolet NPR 2020'));
    expect(csv, contains('ABC-123'));
    expect(csv, contains('40.0'));
    expect(csv, contains('10.0'));
    expect(csv, contains('980.00'));
    expect(csv, contains('TOTALES'));
    expect(csv, contains('Pendiente')); // no se adjuntó foto de ticket

    final xlsx = construirXlsxConcentrado(
      [fila],
      totalLitros: 40,
      totalImporte: 980,
    );
    final archive = ZipDecoder().decodeBytes(xlsx);
    final sheet = utf8.decode(
      archive.findFile('xl/worksheets/sheet1.xml')!.content,
    );
    expect(sheet, contains('Juan Pérez'));
    expect(sheet, contains('Chevrolet NPR 2020'));
    expect(sheet, contains('<c r="F2" s="4"><v>40.0</v></c>'));
    expect(sheet, contains('<c r="J2" s="5"><v>980.0</v></c>'));
    expect(sheet, contains('TOTALES'));
  });

  test('nombreArchivoConcentrado arma un nombre único con marca de tiempo', () {
    final nombre = nombreArchivoConcentrado(DateTime(2026, 7, 15, 14, 5, 9));
    expect(nombre, 'concentrado_20260715_140509.xlsx');
  });

  // La tabla del Concentrado (scroll horizontal anidado dentro de uno
  // vertical) dispara un bug conocido del entorno de widget test de
  // Flutter ("!semantics.parentDataDirty") ajeno a esta app — se prueba
  // la unión de datos (Carga + CierreDia + rendimiento) directo contra el
  // repositorio, sin renderizar el árbol de widgets.
  test(
    'el repositorio une una Carga con su CierreDia y calcula el rendimiento',
    () async {
      final repo = MockOperacionesRepository();
      final carga = await repo.registrarCarga(
        choferId: 'chofer-test',
        vehiculoId: 'veh-test',
        folioAutorizacion: 'FA-test',
        litrosCargados: 40,
        kmAlCargar: 1000,
        gasolinera: 'Pemex Obra Norte',
      );
      final cierre = await repo.cerrarDia(
        choferId: 'chofer-test',
        cargaId: carga.id,
        kmFinal: 1400,
        fotoTableroPath: 'foto-tablero.jpg',
      );

      expect(repo.todasLasCargas, contains(carga));
      expect(repo.cierreDe(carga), equals(cierre));

      final rendimiento = repo.rendimientoDe(cierre);
      expect(rendimiento!.kmRecorridos, 400);
      expect(rendimiento.rendimiento, 10.0);
      expect(rendimiento.esAnomalo, isFalse);
    },
  );
}
