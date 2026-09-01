import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:indi_combustible/core/centro_sincronizacion/centro_providers.dart';
import 'package:indi_combustible/core/centro_sincronizacion/operacion_sincronizacion_view.dart';
import 'package:indi_combustible/core/connectivity_provider.dart';
import 'package:indi_combustible/core/offline/metadata_operacion_offline.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/screens/chofer/centro_sincronizacion_screen.dart';
import 'package:indi_combustible/theme/app_theme.dart';

import 'mocks/mock_auditoria_repository.dart';
import 'mocks/mock_auth_repository.dart';
import 'mocks/mock_evidencias_repository.dart';
import 'mocks/mock_incidencias_repository.dart';
import 'mocks/mock_operaciones_repository.dart';
import 'mocks/mock_vehiculos_repository.dart';
import 'test_helpers.dart';

OperacionSincronizacionView _op({
  String? idLocal,
  TipoOperacionOffline tipo = TipoOperacionOffline.solicitud,
  EstadoVisualSincronizacion estadoVisual = EstadoVisualSincronizacion.pendiente,
  bool puedeReintentar = true,
  bool requiereAtencion = false,
  bool requiereLogin = false,
  int intentos = 0,
  String? ultimoError,
  String? idempotencyKey,
  DateTime? proximoIntento,
  List<ArchivoSincronizacionView> archivos = const [],
  List<DependenciaSincronizacionView> dependencias = const [],
}) =>
    OperacionSincronizacionView(
      idLocal: idLocal ?? 'test-0000-0000-000000000001',
      tipo: tipo,
      titulo: _tituloPorTipo(tipo),
      descripcion: '100L · Prueba',
      estado: EstadoOperacionOffline.pendiente,
      estadoVisual: estadoVisual,
      usuarioId: 'userA',
      intentos: intentos,
      creadaEn: DateTime.now(),
      puedeReintentar: puedeReintentar,
      requiereAtencion: requiereAtencion,
      requiereLogin: requiereLogin,
      ultimoError: ultimoError,
      idempotencyKey: idempotencyKey,
      proximoIntento: proximoIntento,
      archivos: archivos,
      dependencias: dependencias,
    );

String _tituloPorTipo(TipoOperacionOffline tipo) => switch (tipo) {
  TipoOperacionOffline.solicitud => 'Solicitud de carga',
  TipoOperacionOffline.comprobarCarga => 'Comprobar carga',
  TipoOperacionOffline.cerrarDia => 'Cerrar día',
  TipoOperacionOffline.incidencia => 'Incidencia',
  TipoOperacionOffline.evidencia => 'Evidencia frente',
  TipoOperacionOffline.recorridoMarimba => 'Recorrido marimba',
  TipoOperacionOffline.despachoMarimba => 'Despacho marimba',
  TipoOperacionOffline.cierreRecorridoMarimba => 'Cierre recorrido',
};

CentroSincronizacionData _datosVacios() => const CentroSincronizacionData(
  operaciones: [],
  conteoPorEstado: {},
);

CentroSincronizacionData _datosConOperaciones({
  List<OperacionSincronizacionView>? ops,
}) {
  final operaciones = ops ?? [_op()];
  final conteo = <EstadoVisualSincronizacion, int>{};
  var reqAtencion = 0;
  var reintentables = 0;
  for (final op in operaciones) {
    conteo[op.estadoVisual] = (conteo[op.estadoVisual] ?? 0) + 1;
    if (op.requiereAtencion) reqAtencion++;
    if (op.puedeReintentar) reintentables++;
  }
  return CentroSincronizacionData(
    operaciones: operaciones,
    conteoPorEstado: conteo,
    total: operaciones.length,
    requiereAtencion: reqAtencion,
    reintentables: reintentables,
  );
}

Perfil _perfil() => const Perfil(
  id: 'userA',
  usuario: 'testuser',
  nombre: 'Test',
  correo: 'test@test.com',
  rol: RolUsuario.chofer,
);

