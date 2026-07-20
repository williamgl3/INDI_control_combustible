import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/models/carga.dart';
import 'package:indi_combustible/screens/administrativo/tabs/dashboard_calculo.dart';

Carga _carga(DateTime fecha, String vehiculoId, double litros) {
  return Carga(
    id: 'c-${fecha.millisecondsSinceEpoch}-$vehiculoId',
    choferId: 'chofer-1',
    vehiculoId: vehiculoId,
    folioAutorizacion: 'FA-1',
    litrosCargados: litros,
    kmAlCargar: 100,
    gasolinera: 'Gasolinera X',
    creadaEn: fecha,
  );
}

void main() {
  group('cargaDentroDePeriodo', () {
    final ahora = DateTime(2026, 7, 17); // viernes

    test('dia: solo el mismo día', () {
      expect(cargaDentroDePeriodo(DateTime(2026, 7, 17, 10), PeriodoDashboard.dia, ahora), isTrue);
      expect(cargaDentroDePeriodo(DateTime(2026, 7, 16, 10), PeriodoDashboard.dia, ahora), isFalse);
    });

    test('semana: lunes a domingo de esa semana', () {
      expect(
        cargaDentroDePeriodo(DateTime(2026, 7, 13), PeriodoDashboard.semana, ahora),
        isTrue,
      );
      expect(
        cargaDentroDePeriodo(DateTime(2026, 7, 20), PeriodoDashboard.semana, ahora),
        isFalse,
      );
    });

    test('mes: mismo año y mes', () {
      expect(cargaDentroDePeriodo(DateTime(2026, 7, 1), PeriodoDashboard.mes, ahora), isTrue);
      expect(cargaDentroDePeriodo(DateTime(2026, 6, 30), PeriodoDashboard.mes, ahora), isFalse);
    });

    test('anio: mismo año', () {
      expect(cargaDentroDePeriodo(DateTime(2026, 1, 1), PeriodoDashboard.anio, ahora), isTrue);
      expect(cargaDentroDePeriodo(DateTime(2025, 12, 31), PeriodoDashboard.anio, ahora), isFalse);
    });
  });

  test('agruparLitrosPorSubperiodo suma litros por día de la semana', () {
    final ahora = DateTime(2026, 7, 17); // viernes
    final cargas = [
      _carga(DateTime(2026, 7, 13), 'veh-1', 10), // lunes
      _carga(DateTime(2026, 7, 13), 'veh-1', 5), // lunes (se suma)
      _carga(DateTime(2026, 7, 17), 'veh-1', 20), // viernes
    ];

    final serie = agruparLitrosPorSubperiodo(cargas, PeriodoDashboard.semana, ahora);

    expect(serie, hasLength(7));
    expect(serie[0].etiqueta, 'Lun');
    expect(serie[0].litros, 15);
    expect(serie[4].etiqueta, 'Vie');
    expect(serie[4].litros, 20);
    expect(serie[1].litros, 0);
  });

  test('agruparLitrosPorSubperiodo para día devuelve lista vacía', () {
    final ahora = DateTime(2026, 7, 17);
    final serie = agruparLitrosPorSubperiodo(
      [_carga(ahora, 'veh-1', 10)],
      PeriodoDashboard.dia,
      ahora,
    );
    expect(serie, isEmpty);
  });

  test('desglosarPorCombustible calcula porcentajes correctos', () {
    final cargas = [
      _carga(DateTime(2026, 7, 17), 'veh-diesel', 75),
      _carga(DateTime(2026, 7, 17), 'veh-gas', 25),
    ];
    final mapa = {'veh-diesel': 'Diésel', 'veh-gas': 'Gasolina'};

    final desglose = desglosarPorCombustible(cargas, mapa);

    expect(desglose, hasLength(2));
    expect(desglose.first.tipo, 'Diésel');
    expect(desglose.first.porcentaje, 75);
    expect(desglose.last.tipo, 'Gasolina');
    expect(desglose.last.porcentaje, 25);
  });

  test('desglosarPorCombustible con lista vacía no divide por cero', () {
    expect(desglosarPorCombustible(const [], const {}), isEmpty);
  });
}
