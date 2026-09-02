import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/models/vehiculo.dart';

void main() {
  Map<String, dynamic> contrato({
    String? placas = 'ABC-123',
    String? economico,
    Object? activo = false,
  }) => {
    'id': 'unidad-1',
    'tipoUnidad': economico == null ? 'Vehículo' : 'Maquinaria',
    'placas': placas,
    'numeroEconomico': economico,
    'tipoCombustible': 'Diésel',
    'modelo': 'Unidad de prueba',
    'intervaloServicio': 5000,
    'lecturaUltimoServicio': null,
    'fechaUltimoServicio': null,
    'activo': activo,
    'unidadPadreId': 'padre-1',
    'ubicacion': 'Frente A',
  };

  test('lee el contrato actualizado completo con placas', () {
    final unidad = Vehiculo.fromJson(contrato());
    expect(unidad.placas, 'ABC-123');
    expect(unidad.etiquetaUnidad, 'ABC-123');
    expect(unidad.activo, isFalse);
    expect(unidad.unidadPadreId, 'padre-1');
    expect(unidad.ubicacion, 'Frente A');
  });

  test('usa número económico como etiqueta cuando está disponible', () {
    final unidad = Vehiculo.fromJson(
      contrato(placas: null, economico: 'ECO-1'),
    );
    expect(unidad.numeroEconomico, 'ECO-1');
    expect(unidad.etiquetaUnidad, 'ECO-1');
  });

  test('acepta padre y ubicación opcionales', () {
    final json = contrato()..addAll({'unidadPadreId': null, 'ubicacion': null});
    final unidad = Vehiculo.fromJson(json);
    expect(unidad.unidadPadreId, isNull);
    expect(unidad.ubicacion, isNull);
  });

  test('rechaza de forma controlada un contrato sin identificador', () {
    expect(
      () => Vehiculo.fromJson(contrato(placas: null, economico: null)),
      throwsA(isA<FormatException>()),
    );
  });

  test('conserva activo true y false', () {
    expect(Vehiculo.fromJson(contrato(activo: true)).activo, isTrue);
    expect(Vehiculo.fromJson(contrato(activo: false)).activo, isFalse);
  });

  test('rechaza activo ausente', () {
    final json = contrato()..remove('activo');
    expect(() => Vehiculo.fromJson(json), throwsA(isA<FormatException>()));
  });

  test('rechaza activo null', () {
    expect(
      () => Vehiculo.fromJson(contrato(activo: null)),
      throwsA(isA<FormatException>()),
    );
  });

  test('rechaza activo con tipo inválido', () {
    for (final valor in ['true', 0, 1]) {
      expect(
        () => Vehiculo.fromJson(contrato(activo: valor)),
        throwsA(isA<FormatException>()),
      );
    }
  });

  test('acepta y conserva intervalo null', () {
    final unidad = Vehiculo.fromJson(contrato()..['intervaloServicio'] = null);
    expect(unidad.intervaloServicio, isNull);
    expect(unidad.toJson()['intervaloServicio'], isNull);
  });

  test('rechaza intervalo con tipo inválido o valor no finito', () {
    for (final valor in ['5000', double.infinity, double.nan]) {
      final json = contrato()..['intervaloServicio'] = valor;
      expect(() => Vehiculo.fromJson(json), throwsA(isA<FormatException>()));
    }
  });
}
