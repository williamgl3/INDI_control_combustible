@TestOn('browser')
library;

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/offline/almacenamiento_offline_factory.dart';
import 'package:indi_combustible/core/offline/almacenamiento_offline_web.dart';

void main() {
  test(
    'factory Web selecciona IndexedDB y conserva bytes entre instancias',
    () async {
      final almacenamiento = crearAlmacenamientoOffline();
      expect(almacenamiento, isA<AlmacenamientoOfflineWeb>());

      const usuarioId = 'usuario-web-test';
      const idLocal = 'operacion-web-test';
      final metadata = await almacenamiento.importar(
        usuarioId: usuarioId,
        idLocalOperacion: idLocal,
        multipartField: 'foto',
        bytesDirectos: Uint8List.fromList([10, 20, 30]),
      );

      // Una instancia nueva abre la misma IndexedDB, equivalente a reconstruir
      // el provider después de una recarga de la aplicación.
      final despuesDeRecarga = AlmacenamientoOfflineWeb();
      expect(
        await despuesDeRecarga.leer(
          storageKey: metadata.storageKey,
          usuarioId: usuarioId,
          idLocalOperacion: idLocal,
        ),
        [10, 20, 30],
      );
      expect(
        await despuesDeRecarga.listarArchivos(usuarioId: usuarioId),
        hasLength(1),
      );
      expect(
        await despuesDeRecarga.eliminar(
          storageKey: metadata.storageKey,
          usuarioId: usuarioId,
          idLocalOperacion: idLocal,
        ),
        isTrue,
      );
    },
  );
}
