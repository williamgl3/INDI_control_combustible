import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/data/auth_repository.dart';
import 'package:indi_combustible/models/perfil.dart';

import 'mocks/mock_auth_repository.dart';
import 'test_helpers.dart';

Future<void> _login(
  WidgetTester tester, {
  String usuario = 'admin1',
  String password = 'admin1234',
}) async {
  await tester.ensureVisible(find.text('Entrar como administrador'));
  await tester.tap(find.text('Entrar como administrador'));
  await tester.pumpAndSettle();
  final d = find.byType(Dialog);
  await tester.enterText(
    find.descendant(
      of: d,
      matching: find.widgetWithText(TextFormField, 'Usuario del administrador'),
    ),
    usuario,
  );
  await tester.enterText(
    find.descendant(
      of: d,
      matching: find.widgetWithText(TextFormField, 'Contraseña'),
    ),
    password,
  );
  await tester.tap(find.descendant(of: d, matching: find.text('Ingresar')));
  await tester.pumpAndSettle();
}

Future<void> _choferes(WidgetTester tester) async {
  if (find.text('Choferes').evaluate().isEmpty &&
      find.byTooltip('Expandir navegación').evaluate().isNotEmpty) {
    await tester.tap(find.byTooltip('Expandir navegación'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Choferes').last);
  await tester.pumpAndSettle();
}

Finder _menu(String id) => find.byKey(ValueKey('acciones-$id'));

void main() {
  testWidgets(
    'la vista excluye cuentas administrativas y permite buscar correo',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = _RepoMixto();
      final c = makeTestContainer(
        overridesExtra: [authRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(c.dispose);
      await pumpTestApp(tester, container: c);
      await _login(tester);
      await _choferes(tester);
      expect(find.text('Juan Pérez'), findsOneWidget);
      expect(find.text('Administrativo Mezclado'), findsNothing);
      await tester.enterText(
        find.widgetWithText(
          TextField,
          'Buscar por nombre, apellidos, usuario o correo',
        ),
        'chofer1@example.com',
      );
      await tester.pump();
      expect(find.text('Juan Pérez'), findsOneWidget);
    },
  );

  testWidgets('desactivar exige motivo y actualiza solo la fila', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = makeTestContainer();
    addTearDown(c.dispose);
    await pumpTestApp(tester, container: c);
    await _login(tester);
    await _choferes(tester);
    final p = c.read(authRepositoryProvider).listarChoferes().first;
    await tester.tap(_menu(p.id));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Desactivar'));
    await tester.pumpAndSettle();
    expect(find.text('Motivo obligatorio'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Motivo obligatorio'),
      'Cuenta temporalmente suspendida',
    );
    await tester.tap(find.text('Desactivar').last);
    await tester.pumpAndSettle();
    expect(find.text('INACTIVO'), findsOneWidget);
  });

  testWidgets(
    'administrativo no ve eliminación y reset no muestra contraseñas',
    (tester) async {
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = makeTestContainer();
      addTearDown(c.dispose);
      await pumpTestApp(tester, container: c);
      await _login(tester);
      await _choferes(tester);
      final p = c.read(authRepositoryProvider).listarChoferes().first;
      await tester.tap(_menu(p.id));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar definitivamente'), findsNothing);
      await tester.tap(find.text('Restablecer contraseña'));
      await tester.pumpAndSettle();
      expect(find.text('Contraseña nueva'), findsNothing);
      expect(find.text('Motivo'), findsOneWidget);
    },
  );

  testWidgets('superadmin ve eliminación solo en cuenta inactiva', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = _RepoInactivo();
    final c = makeTestContainer(
      overridesExtra: [authRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(c.dispose);
    await pumpTestApp(tester, container: c);
    await _login(tester, usuario: 'superadmin1', password: 'superadmin1234');
    await _choferes(tester);
    final p = repo.listarChoferes().first;
    await tester.tap(_menu(p.id));
    await tester.pumpAndSettle();
    expect(find.text('Eliminar definitivamente'), findsOneWidget);
  });
}

class _RepoMixto extends MockAuthRepository {
  @override
  List<Perfil> listarChoferes() => [
    ...super.listarChoferes(),
    const Perfil(
      id: 'admin-mezclado',
      usuario: 'admin.mezclado',
      nombre: 'Administrativo',
      apellidoPaterno: 'Mezclado',
      correo: 'admin@example.com',
      rol: RolUsuario.administrativo,
    ),
  ];
}

class _RepoInactivo extends MockAuthRepository {
  _RepoInactivo();
  @override
  List<Perfil> listarChoferes() =>
      super.listarChoferes().map((p) => p.copyWith(activo: false)).toList();
  @override
  Future<PaginaChoferes> cargarChoferes({
    String buscar = '',
    String estado = 'todos',
    int pagina = 1,
    int limite = 25,
  }) async => (
    datos: listarChoferes(),
    pagina: 1,
    limite: 25,
    total: 1,
    totalPaginas: 1,
  );
}
