import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_storage.dart';
import 'package:indi_combustible/core/token_storage.dart';
import 'package:indi_combustible/data/mock_auditoria_repository.dart';
import 'package:indi_combustible/data/mock_auth_repository.dart';
import 'package:indi_combustible/data/mock_incidencias_repository.dart';
import 'package:indi_combustible/data/mock_operaciones_repository.dart';
import 'package:indi_combustible/data/mock_vehiculos_repository.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/theme/app_theme.dart';

/// [TokenStorage]/[SessionStorage] usan flutter_secure_storage, que
/// depende de canales de plataforma no disponibles en widget tests.
/// Estas fakes en memoria evitan que las pruebas cuelguen esperando esos
/// canales, sin cambiar el comportamiento observable de las pantallas.
class _FakeTokenStorage extends TokenStorage {
  String? _token;
  String? _refreshToken;

  @override
  Future<void> guardarToken(String token) async => _token = token;

  @override
  Future<String?> leerToken() async => _token;

  @override
  Future<void> borrarToken() async => _token = null;

  @override
  Future<void> guardarRefreshToken(String refreshToken) async =>
      _refreshToken = refreshToken;

  @override
  Future<String?> leerRefreshToken() async => _refreshToken;

  @override
  Future<void> borrarRefreshToken() async => _refreshToken = null;
}

class _FakeSessionStorage extends SessionStorage {
  Perfil? _perfil;

  @override
  Future<void> guardarPerfil(Perfil perfil) async => _perfil = perfil;

  @override
  Future<Perfil?> leerPerfil() async => _perfil;

  @override
  Future<void> borrarPerfil() async => _perfil = null;
}

ProviderContainer _makeContainer() {
  return ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(_FakeTokenStorage()),
      sessionStorageProvider.overrideWithValue(_FakeSessionStorage()),
      authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      operacionesRepositoryProvider.overrideWithValue(
        MockOperacionesRepository(),
      ),
      vehiculosRepositoryProvider.overrideWithValue(MockVehiculosRepository()),
      incidenciasRepositoryProvider.overrideWithValue(
        MockIncidenciasRepository(),
      ),
      auditoriaRepositoryProvider.overrideWithValue(
        MockAuditoriaRepository(),
      ),
    ],
  );
}

void main() {
  Future<GoRouter> pumpApp(
    WidgetTester tester, {
    required ProviderContainer container,
  }) async {
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // La ruta inicial ahora es la pantalla de bienvenida; estas pruebas
    // ejercitan el formulario de login, así que se navega directo a él.
    router.go(RoutePaths.login);
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('login con credenciales inválidas muestra error y no navega', (
    tester,
  ) async {
    final container = _makeContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container: container);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Usuario'),
      'usuarioinexistente',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Contraseña'),
      'passwordmalo',
    );
    await tester.ensureVisible(find.text('Ingresar'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();

    expect(find.text('Usuario o contraseña incorrectos.'), findsOneWidget);
    expect(find.text('Ingresar'), findsOneWidget);
  });

  testWidgets('login con credenciales mock válidas navega a /chofer', (
    tester,
  ) async {
    final container = _makeContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container: container);

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

    expect(find.text('Hola, Juan'), findsOneWidget);
  });

  testWidgets('acceso de administrador abre modal y navega a /administrativo', (
    tester,
  ) async {
    final container = _makeContainer();
    addTearDown(container.dispose);
    await pumpApp(tester, container: container);

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

    expect(find.text('Panel administrativo'), findsOneWidget);
  });

  testWidgets(
    'registro de chofer con datos válidos crea sesión y navega a /chofer',
    (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final router = await pumpApp(tester, container: container);

      router.go(RoutePaths.registroChofer);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nombre(s)'),
        'Luis',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Apellido paterno'),
        'Gómez',
      );
      await tester.ensureVisible(find.byIcon(Icons.calendar_today_outlined));
      await tester.tap(find.byIcon(Icons.calendar_today_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo'),
        'luis.gomez@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Usuario'),
        'luis.gomez',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'password123',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Confirmar contraseña'),
        'password123',
      );

      await tester.ensureVisible(find.text('Crear cuenta'));
      await tester.tap(find.text('Crear cuenta'));
      await tester.pumpAndSettle();

      expect(find.text('Hola, Luis'), findsOneWidget);
    },
  );

  testWidgets(
    'recuperar password con usuario existente muestra pantalla de confirmación',
    (tester) async {
      final container = _makeContainer();
      addTearDown(container.dispose);
      final router = await pumpApp(tester, container: container);

      router.go(RoutePaths.recuperarPassword);
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Usuario o correo'),
        'chofer1',
      );
      await tester.ensureVisible(find.text('Enviar instrucciones'));
      await tester.tap(find.text('Enviar instrucciones'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Si la cuenta existe, enviamos instrucciones para restablecer '
          'tu contraseña.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('Volver a iniciar sesión'));
      await tester.pumpAndSettle();
      expect(find.text('INDI Combustible'), findsOneWidget);
    },
  );

  testWidgets('recuperar password con usuario inexistente muestra error', (
    tester,
  ) async {
    final container = _makeContainer();
    addTearDown(container.dispose);
    final router = await pumpApp(tester, container: container);

    router.go(RoutePaths.recuperarPassword);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Usuario o correo'),
      'no-existe-nadie',
    );
    await tester.ensureVisible(find.text('Enviar instrucciones'));
    await tester.tap(find.text('Enviar instrucciones'));
    await tester.pumpAndSettle();

    expect(
      find.text('No encontramos una cuenta con ese usuario o correo.'),
      findsOneWidget,
    );
  });
}
