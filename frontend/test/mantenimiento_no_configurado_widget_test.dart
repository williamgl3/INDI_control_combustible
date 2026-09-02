import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/models/vehiculo.dart';
import 'package:indi_combustible/screens/administrativo/tabs/mantenimiento_tab.dart';
import 'package:indi_combustible/theme/app_theme.dart';

import 'mocks/mock_incidencias_repository.dart';
import 'mocks/mock_operaciones_repository.dart';
import 'mocks/mock_vehiculos_repository.dart';

class _CatalogoSinIntervalo extends MockVehiculosRepository {
  @override
  List<Vehiculo> get todos => const [
    Vehiculo(
      id: 'sin-intervalo',
      tipoUnidad: 'Vehículo',
      placas: 'TEST-001',
      numeroEconomico: null,
      tipoCombustible: 'Diésel',
      modelo: 'Unidad sin intervalo',
      intervaloServicio: null,
    ),
  ];
}

void main() {
  for (final caso in [
    (size: const Size(320, 800), mode: ThemeMode.light),
    (size: const Size(1200, 900), mode: ThemeMode.dark),
  ]) {
    testWidgets(
      'mantenimiento muestra No configurado a ${caso.size.width}px en ${caso.mode}',
      (tester) async {
        tester.view.physicalSize = caso.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              vehiculosRepositoryProvider.overrideWithValue(
                _CatalogoSinIntervalo(),
              ),
              operacionesRepositoryProvider.overrideWithValue(
                MockOperacionesRepository(),
              ),
              incidenciasRepositoryProvider.overrideWithValue(
                MockIncidenciasRepository(),
              ),
            ],
            child: MaterialApp(
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              themeMode: caso.mode,
              home: const Scaffold(body: MantenimientoTab()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sin configurar'), findsOneWidget);
        expect(find.textContaining('No configurado'), findsWidgets);
        expect(find.text('Configurar intervalo'), findsOneWidget);
        expect(find.textContaining('0 km'), findsNothing);
        expect(find.textContaining('0 h'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
