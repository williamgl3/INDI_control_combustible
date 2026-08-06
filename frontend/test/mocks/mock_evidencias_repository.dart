import 'package:indi_combustible/data/evidencias_repository.dart';
import 'package:indi_combustible/models/evidencia.dart';

/// Repositorio de evidencias MOCK — datos en memoria, para widget tests.
class MockEvidenciasRepository implements EvidenciasRepository {
  final List<Evidencia> _todas = [];
  int _idSeq = 1;

  @override
  List<Evidencia> get todasLasEvidencias => List.unmodifiable(_todas);

  @override
  Future<void> cargarTodasLasEvidencias() async {}

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
    final evidencia = Evidencia(
      id: 'evidencia-${_idSeq++}',
      usuarioId: usuarioId,
      tipo: tipo,
      fotoUrls: fotoPaths,
      km: km,
      folioId: folioId,
      cargaId: cargaId,
      pendienteVincular: pendienteVincular,
      notas: notas,
      creadaEn: DateTime.now(),
      tipoCombustibleCargado: tipoCombustibleCargado,
      litros: litros,
      precioPorLitro: precioPorLitro,
      montoPagado: montoPagado,
    );
    _todas.insert(0, evidencia);
    return evidencia;
  }
}
