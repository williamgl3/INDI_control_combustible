import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/models/vehiculo.dart';
import 'package:indi_combustible/screens/administrativo/tabs/mantenimiento_calculo.dart';

void main() {
  const vehiculoBase = Vehiculo(
    id: 'veh-1',
    tipoUnidad: 'Vehículo',
    placas: 'ABC-123',
    numeroEconomico: null,
    tipoCombustible: 'Diésel',
    intervaloServicio: 5000,
  );

  test('sin historial ni servicio previo: estado sinDatos', () {
    final diagnostico = calcularMantenimiento(
      vehiculo: vehiculoBase,
      historial: const [],
      ahora: DateTime(2026, 7, 17),
    );

    expect(diagnostico.estado, EstadoMantenimiento.sinDatos);
    expect(diagnostico.lecturaActual, isNull);
    expect(diagnostico.fechaProyectada, isNull);
  });

  test('intervalo null: visible como noConfigurado y sin cálculos', () {
    final diagnostico = calcularMantenimiento(
      vehiculo: vehiculoBase.copyWith(intervaloServicio: null),
      historial: [(fecha: DateTime(2026, 7, 1), lectura: 1500)],
      ahora: DateTime(2026, 7, 17),
    );

    expect(diagnostico.estado, EstadoMantenimiento.noConfigurado);
    expect(diagnostico.usoDesdeServicio, isNull);
    expect(diagnostico.restante, isNull);
    expect(diagnostico.fechaProyectada, isNull);
  });

  test('intervalo cero heredado: noConfigurado, nunca próximo ni vencido', () {
    final diagnostico = calcularMantenimiento(
      vehiculo: vehiculoBase.copyWith(intervaloServicio: 0),
      historial: [(fecha: DateTime(2026, 7, 1), lectura: 9000)],
      ahora: DateTime(2026, 7, 17),
    );

    expect(diagnostico.estado, EstadoMantenimiento.noConfigurado);
    expect(diagnostico.restante, isNull);
  });

  test('uso bajo desde el último servicio: estado alDia', () {
    final vehiculo = vehiculoBase.copyWith(
      lecturaUltimoServicio: 1000,
      fechaUltimoServicio: DateTime(2026, 6, 1),
    );
    final diagnostico = calcularMantenimiento(
      vehiculo: vehiculo,
      historial: [(fecha: DateTime(2026, 7, 1), lectura: 1500)],
      ahora: DateTime(2026, 7, 17),
    );

    expect(diagnostico.estado, EstadoMantenimiento.alDia);
    expect(diagnostico.usoDesdeServicio, 500);
    expect(diagnostico.restante, 4500);
    expect(diagnostico.fechaProyectada, isNotNull);
  });

  test('uso cerca del intervalo (>=85%): estado proximo', () {
    final vehiculo = vehiculoBase.copyWith(
      lecturaUltimoServicio: 0,
      fechaUltimoServicio: DateTime(2026, 6, 1),
    );
    final diagnostico = calcularMantenimiento(
      vehiculo: vehiculo,
      historial: [(fecha: DateTime(2026, 7, 1), lectura: 4400)],
      ahora: DateTime(2026, 7, 17),
    );

    expect(diagnostico.estado, EstadoMantenimiento.proximo);
    expect(diagnostico.restante, 600);
  });

  test(
    'uso que ya rebasó el intervalo: estado vencido, sin fecha proyectada',
    () {
      final vehiculo = vehiculoBase.copyWith(
        lecturaUltimoServicio: 0,
        fechaUltimoServicio: DateTime(2026, 5, 1),
      );
      final diagnostico = calcularMantenimiento(
        vehiculo: vehiculo,
        historial: [(fecha: DateTime(2026, 7, 1), lectura: 6000)],
        ahora: DateTime(2026, 7, 17),
      );

      expect(diagnostico.estado, EstadoMantenimiento.vencido);
      expect(diagnostico.restante, lessThanOrEqualTo(0));
      expect(diagnostico.fechaProyectada, isNull);
    },
  );

  test(
    'sin servicio previo pero con historial: usa la primera lectura como base',
    () {
      final diagnostico = calcularMantenimiento(
        vehiculo: vehiculoBase,
        historial: [
          (fecha: DateTime(2026, 6, 1), lectura: 2000),
          (fecha: DateTime(2026, 7, 1), lectura: 2500),
        ],
        ahora: DateTime(2026, 7, 17),
      );

      expect(diagnostico.lecturaActual, 2500);
      expect(diagnostico.usoDesdeServicio, 500);
      expect(diagnostico.estado, EstadoMantenimiento.alDia);
    },
  );

  test(
    'construirCsvMantenimiento arma encabezado y una fila por diagnóstico',
    () {
      final diagnostico = calcularMantenimiento(
        vehiculo: vehiculoBase.copyWith(
          lecturaUltimoServicio: 1000,
          fechaUltimoServicio: DateTime(2026, 6, 1),
        ),
        historial: [(fecha: DateTime(2026, 7, 1), lectura: 1500)],
        ahora: DateTime(2026, 7, 17),
      );

      final csv = construirCsvMantenimiento([diagnostico]);
      final lineas = csv.split('\r\n');

      expect(lineas.first, contains('Unidad'));
      expect(lineas[1], contains('ABC-123'));
      expect(lineas[1], contains('Al día'));
    },
  );

  test('CSV representa null y cero heredado como No configurado', () {
    final diagnosticos = [null, 0.0]
        .map(
          (intervalo) => calcularMantenimiento(
            vehiculo: vehiculoBase.copyWith(intervaloServicio: intervalo),
            historial: const [],
            ahora: DateTime(2026, 7, 17),
          ),
        )
        .toList();

    final csv = construirCsvMantenimiento(diagnosticos);
    expect('No configurado'.allMatches(csv), hasLength(4));
    expect(csv, contains('No aplica'));
  });

  test('contador y filtro separan unidades no configuradas', () {
    final diagnosticos = [null, 0.0, 5000.0]
        .map(
          (intervalo) => calcularMantenimiento(
            vehiculo: vehiculoBase.copyWith(intervaloServicio: intervalo),
            historial: const [],
            ahora: DateTime(2026, 7, 17),
          ),
        )
        .toList();

    final resumen = resumirMantenimiento(diagnosticos);
    final noConfigurados = filtrarMantenimiento(
      diagnosticos,
      EstadoMantenimiento.noConfigurado,
    );
    expect(resumen.noConfigurados, 2);
    expect(noConfigurados, hasLength(2));
    expect(
      noConfigurados.every(
        (d) =>
            d.estado != EstadoMantenimiento.proximo &&
            d.estado != EstadoMantenimiento.vencido,
      ),
      isTrue,
    );
  });
}
