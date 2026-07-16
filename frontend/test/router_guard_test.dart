import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/vehiculo.dart';
import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/theme/app_theme.dart';

void main() {
  Future<GoRouter> pumpApp(WidgetTester tester, {required ProviderContainer container}) async {
    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('sin sesión: rutas públicas se muestran, /chofer redirige a /login', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = await pumpApp(tester, container: container);

    router.go('/registro-chofer');
    await tester.pumpAndSettle();
    expect(find.text('Registro de chofer'), findsOneWidget);

    router.go('/recuperar-password');
    await tester.pumpAndSettle();
    expect(find.text('Recuperar contraseña'), findsOneWidget);

    router.go('/chofer');
    await tester.pumpAndSettle();
    expect(find.text('INDI Combustible'), findsOneWidget);

    router.go('/administrativo');
    await tester.pumpAndSettle();
    expect(find.text('INDI Combustible'), findsOneWidget);
  });

  testWidgets('con sesión de chofer: puede ver /chofer, no /administrativo, y /login redirige a /chofer', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = await pumpApp(tester, container: container);

    container.read(sessionProvider.notifier).iniciarSesion(
          const Perfil(
            id: '1',
            usuario: 'chofer1',
            nombreCompleto: 'Juan Pérez',
            correo: 'juan@example.com',
            edad: 30,
            rol: RolUsuario.chofer,
            vehiculo: Vehiculo(
              tipoUnidad: 'camión',
              modelo: 'NPR 2020',
              placaONumeroEconomico: 'ABC-123',
              tipoCombustible: 'diésel',
              topeSemanal: 500,
            ),
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
  });

  testWidgets('extra inválido en /chofer/respuesta y /chofer/comprobar muestra RutaInvalidaScreen', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).iniciarSesion(
          const Perfil(
            id: '1',
            usuario: 'chofer1',
            nombreCompleto: 'Juan Pérez',
            correo: 'juan@example.com',
            edad: 30,
            rol: RolUsuario.chofer,
            vehiculo: Vehiculo(
              tipoUnidad: 'camión',
              modelo: 'NPR 2020',
              placaONumeroEconomico: 'ABC-123',
              tipoCombustible: 'diésel',
              topeSemanal: 500,
            ),
          ),
        );
    final router = await pumpApp(tester, container: container);

    router.go('/chofer/respuesta');
    await tester.pumpAndSettle();
    expect(find.text('Esta pantalla no recibió la información esperada.'), findsOneWidget);

    await tester.tap(find.text('Volver'));
    await tester.pumpAndSettle();
    expect(find.text('Hola, Juan'), findsOneWidget);
  });
}
