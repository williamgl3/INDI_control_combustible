import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/unidad_form_data.dart';
import 'package:indi_combustible/data/api_client.dart';
import 'package:indi_combustible/models/vehiculo.dart';
import 'package:indi_combustible/screens/administrativo/editar_vehiculo_dialog.dart';
import 'package:indi_combustible/theme/app_theme.dart';

import 'mocks/mock_vehiculos_repository.dart';

void main() {
  test('validadores cubren modelo, identificadores e intervalo', () {
    expect(UnidadFormValidators.modelo(' '), isNotNull);
    expect(UnidadFormValidators.modelo('Camión'), isNull);
    expect(UnidadFormValidators.identificadores('', ''), isNotNull);
    expect(UnidadFormValidators.identificadores('AA-000-A', ''), isNull);
    expect(UnidadFormValidators.identificadores('', 'EQ-001'), isNull);
    expect(UnidadFormValidators.identificadores('AA-000-A', 'EQ-001'), isNull);
    expect(UnidadFormValidators.intervalo(''), isNull);
    expect(UnidadFormValidators.intervalo('0'), isNotNull);
    expect(UnidadFormValidators.intervalo('-1'), isNotNull);
    expect(UnidadFormValidators.intervalo('250'), isNull);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final size in [const Size(320, 700), const Size(1200, 900)]) {
      testWidgets('formulario abre sin errores en $mode a ${size.width}px', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vehiculosRepositoryProvider.overrideWithValue(
                MockVehiculosRepository(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: mode,
              home: const Scaffold(body: EditarVehiculoDialog()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Agregar unidad'), findsOneWidget);
        expect(
          find.text('Ingresa el modelo o nombre de la unidad'),
          findsNothing,
        );
        expect(
          find.text('Captura las placas o el número económico'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
        expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      });
    }
  }

  testWidgets('muestra errores tras intentar guardar y soporta teclado', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vehiculosRepositoryProvider.overrideWithValue(
            MockVehiculosRepository(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const MediaQuery(
            data: MediaQueryData(
              size: Size(320, 700),
              viewInsets: EdgeInsets.only(bottom: 280),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(body: EditarVehiculoDialog()),
          ),
        ),
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pump();
    expect(
      find.text('Ingresa el modelo o nombre de la unidad'),
      findsOneWidget,
    );
    expect(
      find.text('Captura las placas o el número económico'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('un error del backend mantiene abierto el formulario', (
    tester,
  ) async {
    final repo = _RepositorioControlado(
      error: ApiException('No se pudo guardar'),
    );
    await _abrirDialogo(tester, repo);
    await _completarDatosMinimos(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Agregar'));
    await tester.pump();

    expect(repo.creaciones, 1);
    expect(find.text('No se pudo guardar'), findsOneWidget);
    expect(find.text('Agregar unidad'), findsOneWidget);
  });

  testWidgets('doble pulsación inicia una sola creación', (tester) async {
    final completer = Completer<Vehiculo>();
    final repo = _RepositorioControlado(pendiente: completer);
    await _abrirDialogo(tester, repo);
    await _completarDatosMinimos(tester);

    final agregar = find.widgetWithText(FilledButton, 'Agregar');
    await tester.tap(agregar);
    await tester.tap(agregar);
    await tester.pump();

    expect(repo.creaciones, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completer.complete(_unidadCreada);
    await tester.pumpAndSettle();
    expect(find.text('Agregar unidad'), findsNothing);
  });
}

Future<void> _abrirDialogo(
  WidgetTester tester,
  MockVehiculosRepository repo,
) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => EditarVehiculoDialog.show(context),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pumpAndSettle();
}

Future<void> _completarDatosMinimos(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextFormField, 'Modelo o nombre'),
    'Unidad de prueba',
  );
  await tester.enterText(
    find.widgetWithText(TextField, 'Número económico'),
    'TEST-001',
  );
  await tester.tap(find.byType(DropdownButtonFormField<String?>));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Diésel').last);
  await tester.pumpAndSettle();
}

const _unidadCreada = Vehiculo(
  id: 'creada',
  tipoUnidad: 'Vehículo',
  placas: null,
  numeroEconomico: 'TEST-001',
  tipoCombustible: 'Diésel',
  modelo: 'Unidad de prueba',
  intervaloServicio: 5000,
);

class _RepositorioControlado extends MockVehiculosRepository {
  _RepositorioControlado({this.pendiente, this.error});

  final Completer<Vehiculo>? pendiente;
  final ApiException? error;
  int creaciones = 0;

  @override
  Future<Vehiculo> crear({
    required String tipoUnidad,
    String? placas,
    String? numeroEconomico,
    String? tipoCombustible,
    String? modelo,
    double? intervaloServicio,
    String? ubicacion,
    String? unidadPadreId,
    bool activo = true,
  }) {
    creaciones++;
    if (error != null) return Future.error(error!);
    return pendiente?.future ?? Future.value(_unidadCreada);
  }
}
