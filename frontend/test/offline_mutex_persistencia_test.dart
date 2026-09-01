import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/offline/mutex_persistencia.dart';

void main() {
  group('MutexPersistencia', () {
    test('ejecutafn de forma serializada', () async {
      final mutex = MutexPersistencia();
      final orden = <int>[];

      // Dos operaciones concurrentes deben ejecutarse en orden
      final f1 = mutex.run(() async {
        await Future.delayed(const Duration(milliseconds: 50));
        orden.add(1);
      });
      final f2 = mutex.run(() async {
        orden.add(2);
      });

      await Future.wait([f1, f2]);

      expect(orden, [1, 2]);
    });

    test('segunda operación espera a que la primera termine', () async {
      final mutex = MutexPersistencia();
      final resultados = <String>[];

      final f1 = mutex.run(() async {
        await Future.delayed(const Duration(milliseconds: 100));
        resultados.add('primera-listo');
        return 'ok';
      });
      final f2 = mutex.run(() async {
        resultados.add('segunda-listo');
        return 'ok';
      });

      final r1 = await f1;
      final r2 = await f2;

      expect(r1, 'ok');
      expect(r2, 'ok');
      expect(resultados, ['primera-listo', 'segunda-listo']);
    });

    test('propaga excepciones sin bloquear siguientes', () async {
      final mutex = MutexPersistencia();

      expect(
        () => mutex.run(() async {
          throw StateError('fallo');
        }),
        throwsStateError,
      );

      // La siguiente operación debe poder ejecutarse
      final resultado = await mutex.run(() async => 42);
      expect(resultado, 42);
    });

    test('múltiples operaciones en cadena se ejecutan en orden', () async {
      final mutex = MutexPersistencia();
      final orden = <int>[];

      final futures = List.generate(10, (i) {
        return mutex.run(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          orden.add(i);
        });
      });

      await Future.wait(futures);

      expect(orden, List.generate(10, (i) => i));
    });
  });
}
