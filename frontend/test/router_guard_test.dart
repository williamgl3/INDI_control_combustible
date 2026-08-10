import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/theme/app_theme.dart';
import 'mocks/mock_vehiculos_repository.dart';

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
    return router;
  }

  testWidgets(
    'sin sesión: rutas públicas se muestran, /chofer redirige a /login',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = await pumpApp(tester, container: container);

      router.go('/registro-chofer');
      await tester.pumpAndSettle();
      expect(find.text('Regístrate'), findsOneWidget);

      router.go('/recuperar-password');
      await tester.pumpAndSettle();
      expect(find.text('Recuperar contraseña'), findsOneWidget);

      router.go('/chofer');
      await tester.pumpAndSettle();
      expect(find.text('INDI Combustible'), findsOneWidget);

      router.go('/administrativo');
      await tester.pumpAndSettle();
      expect(find.text('INDI Combustible'), findsOneWidget);
    },
  );

  testWidgets('chofer no entra por deep link a recorridos de supervisor', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .iniciarSesion(
          const Perfil(
            id: '1',
            usuario: 'chofer1',
            nombre: 'Juan',
            correo: 'juan@example.com',
            rol: RolUsuario.chofer,
          ),
        );
    final router = await pumpApp(tester, container: container);
    router.go('/chofer/recorrido-marimba');
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/chofer');
  });

  testWidgets('supervisor entra a tipo de operación y ve granel', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .iniciarSesion(
          const Perfil(
            id: '2',
            usuario: 'supervisor1',
            nombre: 'Supervisión',
            correo: 'supervisor@example.com',
            rol: RolUsuario.supervisor,
          ),
        );
    final router = await pumpApp(tester, container: container);
    router.go('/chofer/tipo-operacion');
    await tester.pumpAndSettle();
    expect(find.text('Cargar la marimba'), findsOneWidget);
    expect(find.text('Registrar despacho'), findsOneWidget);
  });

  testWidgets('rutas semánticas sobreviven deep link y respetan el rol', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        vehiculosRepositoryProvider.overrideWithValue(
          MockVehiculosRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .iniciarSesion(
          const Perfil(
            id: '1',
            usuario: 'chofer1',
            nombre: 'Juan',
            correo: 'juan@example.com',
            rol: RolUsuario.chofer,
          ),
        );
    final router = await pumpApp(tester, container: container);

    router.go('/chofer/solicitar/vehiculo');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/chofer/solicitar/vehiculo',
    );

    router.go('/chofer/solicitar');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/chofer/tipo-operacion',
    );

    router.go('/chofer/solicitar/inexistente');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/chofer/tipo-operacion',
    );

    router.go('/chofer/solicitar/granel');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/chofer/tipo-operacion',
    );
  });

  testWidgets('supervisor conserva granel en entrada directa y refresh', (
    tester,
  ) async {
    final repo = MockVehiculosRepository();
    final container = ProviderContainer(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .iniciarSesion(
          const Perfil(
            id: '2',
            usuario: 'supervisor1',
            nombre: 'Supervisión',
            correo: 'supervisor@example.com',
            rol: RolUsuario.supervisor,
          ),
        );
    final router = await pumpApp(tester, container: container);
    router.go('/chofer/solicitar/granel');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/chofer/solicitar/granel',
    );
    router.go(router.routeInformationProvider.value.uri.toString());
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/chofer/solicitar/granel',
    );
  });

  testWidgets('regreso desde solicitud sin historial usa fallback seguro', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        vehiculosRepositoryProvider.overrideWithValue(
          MockVehiculosRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(sessionProvider.notifier)
        .iniciarSesion(
          const Perfil(
            id: '1',
            usuario: 'chofer1',
            nombre: 'Juan',
            correo: 'juan@example.com',
            rol: RolUsuario.chofer,
          ),
        );
    final router = await pumpApp(tester, container: container);
    router.go('/chofer/solicitar/vehiculo');
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/chofer');
  });

  testWidgets(
    'con sesión de chofer: puede ver /chofer, no /administrativo, y /login redirige a /chofer',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = await pumpApp(tester, container: container);

      container
          .read(sessionProvider.notifier)
          .iniciarSesion(
            Perfil(
              id: '1',
              usuario: 'chofer1',
              nombre: 'Juan',
              apellidoPaterno: 'Pérez',
              correo: 'juan@example.com',
              fechaNacimiento: DateTime(1996, 3, 10),
              rol: RolUsuario.chofer,
            ),
          );
      await tester.pumpAndSettle();

      router.go('/chofer');
      await tester.pumpAndSettle();
      expect(find.text('Hola, Juan'), findsOneWidget);

      router.go('/administrativo');
      await tester.pumpAndSettle();
      expect(find.text('Hola, Juan'), findsOneWidget);

      router.go('/login');
      await tester.pumpAndSettle();
      expect(find.text('Hola, Juan'), findsOneWidget);

      // Sub-rutas de /administrativo también deben quedar bloqueadas para un
      // chofer, no solo la ruta exacta.
      router.go('/administrativo/chofer');
      await tester.pumpAndSettle();
      expect(find.text('Hola, Juan'), findsOneWidget);
    },
  );

  testWidgets(
    'extra inválido en /chofer/respuesta y /chofer/comprobar muestra RutaInvalidaScreen',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container
          .read(sessionProvider.notifier)
          .iniciarSesion(
            Perfil(
              id: '1',
              usuario: 'chofer1',
              nombre: 'Juan',
              apellidoPaterno: 'Pérez',
              correo: 'juan@example.com',
              fechaNacimiento: DateTime(1996, 3, 10),
              rol: RolUsuario.chofer,
            ),
          );
      final router = await pumpApp(tester, container: container);

      router.go('/chofer/respuesta');
      await tester.pumpAndSettle();
      expect(
        find.text('Esta pantalla no recibió la información esperada.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Volver'));
      await tester.pumpAndSettle();
      expect(find.text('Hola, Juan'), findsOneWidget);
    },
  );
}
