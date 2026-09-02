import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'almacenamiento_offline.dart';
import 'metadata_archivo_offline.dart';

/// Implementación de [AlmacenamientoOffline] para plataformas con filesystem
/// (Android, iOS, Windows, macOS, Linux).
///
/// Los archivos se almacenan en:
/// ```
/// <applicationSupportDirectory>/offline/<usuarioId>/<idLocal>/<storageKey>.<ext>
/// ```
///
/// No se utiliza `getTemporaryDirectory` porque el SO puede limpiar ese
/// directorio en cualquier momento.
class AlmacenamientoOfflineFilesystem implements AlmacenamientoOffline {
  AlmacenamientoOfflineFilesystem({this._directorioBase});

  final Future<Directory>? _directorioBase;

  Future<Directory> _dirBase() async =>
      _directorioBase ?? getApplicationSupportDirectory();

  Future<Directory> _dirOperacion(
    String usuarioId,
    String idLocalOperacion, {
    bool crear = true,
  }) async {
    _validarIdentificador(usuarioId, 'usuarioId');
    _validarIdentificador(idLocalOperacion, 'idLocalOperacion');
    final base = await _dirBase();
    final dir = Directory('${base.path}/offline/$usuarioId/$idLocalOperacion');
    if (crear && !dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  void _validarIdentificador(String valor, String campo) {
    if (!identificadorOfflineValido(valor)) {
      throw ArgumentError.value(valor, campo, 'Identificador offline inválido');
    }
  }

  String _extension(String mimeType) => switch (mimeType) {
    'image/png' => 'png',
    'image/webp' => 'webp',
    'image/heic' => 'heic',
    'image/heif' => 'heif',
    _ => 'jpg',
  };

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
    Uint8List bytes;
    if (bytesDirectos != null) {
      bytes = bytesDirectos;
    } else if (rutaOrigen != null) {
      final archivo = File(rutaOrigen);
      if (!archivo.existsSync()) {
        throw StateError('El archivo origen no existe: $multipartField');
      }
      bytes = await archivo.readAsBytes();
    } else {
      throw StateError(
        'Se debe proporcionar rutaOrigen o bytesDirectos para $multipartField',
      );
    }

    final hash = sha256.convert(bytes).toString();
    final metadata = MetadataArchivoOffline.nueva(
      sizeBytes: bytes.length,
      sha256: hash,
      multipartField: multipartField,
      mimeType: mimeType,
      originalName: originalName,
    );

    final dir = await _dirOperacion(usuarioId, idLocalOperacion);
    final ext = _extension(mimeType);
    final destino = File('${dir.path}/${metadata.storageKey}.$ext');
    await destino.writeAsBytes(bytes, flush: true);

    return metadata;
  }

  @override
  Future<Uint8List> leer({
    required String storageKey,
    required String usuarioId,
    required String idLocalOperacion,
  }) async {
    final dir = await _dirOperacion(usuarioId, idLocalOperacion, crear: false);
    final archivo = _buscarArchivo(dir, storageKey);
    if (archivo == null) {
      throw StateError('Archivo durable no encontrado: $storageKey');
    }
    return archivo.readAsBytes();
  }

  @override
  Future<VerificacionArchivo> verificarIntegridad({
    required MetadataArchivoOffline metadata,
    required String usuarioId,
    required String idLocalOperacion,
  }) async {
    final dir = await _dirOperacion(usuarioId, idLocalOperacion, crear: false);
    final archivo = _buscarArchivo(dir, metadata.storageKey);
    if (archivo == null) return VerificacionArchivo.faltante;

    try {
      final bytes = await archivo.readAsBytes();
      if (bytes.length != metadata.sizeBytes) {
        return VerificacionArchivo.modificado;
      }
      final hash = sha256.convert(bytes).toString();
      if (hash != metadata.sha256) {
        return VerificacionArchivo.modificado;
      }
      return VerificacionArchivo.ok;
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
    final dir = await _dirOperacion(usuarioId, idLocalOperacion, crear: false);
    return _buscarArchivo(dir, storageKey) != null;
  }

  @override
  Future<bool> eliminar({
    required String storageKey,
    required String usuarioId,
    required String idLocalOperacion,
  }) async {
    _validarIdentificador(storageKey, 'storageKey');
    final dir = await _dirOperacion(usuarioId, idLocalOperacion, crear: false);
    final archivo = _buscarArchivo(dir, storageKey);
    if (archivo != null && archivo.existsSync()) {
      await archivo.delete();
      return true;
    }
    return false;
  }

  @override
  Future<List<ArchivoOfflineAlmacenado>> listarArchivos({
    required String usuarioId,
  }) async {
    _validarIdentificador(usuarioId, 'usuarioId');
    final base = await _dirBase();
    final dirUsuario = Directory('${base.path}/offline/$usuarioId');
    if (!dirUsuario.existsSync()) return const [];

    final archivos = <ArchivoOfflineAlmacenado>[];
    await for (final entidad in dirUsuario.list(recursive: true)) {
      if (entidad is File) {
        final relativa = entidad.path.substring(dirUsuario.path.length + 1);
        final segmentos = relativa.split(RegExp(r'[\\/]'));
        if (segmentos.length != 2 ||
            !identificadorOfflineValido(segmentos.first)) {
          continue;
        }
        final nombre = entidad.uri.pathSegments.last;
        // El storageKey es el nombre sin extensión.
        final key = nombre.contains('.')
            ? nombre.substring(0, nombre.lastIndexOf('.'))
            : nombre;
        if (identificadorOfflineValido(key)) {
          archivos.add(
            ArchivoOfflineAlmacenado(
              idLocalOperacion: segmentos.first,
              storageKey: key,
            ),
          );
        }
      }
    }
    return archivos;
  }

  File? _buscarArchivo(Directory dir, String storageKey) {
    _validarIdentificador(storageKey, 'storageKey');
    if (!dir.existsSync()) return null;
    for (final entidad in dir.listSync()) {
      if (entidad is File) {
        final nombre = entidad.uri.pathSegments.last;
        final nombreSinExtension = nombre.contains('.')
            ? nombre.substring(0, nombre.lastIndexOf('.'))
            : nombre;
        if (nombreSinExtension == storageKey) {
          return entidad;
        }
      }
    }
    return null;
  }
}
