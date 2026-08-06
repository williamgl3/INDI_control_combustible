import '../models/evidencia.dart';
import 'api_client.dart';
import 'evidencias_repository.dart';

/// Implementación real de [EvidenciasRepository]: sube evidencias al
/// backend vía multipart POST (`/evidencias`).
class ApiEvidenciasRepository implements EvidenciasRepository {
  ApiEvidenciasRepository(this._client);

  final ApiClient _client;

  List<Evidencia> _todas = [];

  @override
  List<Evidencia> get todasLasEvidencias => List.unmodifiable(_todas);

  @override
  Future<void> cargarTodasLasEvidencias() async {
    final data = await _client.get('/evidencias');
    _todas = (data as List)
        .map((e) => Evidencia.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Evidencia> subirEvidencia({
    required String usuarioId,
    required TipoEvidencia tipo,
    required List<String> fotoPaths,
    double? km,
    String? folioId,
    String? cargaId,
    bool pendienteVincular = false,
    String? notas,
    String? tipoCombustibleCargado,
    double? litros,
    double? precioPorLitro,
    double? montoPagado,
  }) async {
    final data = await _client.postMultipart(
      '/evidencias',
      campos: {
        'usuario_id': usuarioId,
        'tipo': tipo.name,
        'folio_id': ?folioId,
        'carga_id': ?cargaId,
        if (km != null) 'km': km.toString(),
        if (pendienteVincular) 'pendiente_vincular': 'true',
        if (notas != null && notas.isNotEmpty) 'notas': notas,
        // `toStringAsFixed(2)`, no `toString()`: mismos 2 decimales que
        // las columnas NUMERIC(10,2) del backend, sin arrastrar el
        // formato "crudo" de un double de Dart.
        'tipo_combustible_cargado': ?tipoCombustibleCargado,
        if (litros != null) 'litros': litros.toStringAsFixed(2),
        if (precioPorLitro != null) 'precio_por_litro': precioPorLitro.toStringAsFixed(2),
        if (montoPagado != null) 'monto_pagado': montoPagado.toStringAsFixed(2),
      },
      archivosMultiples: {'fotos': fotoPaths},
    );
    return Evidencia.fromJson(data as Map<String, dynamic>);
  }
}
