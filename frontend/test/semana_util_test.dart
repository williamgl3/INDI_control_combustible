import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/semana_util.dart';

void main() {
  group('inicioDeSemana', () {
    test('un lunes devuelve el mismo día a medianoche', () {
      // 2026-07-13 es lunes.
      final resultado = inicioDeSemana(DateTime(2026, 7, 13, 15, 30));
      expect(resultado, DateTime(2026, 7, 13));
    });

    test('un domingo devuelve el lunes anterior', () {
      // 2026-07-19 es domingo (misma semana que el 13).
      final resultado = inicioDeSemana(DateTime(2026, 7, 19, 23, 59));
      expect(resultado, DateTime(2026, 7, 13));
    });

    test('un miércoles devuelve el lunes de esa semana', () {
      final resultado = inicioDeSemana(DateTime(2026, 7, 15, 8));
      expect(resultado, DateTime(2026, 7, 13));
    });
  });

  group('estaEnSemanaDe', () {
    final referencia = DateTime(2026, 7, 15, 12); // miércoles

    test('el lunes y el domingo de la misma semana cuentan', () {
      expect(estaEnSemanaDe(DateTime(2026, 7, 13), referencia), isTrue);
      expect(
        estaEnSemanaDe(DateTime(2026, 7, 19, 23, 59, 59), referencia),
        isTrue,
      );
    });

    test('el domingo anterior y el lunes siguiente NO cuentan', () {
      expect(
        estaEnSemanaDe(DateTime(2026, 7, 12, 23, 59, 59), referencia),
        isFalse,
      );
      expect(estaEnSemanaDe(DateTime(2026, 7, 20), referencia), isFalse);
    });
  });

  group('etiquetaRangoSemana', () {
    test('formatea el rango lunes-domingo', () {
      expect(etiquetaRangoSemana(DateTime(2026, 7, 15)), '13 al 19 jul');
    });
  });
}
