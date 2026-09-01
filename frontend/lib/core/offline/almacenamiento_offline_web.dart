import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:web/web.dart' as web;

import 'almacenamiento_offline.dart';
import 'metadata_archivo_offline.dart';

/// Implementación durable para navegador mediante IndexedDB.
class AlmacenamientoOfflineWeb implements AlmacenamientoOffline {
  static const _databaseName = 'indi_combustible_offline';
  static const _storeName = 'offline_archivos';
  static const _prefix = 'offline';

  web.IDBDatabase? _db;

  Future<web.IDBDatabase> _abrir() async {
    final existente = _db;
    if (existente != null) return existente;
    final completer = Completer<web.IDBDatabase>();
    final request = web.window.indexedDB.open(_databaseName, 1);
    request.onupgradeneeded = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      final db = request.result as web.IDBDatabase;
      db.onversionchange = ((web.Event _) {
        db.close();
        if (identical(_db, db)) _db = null;
      }).toJS;
      _db = db;
      if (!completer.isCompleted) completer.complete(db);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('No se pudo abrir IndexedDB: ${request.error?.message}'),
        );
      }
    }).toJS;
    request.onblocked = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('La actualización de IndexedDB está bloqueada.'),
        );
      }
    }).toJS;
    return completer.future;
  }

  void _validar(String valor, String campo) {
    if (!identificadorOfflineValido(valor)) {
      throw ArgumentError.value(valor, campo, 'Identificador offline inválido');
    }
  }

  String _key(String usuarioId, String idLocalOperacion, String storageKey) {
    _validar(usuarioId, 'usuarioId');
    _validar(idLocalOperacion, 'idLocalOperacion');
    _validar(storageKey, 'storageKey');
    return '$_prefix:$usuarioId:$idLocalOperacion:$storageKey';
  }

  String _prefixUsuario(String usuarioId) {
    _validar(usuarioId, 'usuarioId');
    return '$_prefix:$usuarioId:';
  }

  Future<void> _esperarTransaccion(web.IDBTransaction tx) {
    final completer = Completer<void>();
    tx.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    void fallar(web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Falló una transacción de IndexedDB: ${tx.error?.message}',
          ),
        );
      }
    }

    tx.onabort = fallar.toJS;
    tx.onerror = fallar.toJS;
    return completer.future;
  }

  Future<JSAny?> _esperarRequest(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            'Falló una operación de IndexedDB: ${request.error?.message}',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }

  @override
  Future<MetadataArchivoOffline> importar({
    required String usuarioId,
    required String idLocalOperacion,
    required String multipartField,
    String? rutaOrigen,
    Uint8List? bytesDirectos,
    String mimeType = 'image/jpeg',
    String? originalName,
  }) async {
    if (bytesDirectos == null) {
      throw StateError(
        rutaOrigen == null
            ? 'Se requieren bytesDirectos para $multipartField.'
            : 'Web no puede importar rutas locales; usa bytesDirectos.',
      );
    }
    final metadata = MetadataArchivoOffline.nueva(
      sizeBytes: bytesDirectos.length,
      sha256: sha256.convert(bytesDirectos).toString(),
      multipartField: multipartField,
      mimeType: mimeType,
      originalName: originalName,
    );
    final db = await _abrir();
    final tx = db.transaction(_storeName.toJS, 'readwrite');
    tx
        .objectStore(_storeName)
        .put(
          bytesDirectos.toJS,
          _key(usuarioId, idLocalOperacion, metadata.storageKey).toJS,
        );
    await _esperarTransaccion(tx);
    return metadata;
  }

  @override
  Future<Uint8List> leer({
    required String storageKey,
    required String usuarioId,
    required String idLocalOperacion,
  }) async {
    final db = await _abrir();
    final tx = db.transaction(_storeName.toJS, 'readonly');
    final resultado = await _esperarRequest(
      tx
          .objectStore(_storeName)
          .get(_key(usuarioId, idLocalOperacion, storageKey).toJS),
    );
    if (resultado == null || !resultado.isA<JSUint8Array>()) {
      throw StateError('Archivo durable no encontrado: $storageKey');
    }
    return (resultado as JSUint8Array).toDart;
  }

  @override
  Future<VerificacionArchivo> verificarIntegridad({
    required MetadataArchivoOffline metadata,
    required String usuarioId,
    required String idLocalOperacion,
  }) async {
    try {
      final bytes = await leer(
        storageKey: metadata.storageKey,
        usuarioId: usuarioId,
        idLocalOperacion: idLocalOperacion,
      );
      if (bytes.length != metadata.sizeBytes ||
          sha256.convert(bytes).toString() != metadata.sha256) {
        return VerificacionArchivo.modificado;
      }
      return VerificacionArchivo.ok;
    } on StateError catch (error) {
      return error.message.contains('no encontrado')
          ? VerificacionArchivo.faltante
          : VerificacionArchivo.ilegible;
    } catch (_) {
      return VerificacionArchivo.ilegible;
    }
  }

  @override
  Future<bool> existe({
    required String storageKey,
    required String usuarioId,
    required String idLocalOperacion,
  }) async {
    try {
      await leer(
        storageKey: storageKey,
        usuarioId: usuarioId,
        idLocalOperacion: idLocalOperacion,
      );
      return true;
    } on StateError {
      return false;
    }
  }

  @override
  Future<bool> eliminar({
    required String storageKey,
    required String usuarioId,
    required String idLocalOperacion,
  }) async {
    if (!await existe(
      storageKey: storageKey,
      usuarioId: usuarioId,
      idLocalOperacion: idLocalOperacion,
    )) {
      return false;
    }
    final db = await _abrir();
    final tx = db.transaction(_storeName.toJS, 'readwrite');
    tx
        .objectStore(_storeName)
        .delete(_key(usuarioId, idLocalOperacion, storageKey).toJS);
    await _esperarTransaccion(tx);
    return true;
  }

  @override
  Future<List<ArchivoOfflineAlmacenado>> listarArchivos({
    required String usuarioId,
  }) async {
    final prefix = _prefixUsuario(usuarioId);
    final db = await _abrir();
    final tx = db.transaction(_storeName.toJS, 'readonly');
    final resultado = await _esperarRequest(
      tx.objectStore(_storeName).getAllKeys(),
    );
    if (resultado == null || !resultado.isA<JSArray>()) return const [];
    final archivos = <ArchivoOfflineAlmacenado>[];
    for (final valor in (resultado as JSArray<JSAny?>).toDart) {
      if (valor == null || !valor.isA<JSString>()) continue;
      final key = (valor as JSString).toDart;
      if (!key.startsWith(prefix)) continue;
      final segmentos = key.split(':');
      if (segmentos.length != 4) continue;
      final idLocal = segmentos[2];
      final storageKey = segmentos[3];
      if (identificadorOfflineValido(idLocal) &&
          identificadorOfflineValido(storageKey)) {
        archivos.add(
          ArchivoOfflineAlmacenado(
            idLocalOperacion: idLocal,
            storageKey: storageKey,
          ),
        );
      }
    }
    return archivos;
  }
}
