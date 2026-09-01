import '../models/evidencia.dart';

/// Interfaz para el repositorio de evidencias fotográficas.
abstract class EvidenciasRepository {
  /// Sube una evidencia fotográfica al backend (1 a 5 imágenes +
  /// metadatos). Las imágenes se envían como `multipart/form-data`.
  ///
  /// [idempotencyKey] se envía como header `Idempotency-Key` cuando se
  /// proporciona — necesario para el soporte offline persist-first (fase 3D).
  Future<Evidencia> subirEvidencia({
    required String usuarioId,
    required TipoEvidencia tipo,
    required List<String> fotoPaths,
    double? km,
    String? folioId,
    String? cargaId,
    bool pendienteVincular = false,
    String? notas,
    // Obligatorios en el backend cuando `tipo == TipoEvidencia.comprobante`.
    String? tipoCombustibleCargado,
    double? litros,
    double? precioPorLitro,
    double? montoPagado,
    String idempotencyKey = '',
  });

  /// Cache en memoria de [cargarTodasLasEvidencias] — solo poblado para
  /// sesión administrativa (ver `auth_controller._precargarDatos`, mismo
  /// patrón que `IncidenciasRepository.todasLasIncidencias`). Hoy lo usa
  /// el reporte de Concentrado para resolver el gasto real de una carga.
  List<Evidencia> get todasLasEvidencias;

  Future<void> cargarTodasLasEvidencias();
}