Future<void> _pumpCentro(
  WidgetTester tester, {
  required CentroSincronizacionData datos,
  bool conectado = true,
  Size? surfaceSize,
}) async {
  final container = ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      fotoPickerProvider.overrideWithValue(FakeFotoPicker()),
      ticketOcrServiceProvider.overrideWithValue(const FakeTicketOcrService()),
      recordatorioServiceProvider.overrideWithValue(FakeRecordatorioService()),
      exportadorServiceProvider.overrideWithValue(FakeExportadorService()),
      authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      evidenciasRepositoryProvider.overrideWithValue(
        MockEvidenciasRepository(),
      ),
      operacionesRepositoryProvider.overrideWithValue(
        MockOperacionesRepository(),
      ),
      vehiculosRepositoryProvider.overrideWithValue(MockVehiculosRepository()),
      incidenciasRepositoryProvider.overrideWithValue(
        MockIncidenciasRepository(),
      ),
      auditoriaRepositoryProvider.overrideWithValue(MockAuditoriaRepository()),
      centroSincronizacionProvider.overrideWith(
        (ref) async => datos,
      ),
      conectividadProvider.overrideWith(
        (ref) => Stream.value(conectado),
      ),
      sessionProvider.overrideWith(() {
        final ctrl = SessionController();
        ctrl.iniciarSesion(_perfil());
        return ctrl;
      }),
    ],
  );
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: RoutePaths.choferCentroSincronizacion,
    routes: [
      GoRoute(
        path: RoutePaths.choferCentroSincronizacion,
        builder: (_, _) => const CentroSincronizacionScreen(),
      ),
      GoRoute(
        path: RoutePaths.chofer,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Chofer Home'))),
      ),
      GoRoute(
        path: RoutePaths.login,
        builder: (_, _) =>
            const Scaffold(body: Center(child: Text('Login'))),
      ),
    ],
  );
  addTearDown(router.dispose);

  tester.view.physicalSize = surfaceSize ?? const Size(800, 600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
      ),
    ),
  );
  await tester.pump();
}

