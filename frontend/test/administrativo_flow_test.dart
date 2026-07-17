import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/data/mock_operaciones_repository.dart';
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
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

Future<void> _loginComoAdmin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Acceso de administrador'));
  await tester.tap(find.text('Acceso de administrador'));
  await tester.pumpAndSettle();

  final dialog = find.byType(Dialog);
  await tester.enterText(
      find.descendant(
          of: dialog, matching: find.widgetWithText(TextFormField, 'Usuario del administrador')),
      'admin1');
  await tester.enterText(
      find.descendant(of: dialog, matching: find.widgetWithText(TextFormField, '••••••••')),
      'admin1234');
  await tester.tap(find.descendant(of: dialog, matching: find.text('Ingresar')));
  await tester.pumpAndSettle();
}

/// Cambia de sección en el shell del panel admin (sidebar o bottom nav,
/// según el ancho de pantalla del test — la etiqueta es la misma en
/// ambos).
Future<void> _irASeccion(WidgetTester tester, String etiqueta) async {
  await tester.tap(find.text(etiqueta));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'admin ve el detalle de un chofer con su historial de vehículos usados, '
      'y edita el tope de un vehículo desde el catálogo', (tester) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);

    // El chofer usa el vehículo sembrado (veh-1) para que aparezca en su
    // historial — el vehículo ya no es un dato fijo del perfil.
    final chofer1 = container.read(authRepositoryProvider).listarChoferes().firstWhere(
          (c) => c.usuario == 'chofer1',
        );
    final vehiculo1 = container.read(vehiculosRepositoryProvider).todos.first;
    await tester.runAsync(() async {
      await container.read(operacionesRepositoryProvider).enviarSolicitud(
            choferId: chofer1.id,
            vehiculo: vehiculo1,
            litrosSolicitados: 100,
          );
    });

    await pumpTestApp(tester, container: container, scrollBehavior: _SinEstiramientoDeScroll());
    await _loginComoAdmin(tester);

    expect(find.text('Panel administrativo'), findsOneWidget);

    await _irASeccion(tester, 'Choferes');
    expect(find.text('Juan Pérez'), findsOneWidget);

    await tester.tap(find.text('Juan Pérez'));
    await tester.pumpAndSettle();

    expect(find.text('Vehículos usados'), findsOneWidget);
    expect(find.textContaining(vehiculo1.identificador), findsWidgets);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await _irASeccion(tester, 'Vehículos');
    await tester.ensureVisible(find.text('Editar').first);
    await tester.tap(find.text('Editar').first);
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    final campoTope = find.descendant(
        of: dialog, matching: find.widgetWithText(TextFormField, 'Tope semanal (déjalo vacío si aún no se asigna)'));
    await tester.enterText(campoTope, '700');
    await tester.tap(find.descendant(of: dialog, matching: find.text('Guardar')));
    await tester.pumpAndSettle();

    expect(find.text('Tope: 700 L/semana'), findsOneWidget);
  });

  testWidgets('admin actualiza el precio de un combustible', (tester) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await pumpTestApp(tester, container: container, scrollBehavior: _SinEstiramientoDeScroll());
    await _loginComoAdmin(tester);
    await _irASeccion(tester, 'Finanzas');

    await tester.ensureVisible(find.text('Diésel'));
    expect(find.text('Diésel'), findsOneWidget);
    expect(find.text('\$24.50 / L'), findsOneWidget);

    final botonEditar = find.widgetWithIcon(IconButton, Icons.edit_outlined).first;
    await tester.ensureVisible(botonEditar);
    await tester.tap(botonEditar);
    await tester.pumpAndSettle();

    final dialog = find.byType(Dialog);
    final campoPrecio = find.descendant(
        of: dialog, matching: find.widgetWithText(TextFormField, 'Precio por litro'));
    await tester.enterText(campoPrecio, '26.90');
    await tester.tap(find.descendant(of: dialog, matching: find.text('Guardar')));
    await tester.pumpAndSettle();

    expect(find.text('\$26.90 / L'), findsOneWidget);
  });

  testWidgets('los chips de filtro muestran solo las solicitudes del estado elegido',
      (tester) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);

    final chofer1 = container.read(authRepositoryProvider).listarChoferes().firstWhere(
          (c) => c.usuario == 'chofer1',
        );
    final vehiculo1 = container.read(vehiculosRepositoryProvider).todos.first;
    final repo = container.read(operacionesRepositoryProvider);
    // chofer1 no tiene historial todavía, así que ambas quedan pendientes
    // de revisión manual (no se auto-aprueban) — ver
    // MockOperacionesRepository.enviarSolicitud.
    // runAsync: enviarSolicitud usa Future.delayed real; sin esto, el
    // reloj falso de testWidgets nunca avanza y el await se cuelga.
    await tester.runAsync(() async {
      await repo.enviarSolicitud(choferId: chofer1.id, vehiculo: vehiculo1, litrosSolicitados: 100);
      await repo.enviarSolicitud(choferId: chofer1.id, vehiculo: vehiculo1, litrosSolicitados: 50);
    });

    await pumpTestApp(tester, container: container, scrollBehavior: _SinEstiramientoDeScroll());
    await _loginComoAdmin(tester);

    expect(find.byType(EstadoSolicitudBadge), findsNWidgets(2));

    // El admin resuelve una como aprobada y la otra como rechazada.
    final botonesRevisar = find.text('Revisar');
    await tester.ensureVisible(botonesRevisar.first);
    await tester.tap(botonesRevisar.first);
    await tester.pumpAndSettle();
    var dialog = find.byType(Dialog);
    await tester.tap(find.descendant(of: dialog, matching: find.textContaining('Autorizar ')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Revisar'));
    await tester.tap(find.text('Revisar'));
    await tester.pumpAndSettle();
    dialog = find.byType(Dialog);
    await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)), 'No hay presupuesto.');
    await tester.tap(find.descendant(of: dialog, matching: find.text('Rechazar')));
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
  });

  testWidgets('la pestaña Concentrado se ve sin datos (sin cargas registradas)', (tester) async {
    final container = makeTestContainer();
    addTearDown(container.dispose);
    await pumpTestApp(tester, container: container, scrollBehavior: _SinEstiramientoDeScroll());
    await _loginComoAdmin(tester);
    await _irASeccion(tester, 'Concentrado');

    expect(find.text('Concentrado de cargas'), findsOneWidget);
    expect(find.text('No hay cargas registradas en este periodo.'), findsOneWidget);
  });

  // Igual que con la tabla (ver más abajo): renderizar ConcentradoTab con
  // datos dispara el bug del entorno de test, así que el CSV se prueba
  // como función pura contra FilaConcentrado, sin montar el árbol de
  // widgets.
  test('construirCsvConcentrado arma encabezado, filas y totales', () {
    final chofer = const Perfil(
      id: 'chofer-1',
      usuario: 'chofer1',
      nombreCompleto: 'Juan Pérez',
      correo: 'chofer1@example.com',
      edad: 30,
      rol: RolUsuario.chofer,
    );
    const vehiculo = Vehiculo(
      id: 'veh-1',
      tipoUnidad: 'Camión',
      modelo: 'Chevrolet NPR 2020',
      identificador: 'ABC-123',
      tipoCombustible: 'Diésel',
      topeSemanal: 500,
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
    );

    final csv = construirCsvConcentrado([fila], totalLitros: 40, totalImporte: 980);

    expect(csv, contains('Juan Pérez'));
    expect(csv, contains('Chevrolet NPR 2020'));
    expect(csv, contains('ABC-123'));
    expect(csv, contains('40.0'));
    expect(csv, contains('10.0'));
    expect(csv, contains('980.00'));
    expect(csv, contains('TOTALES'));
    expect(csv, contains('Pendiente')); // no se adjuntó foto de ticket
  });

  test('nombreArchivoConcentrado arma un nombre único con marca de tiempo', () {
    final nombre = nombreArchivoConcentrado(DateTime(2026, 7, 15, 14, 5, 9));
    expect(nombre, 'concentrado_20260715_140509.csv');
  });

  // La tabla del Concentrado (scroll horizontal anidado dentro de uno
  // vertical) dispara un bug conocido del entorno de widget test de
  // Flutter ("!semantics.parentDataDirty") ajeno a esta app — se prueba
  // la unión de datos (Carga + CierreDia + rendimiento) directo contra el
  // repositorio, sin renderizar el árbol de widgets.
  test('el repositorio une una Carga con su CierreDia y calcula el rendimiento', () async {
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
  });
}
