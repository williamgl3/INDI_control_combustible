import 'almacenamiento_offline.dart';
import 'metadata_archivo_offline.dart';

/// Códigos de error estables para archivo offline faltante/modificado.
const String kCodigoArchivoOfflineFaltante = 'ARCHIVO_OFFLINE_FALTANTE';
const String kCodigoArchivoOfflineModificado = 'ARCHIVO_OFFLINE_MODIFICADO';
const String kCodigoArchivoOfflineIlegible = 'ARCHIVO_OFFLINE_ILEGIBLE';

/// Mensajes descriptivos para cada código.
const Map<String, String> kMensajesArchivoOffline = {
  kCodigoArchivoOfflineFaltante:
      'El archivo requerido ya no existe en el almacenamiento local.',
  kCodigoArchivoOfflineModificado:
      'El archivo local fue modificado o corrupto después de importarlo.',
  kCodigoArchivoOfflineIlegible:
      'El archivo local existe pero no se pueden leer sus bytes.',
};

/// Resultado de verificar un archivo asociado a una operación offline.
class ResultadoVerificacionArchivo {
  const ResultadoVerificacionArchivo({
    required this.verificacion,
    this.codigo,
    this.mensaje,
  });

  factory ResultadoVerificacionArchivo.desdeVerificacion(
    VerificacionArchivo verificacion,
  ) {
    return switch (verificacion) {
      VerificacionArchivo.ok =>
        ResultadoVerificacionArchivo(verificacion: verificacion),
      VerificacionArchivo.faltante => ResultadoVerificacionArchivo(
          verificacion: verificacion,
          codigo: kCodigoArchivoOfflineFaltante,
          mensaje: kMensajesArchivoOffline[kCodigoArchivoOfflineFaltante],
        ),
      VerificacionArchivo.modificado => ResultadoVerificacionArchivo(
          verificacion: verificacion,
          codigo: kCodigoArchivoOfflineModificado,
          mensaje: kMensajesArchivoOffline[kCodigoArchivoOfflineModificado],
        ),
      VerificacionArchivo.ilegible => ResultadoVerificacionArchivo(
          verificacion: verificacion,
          codigo: kCodigoArchivoOfflineIlegible,
          mensaje: kMensajesArchivoOffline[kCodigoArchivoOfflineIlegible],
        ),
    };
  }

  final VerificacionArchivo verificacion;
  final String? codigo;
  final String? mensaje;

  bool get esOk => verificacion == VerificacionArchivo.ok;
  bool get requiereRevision => !esOk;
}

/// Verifica un archivo durable usando el [AlmacenamientoOffline] y la
/// [MetadataArchivoOffline] persistida en la operación.
Future<ResultadoVerificacionArchivo> verificarArchivoOperacion({
  required AlmacenamientoOffline almacenamiento,
  required MetadataArchivoOffline metadata,
  required String usuarioId,
  required String idLocalOperacion,
}) async {
  final verificacion = await almacenamiento.verificarIntegridad(
    metadata: metadata,
    usuarioId: usuarioId,
    idLocalOperacion: idLocalOperacion,
  );
  return ResultadoVerificacionArchivo.desdeVerificacion(verificacion);
}

/// Verifica todos los archivos de una operación. Retorna el primer
/// resultado que no sea OK, o OK si todos pasan.
Future<ResultadoVerificacionArchivo> verificarArchivosOperacion({
  required AlmacenamientoOffline almacenamiento,
  required List<MetadataArchivoOffline> metadatas,
  required String usuarioId,
  required String idLocalOperacion,
}) async {
  for (final metadata in metadatas) {
    final resultado = await verificarArchivoOperacion(
      almacenamiento: almacenamiento,
      metadata: metadata,
      usuarioId: usuarioId,
      idLocalOperacion: idLocalOperacion,
    );
    if (resultado.requiereRevision) return resultado;
  }
  return const ResultadoVerificacionArchivo(verificacion: VerificacionArchivo.ok);
}
