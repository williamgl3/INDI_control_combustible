import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/catalogos_vehiculo.dart';
import 'package:indi_combustible/models/vehiculo.dart';
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
      tipoUnidad: 'Pipa',
      placas: 'PIP-001',
      numeroEconomico: 'P-1',
      tipoCombustible: 'Diésel',
      modelo: 'Pipa operativa',
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

  Future<void> montar(
    WidgetTester tester, {
    bool Function(Vehiculo)? filtroUnidad,
  }) async {
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SelectorVehiculo(
              vehiculoSeleccionado: null,
              onSeleccionar: (_) {},
              filtroUnidad: filtroUnidad,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('granel incluye una Pipa activa y excluye otras categorías', (
    tester,
  ) async {
    await montar(
      tester,
      filtroUnidad: (unidad) => esUnidadGranel(unidad.tipoUnidad),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(find.textContaining('P-1'), findsOneWidget);
    expect(find.textContaining('ABC-123-A'), findsNothing);
    expect(find.textContaining('EHO-336'), findsNothing);
  });

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

  testWidgets('buscar sin guiones ("PL0762") igual encuentra "PL-0762-C"', (
    tester,
  ) async {
    await montar(tester);
    await tester.enterText(find.byType(TextField), 'PL0762');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();

    expect(find.textContaining('PL-0762-C'), findsOneWidget);
    expect(find.textContaining('PL-0760-C'), findsNothing);
  });

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
      expect(
        find.text('Agregar vehículo que no está en la lista'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
      expect(find.textContaining('NEW'), findsNothing);
      expect(find.textContaining('🆕'), findsNothing);

      await tester.tap(find.text('Agregar vehículo que no está en la lista'));
      await tester.pumpAndSettle();
      expect(find.text('Vehículo nuevo'), findsOneWidget);
    },
  );
}