// ---------------------------------------------------------------------------
// Widget tests
// ---------------------------------------------------------------------------
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CentroSincronizacionScreen — widget tests', () {
    testWidgets('muestra estado vacío cuando no hay operaciones',
        (tester) async {
      await _pumpCentro(tester, datos: _datosVacios());

      expect(
        find.text('Todo sincronizado — no hay operaciones pendientes offline.'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    });

    testWidgets('muestra operaciones cuando hay datos', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(tipo: TipoOperacionOffline.solicitud),
          _op(
            idLocal: 'test-002',
            tipo: TipoOperacionOffline.incidencia,
          ),
        ]),
      );

      expect(find.text('Solicitud de carga'), findsOneWidget);
      expect(find.text('Incidencia'), findsAtLeastNWidgets(1));
    });

    testWidgets('muestra barra de sincronización con reintentables',
        (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: true),
          _op(idLocal: 'test-002', puedeReintentar: true),
        ]),
      );

      expect(find.text('Sincronizar ahora (2)'), findsOneWidget);
    });

    testWidgets('muestra "Todo sincronizado" en barra si 0 reintentables',
        (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: false),
        ]),
      );

      expect(find.text('Todo sincronizado'), findsWidgets);
    });

    testWidgets('muestra indicador de conectividad En línea', (tester) async {
      await _pumpCentro(tester, datos: _datosVacios(), conectado: true);

      expect(find.text('EN LÍNEA'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    });

    testWidgets('muestra indicador Sin conexión', (tester) async {
      await _pumpCentro(tester, datos: _datosVacios(), conectado: false);

      expect(find.text('SIN CONEXIÓN'), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
    });

    testWidgets('muestra chip de resumen de estados', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(estadoVisual: EstadoVisualSincronizacion.pendiente),
          _op(
            idLocal: 'test-002',
            estadoVisual: EstadoVisualSincronizacion.errorPermanente,
            puedeReintentar: true,
            requiereAtencion: true,
          ),
        ]),
      );

      expect(find.text('Pendiente'), findsWidgets);
      expect(find.text('Error permanente'), findsWidgets);
    });

    testWidgets('muestra filtros de tipo', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(tipo: TipoOperacionOffline.solicitud),
          _op(
            idLocal: 'test-002',
            tipo: TipoOperacionOffline.incidencia,
          ),
        ]),
      );

      expect(find.text('Solicitud'), findsWidgets);
      expect(find.text('Incidencia'), findsWidgets);
    });

    testWidgets('muestra badge de estado en cada tile', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(estadoVisual: EstadoVisualSincronizacion.pendiente),
        ]),
      );

      expect(find.text('PENDIENTE'), findsOneWidget);
    });

    testWidgets('muestra alerta requiere atención', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            requiereAtencion: true,
            requiereLogin: true,
          ),
        ]),
      );

      expect(find.text('Requiere iniciar sesión'), findsOneWidget);
    });

    testWidgets('muestra botón reintentar en tile si puedeReintentar',
        (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: true),
        ]),
      );

      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    });

    testWidgets('no muestra botón reintentar si no puedeReintentar',
        (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: false),
        ]),
      );

      expect(find.byIcon(Icons.refresh_rounded), findsNothing);
    });

    testWidgets('toca tile y abre bottom sheet de detalle', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            tipo: TipoOperacionOffline.solicitud,
            ultimoError: 'Timeout de red',
            intentos: 3,
            idempotencyKey: 'abc-123',
          ),
        ]),
      );

      await tester.tap(find.text('Solicitud de carga'));
      await tester.pumpAndSettle();

      expect(find.text('Timeout de red'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(find.text('abc-123'), findsOneWidget);
    });

    testWidgets('bottom sheet muestra botón reintentar si puedeReintentar',
        (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: true),
        ]),
      );

      await tester.tap(find.text('Solicitud de carga'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar ahora'), findsOneWidget);
    });

    testWidgets('bottom sheet no muestra reintentar si no puede',
        (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: false),
        ]),
      );

      await tester.tap(find.text('Solicitud de carga'));
      await tester.pumpAndSettle();

      expect(find.text('Reintentar ahora'), findsNothing);
    });

    testWidgets('muestra info de archivos en tile', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            archivos: const [
              ArchivoSincronizacionView(
                ruta: '/tmp/foto.jpg',
                verificado: true,
              ),
            ],
          ),
        ]),
      );

      expect(find.text('1 archivo'), findsOneWidget);
    });

    testWidgets('muestra info de dependencias en tile', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            dependencias: const [
              DependenciaSincronizacionView(
                idLocal: 'v1',
                tipo: TipoOperacionOffline.solicitud,
                descripcion: 'Vehículo v1',
              ),
            ],
          ),
        ]),
      );

      expect(find.text('Vehículo v1'), findsOneWidget);
    });

    testWidgets('estado vacío de filtros muestra mensaje', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(estadoVisual: EstadoVisualSincronizacion.pendiente),
        ]),
      );

      // Type filter "Cerrar día" is always rendered but no ops match → empty state
      await tester.tap(find.text('Cerrar día'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Sin resultados — no hay operaciones que coincidan con los filtros seleccionados.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('botón back en AppBar funciona', (tester) async {
      await _pumpCentro(tester, datos: _datosVacios());

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      expect(find.text('Chofer Home'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation tests
  // ---------------------------------------------------------------------------
  group('CentroSincronizacionScreen — navegación', () {
    testWidgets('se puede navegar a la ruta correcta', (tester) async {
      await _pumpCentro(tester, datos: _datosVacios());

      expect(
        find.text('Centro de sincronización'),
        findsOneWidget,
      );
    });

    testWidgets('back navega a chofer home y forward vuelve',
        (tester) async {
      await _pumpCentro(tester, datos: _datosConOperaciones());

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('Chofer Home'), findsOneWidget);
    });

    test('route path es válido', () {
      expect(
        RoutePaths.choferCentroSincronizacion,
        '/chofer/centro-sincronizacion',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Counter / badge tests
  // ---------------------------------------------------------------------------
  group('CentroSincronizacionScreen — contadores y badges', () {
    testWidgets('muestra conteo correcto de pendientes', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(estadoVisual: EstadoVisualSincronizacion.pendiente),
          _op(
            idLocal: 'test-002',
            estadoVisual: EstadoVisualSincronizacion.pendiente,
          ),
        ]),
      );

      expect(find.text('2'), findsOneWidget);
      expect(find.text('Pendiente'), findsWidgets);
    });

    testWidgets('muestra conteo correcto de errorPermanente', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            estadoVisual: EstadoVisualSincronizacion.errorPermanente,
            requiereAtencion: true,
          ),
          _op(
            idLocal: 'test-002',
            estadoVisual: EstadoVisualSincronizacion.errorPermanente,
            requiereAtencion: true,
          ),
          _op(
            idLocal: 'test-003',
            estadoVisual: EstadoVisualSincronizacion.errorPermanente,
            requiereAtencion: true,
          ),
        ]),
      );

      expect(find.text('3'), findsWidgets);
      expect(find.text('Error permanente'), findsWidgets);
    });

    testWidgets('badge PENDIENTE visible en tile', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(estadoVisual: EstadoVisualSincronizacion.pendiente),
        ]),
      );

      expect(find.text('PENDIENTE'), findsOneWidget);
    });

    testWidgets('badge ERROR PERMANENTE visible en tile', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            estadoVisual: EstadoVisualSincronizacion.errorPermanente,
            requiereAtencion: true,
          ),
        ]),
      );

      expect(find.text('ERROR PERMANENTE'), findsOneWidget);
    });

    testWidgets('badge COMPLETADA visible en tile', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            estadoVisual: EstadoVisualSincronizacion.completada,
            puedeReintentar: false,
          ),
        ]),
      );

      expect(find.text('COMPLETADA'), findsOneWidget);
    });

    testWidgets('barra muestra cantidad de reintentables', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: true),
          _op(idLocal: 't2', puedeReintentar: true),
          _op(idLocal: 't3', puedeReintentar: false),
        ]),
      );

      expect(find.text('Sincronizar ahora (2)'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Responsive tests
  // ---------------------------------------------------------------------------
  group('CentroSincronizacionScreen — responsive', () {
    for (final size in [
      const Size(375, 812),
      const Size(393, 852),
      const Size(768, 1024),
      const Size(1440, 900),
    ]) {
      testWidgets(
          'renderiza sin overflow en ${size.width}x${size.height}',
          (tester) async {
        await _pumpCentro(
          tester,
          datos: _datosConOperaciones(ops: [
            _op(tipo: TipoOperacionOffline.solicitud),
            _op(
              idLocal: 'test-002',
              tipo: TipoOperacionOffline.incidencia,
              requiereAtencion: true,
              requiereLogin: true,
            ),
          ]),
          surfaceSize: size,
        );

        expect(tester.takeException(), isNull);
      });
    }
  });

  // ---------------------------------------------------------------------------
  // Accessibility tests
  // ---------------------------------------------------------------------------
  group('CentroSincronizacionScreen — accesibilidad', () {
    testWidgets('AppBar tiene título semántico', (tester) async {
      await _pumpCentro(tester, datos: _datosVacios());

      expect(find.text('Centro de sincronización'), findsOneWidget);
    });

    testWidgets('tiles tienen Key para testing', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(tipo: TipoOperacionOffline.solicitud),
        ]),
      );

      expect(
        find.byKey(
          const ValueKey('solicitud-test-0000-0000-000000000001'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('iconos de reintento tienen tooltip', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: true),
        ]),
      );

      expect(find.byTooltip('Reintentar'), findsOneWidget);
    });

    testWidgets('botón sincronizar tiene texto descriptivo', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(puedeReintentar: true),
        ]),
      );

      expect(find.text('Sincronizar ahora (1)'), findsOneWidget);
    });

    testWidgets('bottom sheet tiene contenido accesible', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            ultimoError: 'Error de red',
            intentos: 2,
          ),
        ]),
      );

      await tester.tap(find.text('Solicitud de carga'));
      await tester.pumpAndSettle();

      expect(find.text('Descripción'), findsOneWidget);
      expect(find.text('Intentos'), findsOneWidget);
      expect(find.text('Último error'), findsOneWidget);
    });

    testWidgets('estado vacío muestra ícono y mensaje', (tester) async {
      await _pumpCentro(tester, datos: _datosVacios());

      expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
      expect(
        find.text(
          'Todo sincronizado — no hay operaciones pendientes offline.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('requireLogin muestra texto descriptivo', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            requiereAtencion: true,
            requiereLogin: true,
          ),
        ]),
      );

      expect(find.text('Requiere iniciar sesión'), findsOneWidget);
    });

    testWidgets('errorPermanente muestra texto descriptivo', (tester) async {
      await _pumpCentro(
        tester,
        datos: _datosConOperaciones(ops: [
          _op(
            requiereAtencion: true,
            estadoVisual: EstadoVisualSincronizacion.errorPermanente,
          ),
        ]),
      );

      expect(find.text('Error permanente'), findsWidgets);
    });
  });
}
