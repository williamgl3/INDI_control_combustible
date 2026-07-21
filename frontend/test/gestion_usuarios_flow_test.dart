import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/data/auth_repository.dart';
import 'package:indi_combustible/data/mock_auth_repository.dart';
import 'package:indi_combustible/models/perfil.dart';

import 'test_helpers.dart';

/// El menú de acciones de cada fila en `ChoferesTab` lleva una
/// `ValueKey('acciones-<id>')` — se usa esto en vez de `find.byTooltip`
/// porque, con varias filas o SDKs de Flutter que duplican el nodo
/// interno del tooltip, ese finder resulta ambiguo.
Finder _accionesDe(String usuarioId) =>
    find.byKey(ValueKey('acciones-$usuarioId'));

/// Réplica del helper de `administrativo_flow_test.dart` — inicia sesión
/// como el admin de prueba (`admin1`) para poder llegar a las pestañas
/// del panel administrativo.
Future<void> _loginComoAdmin(WidgetTester tester) async {
  await tester.ensureVisible(find.text('Acceso de administrador'));
  await tester.tap(find.text('Acceso de administrador'));
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

void main() {
  testWidgets(
    'desactivar y reactivar un chofer desde el menú de acciones actualiza el badge',
    (tester) async {
      // Con 8 secciones en el sidebar admin, el tamaño lógico por
      // defecto de flutter_test (800x600) ya no alcanza para mostrar
      // todas sin recortar la última — se agranda a un tamaño de
      // escritorio, igual que en `reportar_incidencia_flow_test.dart`.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = makeTestContainer();
      addTearDown(container.dispose);
      await pumpTestApp(tester, container: container);
      await _loginComoAdmin(tester);
      await _irASeccion(tester, 'Choferes');

      expect(find.text('INACTIVO'), findsNothing);

      final chofer1Id = container
          .read(authRepositoryProvider)
          .listarChoferes()
          .first
          .id;

      await tester.tap(_accionesDe(chofer1Id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();
      // Confirmación (ConfirmarAccionDialog).
      await tester.tap(find.text('Desactivar').last);
      await tester.pumpAndSettle();

      expect(find.text('INACTIVO'), findsOneWidget);
      expect(
        container.read(authRepositoryProvider).listarChoferes().first.activo,
        isFalse,
      );

      await tester.tap(_accionesDe(chofer1Id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reactivar'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reactivar').last);
      await tester.pumpAndSettle();

      expect(find.text('INACTIVO'), findsNothing);
      expect(
        container.read(authRepositoryProvider).listarChoferes().first.activo,
        isTrue,
      );
    },
  );

  testWidgets(
    'resetear la contraseña de un chofer permite iniciar sesión con la nueva y no con la anterior',
    (tester) async {
      // Con 8 secciones en el sidebar admin, el tamaño lógico por
      // defecto de flutter_test (800x600) ya no alcanza para mostrar
      // todas sin recortar la última — se agranda a un tamaño de
      // escritorio, igual que en `reportar_incidencia_flow_test.dart`.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = makeTestContainer();
      addTearDown(container.dispose);
      await pumpTestApp(tester, container: container);
      await _loginComoAdmin(tester);
      await _irASeccion(tester, 'Choferes');

      final chofer1 = container
          .read(authRepositoryProvider)
          .listarChoferes()
          .first;

      await tester.tap(_accionesDe(chofer1.id));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Resetear contraseña'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña nueva'),
        'passwordNueva123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña nueva'),
        'passwordNueva123',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      // El diálogo se cierra tras guardar con éxito.
      expect(find.byType(Dialog), findsNothing);

      // runAsync: login() usa Future.delayed real; sin esto, el timer no
      // avanza dentro de la zona de fake async del test y el await se
      // queda colgado para siempre (ver administrativo_flow_test.dart).
      await tester.runAsync(() async {
        await expectLater(
          container
              .read(authRepositoryProvider)
              .login(usuario: chofer1.usuario, password: 'chofer123'),
          throwsA(isA<AuthException>()),
        );
        final resultado = await container
            .read(authRepositoryProvider)
            .login(usuario: chofer1.usuario, password: 'passwordNueva123');
        expect(resultado.perfil.usuario, chofer1.usuario);
      });
    },
  );

  testWidgets(
    'crear administrador da de alta un usuario que puede iniciar sesión',
    (tester) async {
      // Con 8 secciones en el sidebar admin, el tamaño lógico por
      // defecto de flutter_test (800x600) ya no alcanza para mostrar
      // todas sin recortar la última — se agranda a un tamaño de
      // escritorio, igual que en `reportar_incidencia_flow_test.dart`.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final container = makeTestContainer();
      addTearDown(container.dispose);
      await pumpTestApp(tester, container: container);
      await _loginComoAdmin(tester);
      await _irASeccion(tester, 'Choferes');

      await tester.tap(find.text('Crear administrador'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Beto Nuevo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Usuario'),
        'beto.nuevo',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'beto.nuevo@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'password123',
      );
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);

      // runAsync: mismo motivo que en la prueba de resetear contraseña.
      await tester.runAsync(() async {
        final resultado = await container
            .read(authRepositoryProvider)
            .login(usuario: 'beto.nuevo', password: 'password123');
        expect(resultado.perfil.esAdministrativo, isTrue);
      });
    },
  );

  testWidgets(
    'el menú de acciones no ofrece Desactivar para el usuario en sesión actual',
    (tester) async {
      // Con 8 secciones en el sidebar admin, el tamaño lógico por
      // defecto de flutter_test (800x600) ya no alcanza para mostrar
      // todas sin recortar la última — se agranda a un tamaño de
      // escritorio, igual que en `reportar_incidencia_flow_test.dart`.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // El directorio hoy solo lista choferes (rol chofer) — el propio
      // admin en sesión nunca aparece ahí, así que la protección de
      // "no desactivarse a sí mismo" no tiene forma de fallar todavía.
      // Para ejercitarla de cara al contrato ("el backend también puede
      // traer usuarios con rol administrativo"), se usa un repo fake que
      // agrega al admin de la sesión actual a esa misma lista — sin tocar
      // sessionProvider directamente, para no disparar el guard de rutas
      // (que saca a cualquier no-administrativo de /administrativo).
      final container = makeTestContainer(
        overridesExtra: [
          authRepositoryProvider.overrideWithValue(
            _AuthRepositoryConAdminEnDirectorio(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await pumpTestApp(tester, container: container);
      await _loginComoAdmin(tester);
      await _irASeccion(tester, 'Choferes');

      expect(find.text('Ana Torres'), findsWidgets);

      await tester.tap(_accionesDe('mock-admin-1'));
      await tester.pumpAndSettle();

      expect(find.text('Resetear contraseña'), findsOneWidget);
      expect(find.text('Desactivar'), findsNothing);
    },
  );
}

/// Variante de [MockAuthRepository] cuyo directorio ([listarChoferes])
/// también incluye al propio admin de prueba (`admin1`) — simula el
/// escenario real que protege "no puede desactivarse a sí mismo": el
/// admin viendo su propia fila en un directorio con roles mixtos.
class _AuthRepositoryConAdminEnDirectorio extends MockAuthRepository {
  @override
  List<Perfil> listarChoferes() {
    return [
      ...super.listarChoferes(),
      Perfil(
        id: 'mock-admin-1',
        usuario: 'admin1',
        nombre: 'Ana',
        apellidoPaterno: 'Torres',
        correo: 'admin1@example.com',
        fechaNacimiento: DateTime(1991, 8, 22),
        rol: RolUsuario.administrativo,
      ),
    ];
  }
}
