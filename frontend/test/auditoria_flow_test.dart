import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/data/auditoria_repository.dart';
import 'package:indi_combustible/models/registro_auditoria.dart';

import 'test_helpers.dart';

Future<void> _loginComoAdmin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Entrar como administrador'));
  await tester.tap(find.text('Entrar como administrador'));
  await tester.pumpAndSettle();

  final dialog = find.byType(Dialog);
  await tester.enterText(
    find.descendant(
      of: dialog,
      matching: find.widgetWithText(
        TextFormField,
        'Usuario del administrador',
      ),
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

Future<void> _irASeccion(WidgetTester tester, String etiqueta) async {
  await tester.ensureVisible(find.text(etiqueta));
  await tester.tap(find.text(etiqueta));
  await tester.pumpAndSettle();
}

/// Fake de paginación con un tamaño de página fijo (2), para poder probar
/// "cargar más" de forma determinista — a diferencia de
/// [MockAuditoriaRepository], que carga todos sus ejemplos de una vez si
/// caben en el límite por defecto (30).
class _FakeAuditoriaRepositoryPaginado implements AuditoriaRepository {
  final List<RegistroAuditoria> _todos = List.generate(
    5,
    (i) => RegistroAuditoria(
      id: 'reg-$i',
      usuarioId: 'admin-x',
      usuarioNombre: 'Admin de prueba',
      accion: 'editó',
      entidad: 'vehiculo',
      entidadId: 'veh-$i',
      detalle: 'Referencia veh-$i',
      creadoEn: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
    ),
  );

  List<RegistroAuditoria> _cargados = [];
  bool _sinMas = false;

  @override
  List<RegistroAuditoria> get registros => List.unmodifiable(_cargados);

  @override
  bool get sinMasRegistros => _sinMas;

  @override
  Future<void> cargarRegistros({int limit = 30}) async {
    _cargados = _todos.take(2).toList();
    _sinMas = _cargados.length >= _todos.length;
  }

  @override
  Future<void> cargarMasRegistros({int limit = 30}) async {
    final restantes = _todos.skip(_cargados.length).take(2).toList();
    _cargados = [..._cargados, ...restantes];
    _sinMas = _cargados.length >= _todos.length;
  }
}

void main() {
  testWidgets('la pestaña Auditoría muestra la actividad de ejemplo', (
    tester,
  ) async {
    // Con 8 secciones en el sidebar admin, el ancho/alto lógico por
    // defecto de flutter_test (800x600) ya no alcanza para mostrar la
    // última (Auditoría) sin recortarla — se agranda a un tamaño de
    // escritorio, igual que en `reportar_incidencia_flow_test.dart`.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = makeTestContainer();
    addTearDown(container.dispose);
    await pumpTestApp(tester, container: container);
    await _loginComoAdmin(tester);
    await _irASeccion(tester, 'Auditoría');

    expect(find.text('Ana Torres aprobó una solicitud'), findsOneWidget);
    expect(find.text('Cargar más'), findsNothing); // los 8 caben en un limit=30
  });

  testWidgets('Auditoría pagina con "Cargar más" hasta agotar los registros', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = makeTestContainer(
      overridesExtra: [
        auditoriaRepositoryProvider.overrideWithValue(
          _FakeAuditoriaRepositoryPaginado(),
        ),
      ],
    );
    addTearDown(container.dispose);
    await pumpTestApp(tester, container: container);
    await _loginComoAdmin(tester);
    await _irASeccion(tester, 'Auditoría');

    expect(find.textContaining('veh-0'), findsOneWidget);
    expect(find.textContaining('veh-1'), findsOneWidget);
    expect(find.textContaining('veh-2'), findsNothing);
    expect(find.text('Cargar más'), findsOneWidget);

    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();

    expect(find.textContaining('veh-2'), findsOneWidget);
    expect(find.textContaining('veh-3'), findsOneWidget);
    expect(find.text('Cargar más'), findsOneWidget);

    await tester.tap(find.text('Cargar más'));
    await tester.pumpAndSettle();

    expect(find.textContaining('veh-4'), findsOneWidget);
    expect(find.text('Cargar más'), findsNothing);
  });
}
