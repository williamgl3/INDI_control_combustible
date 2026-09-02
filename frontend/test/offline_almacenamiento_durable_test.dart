import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/offline/almacenamiento_offline.dart';
import 'package:indi_combustible/core/offline/almacenamiento_offline_factory.dart';
import 'package:indi_combustible/core/offline/almacenamiento_offline_filesystem.dart';
import 'package:indi_combustible/core/offline/coordinador_sincronizacion.dart';
import 'package:indi_combustible/core/offline/metadata_archivo_offline.dart';

void main() {
  test('factory VM selecciona almacenamiento filesystem', () {
    expect(crearAlmacenamientoOffline(), isA<AlmacenamientoOfflineFilesystem>());
  });

  group('MetadataArchivoOffline', () {
    test('round-trip JSON preserva todos los campos', () {
      final original = MetadataArchivoOffline(
        storageKey: 'abc-123',
        sizeBytes: 4096,
        sha256: 'hash-ejemplo',
        multipartField: 'fotoTablero',
        mimeType: 'image/png',
        originalName: 'foto.png',
      );

      final json = original.toJson();
      final restaurada = MetadataArchivoOffline.fromJson(json);

      expect(restaurada.storageKey, original.storageKey);
      expect(restaurada.sizeBytes, original.sizeBytes);
      expect(restaurada.sha256, original.sha256);
      expect(restaurada.multipartField, original.multipartField);
      expect(restaurada.mimeType, original.mimeType);
      expect(restaurada.originalName, original.originalName);
    });

    test('serializar/deserializar preserva datos', () {
      final original = MetadataArchivoOffline.nueva(
        sizeBytes: 1234,
        sha256: 'abc-def',
        multipartField: 'fotoTicket',
      );

      final serializado = original.serializar();
      final restaurada = MetadataArchivoOffline.deserializar(serializado);

      expect(restaurada, isNotNull);
      expect(restaurada!.storageKey, original.storageKey);
      expect(restaurada.sizeBytes, original.sizeBytes);
    });

    test('deserializar retorna null para input inválido', () {
      expect(MetadataArchivoOffline.deserializar(null), isNull);
      expect(MetadataArchivoOffline.deserializar(''), isNull);
      expect(MetadataArchivoOffline.deserializar('no-json'), isNull);
    });

    test('nueva genera UUID v4 válido para storageKey', () {
      final metadata = MetadataArchivoOffline.nueva(
        sizeBytes: 100,
        sha256: 'test',
        multipartField: 'foto',
      );

      expect(metadata.storageKey.length, 36);
      expect(metadata.storageKey[8], '-');
      // UUID v4 tiene '4' en la posición 14
      expect(metadata.storageKey[14], '4');
    });

    test('originalName es nullable', () {
      final sinNombre = MetadataArchivoOffline.nueva(
        sizeBytes: 100,
        sha256: 'test',
        multipartField: 'foto',
      );
      expect(sinNombre.originalName, isNull);

      final json = sinNombre.toJson();
      expect(json.containsKey('originalName'), isFalse);
    });

    test('equality basado en campos clave', () {
      final a = MetadataArchivoOffline(
        storageKey: 'key-1',
        sizeBytes: 100,
        sha256: 'hash',
        multipartField: 'foto',
      );
      final b = MetadataArchivoOffline(
        storageKey: 'key-1',
        sizeBytes: 100,
        sha256: 'hash',
        multipartField: 'foto',
      );
      final c = MetadataArchivoOffline(
        storageKey: 'key-2',
        sizeBytes: 100,
        sha256: 'hash',
        multipartField: 'foto',
      );
      final d = MetadataArchivoOffline(
        storageKey: 'key-1',
        sizeBytes: 200,
        sha256: 'otro-hash',
        multipartField: 'foto',
      );

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
      expect(a, isNot(equals(d)));
    });
  });

  group('AlmacenamientoOfflineFilesystem', () {
    late Directory tempDir;
    late AlmacenamientoOfflineFilesystem almacenamiento;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('offline_test_');
      almacenamiento = AlmacenamientoOfflineFilesystem(
        directorioBase: Future.value(tempDir),
      );
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('importar desde bytes directos retorna metadata válida', () async {
      final bytes = Uint8List.fromList([1, 2, 3, 4, 5]);

      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'fotoTablero',
        bytesDirectos: bytes,
      );

      expect(metadata.sizeBytes, 5);
      expect(metadata.multipartField, 'fotoTablero');
      expect(metadata.storageKey.isNotEmpty, isTrue);
    });

    test('importar y leer retorna bytes idénticos', () async {
      final bytes = Uint8List.fromList([10, 20, 30, 40, 50]);

      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        bytesDirectos: bytes,
      );

      final leidos = await almacenamiento.leer(
        storageKey: metadata.storageKey,
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
      );

      expect(leidos, equals(bytes));
    });

    test('importar desde ruta de archivo', () async {
      final archivoOrigen = File('${tempDir.path}/origen.jpg');
      await archivoOrigen.writeAsBytes([100, 200, 150]);

      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        rutaOrigen: archivoOrigen.path,
      );

      final leidos = await almacenamiento.leer(
        storageKey: metadata.storageKey,
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
      );

      expect(leidos, equals([100, 200, 150]));
      expect(metadata.sizeBytes, 3);
    });

    test('verificarIntegridad retorna ok para archivo íntegro', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        bytesDirectos: bytes,
      );

      final verificacion = await almacenamiento.verificarIntegridad(
        metadata: metadata,
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
      );

      expect(verificacion, VerificacionArchivo.ok);
    });

    test('verificarIntegridad retorna faltante si no existe', () async {
      final metadata = MetadataArchivoOffline(
        storageKey: 'no-existe',
        sizeBytes: 10,
        sha256: 'hash',
        multipartField: 'foto',
      );

      final verificacion = await almacenamiento.verificarIntegridad(
        metadata: metadata,
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
      );

      expect(verificacion, VerificacionArchivo.faltante);
    });

    test('verificarIntegridad retorna modificado si tamaño cambió', () async {
      final bytes = Uint8List.fromList([1, 2, 3]);

      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        bytesDirectos: bytes,
      );

      // Sobrescribir con bytes diferentes
      final dirOperacion = Directory('${tempDir.path}/offline/user-1/op-1');
      final archivo = dirOperacion.listSync().whereType<File>().first;
      await archivo.writeAsBytes([1, 2, 3, 4, 5], flush: true);

      final verificacion = await almacenamiento.verificarIntegridad(
        metadata: metadata,
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
      );

      expect(verificacion, VerificacionArchivo.modificado);
    });

    test('existe retorna true/false correctamente', () async {
      final bytes = Uint8List.fromList([1]);

      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        bytesDirectos: bytes,
      );

      expect(
        await almacenamiento.existe(
          storageKey: metadata.storageKey,
          usuarioId: 'user-1',
          idLocalOperacion: 'op-1',
        ),
        isTrue,
      );

      expect(
        await almacenamiento.existe(
          storageKey: 'no-existe',
          usuarioId: 'user-1',
          idLocalOperacion: 'op-1',
        ),
        isFalse,
      );
    });

    test('eliminar quita el archivo', () async {
      final bytes = Uint8List.fromList([1]);

      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        bytesDirectos: bytes,
      );

      final eliminado = await almacenamiento.eliminar(
        storageKey: metadata.storageKey,
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
      );

      expect(eliminado, isTrue);

      expect(
        await almacenamiento.existe(
          storageKey: metadata.storageKey,
          usuarioId: 'user-1',
          idLocalOperacion: 'op-1',
        ),
        isFalse,
      );
    });

    test('listarArchivos retorna keys y operaciones del usuario', () async {
      await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'fotoA',
        bytesDirectos: Uint8List.fromList([1]),
      );
      await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-2',
        multipartField: 'fotoB',
        bytesDirectos: Uint8List.fromList([2]),
      );
      // Archivo de otro usuario
      await almacenamiento.importar(
        usuarioId: 'user-2',
        idLocalOperacion: 'op-3',
        multipartField: 'fotoC',
        bytesDirectos: Uint8List.fromList([3]),
      );

      final archivos = await almacenamiento.listarArchivos(usuarioId: 'user-1');

      expect(archivos, hasLength(2));
      expect(archivos.map((archivo) => archivo.idLocalOperacion).toSet(), {
        'op-1',
        'op-2',
      });
    });

    test('aislamiento por usuario — user-2 no ve archivos de user-1', () async {
      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        bytesDirectos: Uint8List.fromList([1]),
      );

      expect(
        await almacenamiento.existe(
          storageKey: metadata.storageKey,
          usuarioId: 'user-2',
          idLocalOperacion: 'op-1',
        ),
        isFalse,
      );
    });

    test('limpieza elimina huérfano y conserva archivo referenciado', () async {
      final huerfano = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-huerfana',
        multipartField: 'foto',
        bytesDirectos: Uint8List.fromList([1]),
      );
      final referenciado = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-referenciada',
        multipartField: 'foto',
        bytesDirectos: Uint8List.fromList([2]),
      );

      final eliminados = await limpiarArchivosHuerfanos(
        almacenamiento: almacenamiento,
        usuarioId: 'user-1',
        storageKeysReferenciadas: {referenciado.storageKey},
      );

      expect(eliminados, 1);
      expect(
        await almacenamiento.existe(
          storageKey: huerfano.storageKey,
          usuarioId: 'user-1',
          idLocalOperacion: 'op-huerfana',
        ),
        isFalse,
      );
      expect(
        await almacenamiento.existe(
          storageKey: referenciado.storageKey,
          usuarioId: 'user-1',
          idLocalOperacion: 'op-referenciada',
        ),
        isTrue,
      );
    });

    test('limpieza resuelve múltiples idLocalOperacion', () async {
      await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        bytesDirectos: Uint8List.fromList([1]),
      );
      await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-2',
        multipartField: 'foto',
        bytesDirectos: Uint8List.fromList([2]),
      );

      expect(
        await limpiarArchivosHuerfanos(
          almacenamiento: almacenamiento,
          usuarioId: 'user-1',
          storageKeysReferenciadas: const {},
        ),
        2,
      );
      expect(await almacenamiento.listarArchivos(usuarioId: 'user-1'), isEmpty);
    });

    test(
      'archivo enumerado pero inexistente no incrementa eliminados',
      () async {
        final conFantasma = _AlmacenamientoConFantasma(
          directorioBase: Future.value(tempDir),
        );

        expect(
          await limpiarArchivosHuerfanos(
            almacenamiento: conFantasma,
            usuarioId: 'user-1',
            storageKeysReferenciadas: const {},
          ),
          0,
        );
      },
    );

    test('rechaza identificadores con path traversal', () async {
      expect(
        () => almacenamiento.eliminar(
          storageKey: '../fuera',
          usuarioId: 'user-1',
          idLocalOperacion: 'op-1',
        ),
        throwsArgumentError,
      );
      expect(
        () => almacenamiento.listarArchivos(usuarioId: '../otro'),
        throwsArgumentError,
      );
    });

    test('original temporal eliminado pero durable funciona', () async {
      final archivoOrigen = File('${tempDir.path}/temp.jpg');
      await archivoOrigen.writeAsBytes([10, 20]);

      final metadata = await almacenamiento.importar(
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
        multipartField: 'foto',
        rutaOrigen: archivoOrigen.path,
      );

      // Eliminar original temporal
      await archivoOrigen.delete();

      // Durable sigue funcionando
      final leidos = await almacenamiento.leer(
        storageKey: metadata.storageKey,
        usuarioId: 'user-1',
        idLocalOperacion: 'op-1',
      );
      expect(leidos, equals([10, 20]));
    });
  });
}

class _AlmacenamientoConFantasma extends AlmacenamientoOfflineFilesystem {
  _AlmacenamientoConFantasma({required super.directorioBase});

  @override
  Future<List<ArchivoOfflineAlmacenado>> listarArchivos({
    required String usuarioId,
  }) async => const [
    ArchivoOfflineAlmacenado(
      idLocalOperacion: 'op-inexistente',
      storageKey: 'archivo-inexistente',
    ),
  ];
}
