import '../offline/metadata_operacion_offline.dart';

/// Tipos de operación — un valor por cada cola offline.
enum TipoOperacionOffline {
  solicitud,
  comprobarCarga,
  cerrarDia,
  incidencia,
  evidencia,
  recorridoMarimba,
  despachoMarimba,
  cierreRecorridoMarimba,
}

/// Estados visuales unificados para la UI del Centro de Sincronización.
/// Fusiona [EstadoOperacionOffline] y [EstadoSolicitudOffline] en un solo
/// conjunto plano que la UI puede consumir directamente sin importar la cola.
enum EstadoVisualSincronizacion {
  pendiente,
  sincronizando,
  reintentoPendiente,
  errorTransitorio,
  errorPermanente,
  conflicto,
  completada,
  requiereRevision,
}

/// Proyección de solo lectura de una operación offline para la UI.
/// No reemplaza los modelos de cola existentes — es un modelo de vista puro
/// que se reconstruye cada vez que cambian las colas o el tick de operaciones.
class OperacionSincronizacionView {
  const OperacionSincronizacionView({
    required this.idLocal,
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.estadoVisual,
    required this.usuarioId,
    required this.intentos,
    required this.creadaEn,
    this.idServer,
    this.proximoIntento,
    this.ultimoError,
    this.codigoError,
    this.ultimoStatus,
    this.requiereLogin = false,
    this.idempotencyKey,
    this.archivos = const [],
    this.dependencias = const [],
    this.puedeReintentar = false,
    this.requiereAtencion = false,
  });

  final String idLocal;
  final String? idServer;
  final TipoOperacionOffline tipo;
  final String titulo;
  final String descripcion;
  final EstadoOperacionOffline estado;
  final EstadoVisualSincronizacion estadoVisual;
  final String usuarioId;
  final int intentos;
  final DateTime creadaEn;
  final DateTime? proximoIntento;
  final String? ultimoError;
  final String? codigoError;
  final int? ultimoStatus;
  final bool requiereLogin;
  final String? idempotencyKey;
  final List<ArchivoSincronizacionView> archivos;
  final List<DependenciaSincronizacionView> dependencias;
  final bool puedeReintentar;
  final bool requiereAtencion;

}

/// Información de un archivo asociado a una operación offline.
/// Puede representar una ruta directa (fotoTableroPath) o una referencia
/// a [MetadataArchivoOffline] por storageKey.
class ArchivoSincronizacionView {
  const ArchivoSincronizacionView({
    this.ruta,
    this.storageKey,
    this.sizeBytes,
    this.sha256,
    this.verificado = true,
  }) : assert(
          ruta != null || storageKey != null,
          'Debe proporcionar ruta o storageKey',
        );

  /// Ruta local directa del archivo (ej. fotoTableroPath, fotoHorometroPath).
  final String? ruta;

  /// Clave de [AlmacenamientoOffline] si el archivo fue persistido en
  /// almacenamiento durable (MetadataArchivoOffline.storageKey).
  final String? storageKey;

  /// Tamaño en bytes ( MetadataArchivoOffline.sizeBytes).
  final int? sizeBytes;

  /// Hash SHA-256 (MetadataArchivoOffline.sha256).
  final String? sha256;

  /// true si el archivo fue verificado o se asume íntegro.
  final bool verificado;

  String get nombreArchivo {
    final r = ruta ?? storageKey ?? '?';
    final partes = r.split(RegExp(r'[/\\]'));
    return partes.isNotEmpty ? partes.last : r;
  }

  bool get esDurable => storageKey != null;
}

/// Dependencia de una operación con otra (ej. despacho → recorrido).
class DependenciaSincronizacionView {
  const DependenciaSincronizacionView({
    required this.idLocal,
    required this.tipo,
    required this.descripcion,
  });

  final String idLocal;
  final TipoOperacionOffline tipo;
  final String descripcion;
}
