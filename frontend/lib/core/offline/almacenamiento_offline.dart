import 'dart:typed_data';

import 'metadata_archivo_offline.dart';

class ArchivoOfflineAlmacenado {
  const ArchivoOfflineAlmacenado({
    required this.idLocalOperacion,
    required this.storageKey,
  });

  final String idLocalOperacion;
  final String storageKey;
}

bool identificadorOfflineValido(String valor) =>
    valor.isNotEmpty && RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(valor);

/// Resultado de una verificación de integridad de archivo durable.
enum VerificacionArchivo {
  /// Los bytes están íntegros — se puede proceder a enviar.
  ok,

  /// El archivo no existe en el almacenamiento.
  faltante,

  /// El archivo existe pero su tamaño o SHA-256 no coinciden con la metadata.
  modificado,

  /// El archivo existe pero no se pudieron leer los bytes.
  ilegible,
}

/// Abstracción de almacenamiento offline durable para archivos binarios
/// (fotografías) que deben sobrevivir reinicios, cierres de app y cambios
/// de conectividad.
///
/// Oculta las diferencias entre plataforma: filesystem privado en
/// Android/iOS/Desktop, IndexedDB en Flutter Web. El resto de la cola
/// offline nunca necesita saber qué backend se usa.
abstract class AlmacenamientoOffline {
  /// Importa bytes desde una ruta temporal u otra fuente, calcula SHA-256
  /// y persiste en almacenamiento durable.
  ///
  /// [rutaOrigen] puede ser una ruta de filesystem (mobile/desktop) o se
  /// puede pasar [bytesDirectos] directamente (Web).
  ///
  /// Retorna la metadata serializable que se debe guardar en la operación.
  Future<MetadataArchivoOffline> importar({
    required String usuarioId,
    required String idLocalOperacion,
    required String multipartField,
    String? rutaOrigen,
    Uint8List? bytesDirectos,
    String mimeType = 'image/jpeg',
    String? originalName,
  });

  /// Lee los bytes completos de un archivo persistido.
  Future<Uint8List> leer({
    required String storageKey,
    required String usuarioId,
    required String idLocalOperacion,
  });

  /// Verifica integridad: tamaño + SHA-256 vs metadata.
  Future<VerificacionArchivo> verificarIntegridad({
    required MetadataArchivoOffline metadata,
    required String usuarioId,
    required String idLocalOperacion,
  });

  /// Verifica si un archivo existe en el almacenamiento.
  Future<bool> existe({
    required String storageKey,
    required String usuarioId,
    required String idLocalOperacion,
  });

  /// Elimina un archivo persistido.
  /// Retorna `true` únicamente cuando el archivo existía y fue eliminado.
  Future<bool> eliminar({
    required String storageKey,
    required String usuarioId,
    required String idLocalOperacion,
  });

  /// Enumera archivos con la operación necesaria para localizarlos sin
  /// búsquedas globales ni rutas ambiguas.
  Future<List<ArchivoOfflineAlmacenado>> listarArchivos({
    required String usuarioId,
  });
}
