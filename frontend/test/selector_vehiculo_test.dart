import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/selector_vehiculo.dart';

import 'mocks/mock_vehiculos_repository.dart';

/// Cubre PASO 5: con el catálogo real de ~96 unidades, la búsqueda del
/// selector del chofer debe encontrar por placa O número económico O
/// modelo, insensible a mayúsculas y a que el chofer escriba o no los
/// guiones — son justo los 3 casos que se discutieron explícitamente.
void main() {
  late MockVehiculosRepository repo;
  late ProviderContainer container;

  setUp(() async {
    repo = MockVehiculosRepository();
    // El mock ya trae 1 vehículo sembrado (ABC-123-A) — se agregan los
    // que hacen falta para superar el umbral de 7 unidades que activa
    // la caja de búsqueda, y para cubrir los 3 casos de la discusión.
    await repo.crear(
      tipoUnidad: 'Maquinaria',
      numeroEconomico: 'EHO-336-082',
      tipoCombustible: 'Diésel',
      modelo: 'Excavadora 336',
    );
    await repo.crear(
      tipoUnidad: 'Maquinaria',
      numeroEconomico: 'EHO-336-083',
      tipoCombustible: 'Diésel',
      modelo: 'Excavadora 336',
    );
    await repo.crear(
      tipoUnidad: 'Vehículo',
      placas: 'PL-0760-C',
      tipoCombustible: 'Magna',
      modelo: 'NISSAN NP300',
    );
    await repo.crear(
      tipoUnidad: 'Vehículo',
      placas: 'PL-0762-C',
      tipoCombustible: 'Magna',
      modelo: 'NISSAN NP300',
    );
    await repo.crear(
      tipoUnidad: 'Vehículo',
      placas: 'RK-4556-B',
      tipoCombustible: 'Diésel',
      modelo: 'TOYOTA HILUX',
    );
    await repo.crear(
      tipoUnidad: 'Vehículo',
      placas: 'RN-8563-B',
      tipoCombustible: 'Magna',
      modelo: 'TOYOTA HILUX',
    );
    // 2 más solo-Vehículo, para que el escenario con `filtroTipoUnidad:
    // 'Vehículo'` también supere el umbral de 7 y muestre la caja de
    // búsqueda (si no, esa prueba se queda sin `TextField` que tocar).
    await repo.crear(
      tipoUnidad: 'Vehículo',
      placas: 'PJ-6567-C',
      tipoCombustible: 'Magna',
      modelo: 'NISSAN FRONTIER',
    );
    await repo.crear(
      tipoUnidad: 'Vehículo',
      placas: 'MNC-002-A',
      tipoCombustible: 'Magna',
      modelo: 'NISSAN FRONTIER',
    );
    container = ProviderContainer(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
    );
  });

  tearDown(() => container.dispose());

  Future<void> montar(WidgetTester tester) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SelectorVehiculo(
              vehiculoSeleccionado: null,
              onSeleccionar: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('buscar "336" encuentra las excavadoras por económico', (
    tester,
  ) async {
    await montar(tester);
    await tester.enterText(find.byType(TextField), '336');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.textContaining('EHO-336-082'), findsOneWidget);
    expect(find.textContaining('EHO-336-083'), findsOneWidget);
    expect(find.textContaining('PL-0760-C'), findsNothing);
  });

  testWidgets('buscar "PL-07" encuentra las dos placas PL-076x-C', (
    tester,
  ) async {
    await montar(tester);
    await tester.enterText(find.byType(TextField), 'PL-07');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.textContaining('PL-0760-C'), findsOneWidget);
    expect(find.textContaining('PL-0762-C'), findsOneWidget);
    expect(find.textContaining('EHO-336'), findsNothing);
  });

  testWidgets(
    'buscar sin guiones ("PL0762") igual encuentra "PL-0762-C"',
    (tester) async {
      await montar(tester);
      await tester.enterText(find.byType(TextField), 'PL0762');
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.textContaining('PL-0762-C'), findsOneWidget);
      expect(find.textContaining('PL-0760-C'), findsNothing);
    },
  );

  testWidgets('buscar por modelo ("hilux") encuentra ambas Hilux', (
    tester,
  ) async {
    await montar(tester);
    await tester.enterText(find.byType(TextField), 'hilux');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.textContaining('RK-4556-B'), findsOneWidget);
    expect(find.textContaining('RN-8563-B'), findsOneWidget);
    expect(find.textContaining('PL-0760-C'), findsNothing);
  });

  testWidgets(
    'combinado con filtroTipoUnidad, la búsqueda no cruza categorías',
    (tester) async {
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: SelectorVehiculo(
                vehiculoSeleccionado: null,
                filtroTipoUnidad: 'Vehículo',
                onSeleccionar: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // "336" no existe entre los Vehículo (solo entre Maquinaria) — el
      // filtro de categoría debe ganar, la lista queda vacía salvo la
      // opción de "vehículo nuevo".
      await tester.enterText(find.byType(TextField), '336');
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();

      expect(find.textContaining('EHO-336'), findsNothing);
      expect(find.textContaining('Vehículo nuevo'), findsOneWidget);
    },
  );
}
