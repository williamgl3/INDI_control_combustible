import 'package:indi_combustible/data/despachos_marimba_repository.dart';
import 'package:indi_combustible/models/despacho_marimba.dart';

/// Libro mayor de la marimba en memoria — mismo saldo continuo del
/// backend real (nunca se reinicia por carga ni por día), útil para
/// tests de widgets y como referencia de la interfaz.
class MockDespachosMarimbaRepository implements DespachosMarimbaRepository {
  final Map<String, double> _saldos = {};
  final List<DespachoMarimba> _despachos = [];
  int _idSeq = 1;

  /// Solo para tests: simula una carga a la marimba (entrada al saldo).
  void agregarCargaDePrueba(String marimbaId, double litros) {
    _saldos[marimbaId] = (_saldos[marimbaId] ?? 0) + litros;
  }

  @override
  Future<double> saldoDeMarimba(
    String marimbaId,
    String tipoCombustible,
  ) async => _saldos['$marimbaId:$tipoCombustible'] ?? _saldos[marimbaId] ?? 0;

  @override
  Future<List<DespachoMarimba>> listarDespachosDeMarimba(
    String marimbaId,
  ) async {
    return _despachos.where((d) => d.marimbaId == marimbaId).toList();
  }

  @override
  Future<DespachoMarimba> registrarDespacho({
    required String marimbaId,
    String? vehiculoDestinoId,
    String? destinoTexto,
    required String operadorTexto,
    String? residenteTexto,
    required String sitio,
    double? litrosSolicitados,
    required double litrosSuministrados,
    double? lecturaMedidor,
    EstadoDespacho estado = EstadoDespacho.activo,
    String? fotoEvidenciaPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final saldo = _saldos[marimbaId] ?? 0;
    if (litrosSuministrados > saldo) {
      throw Exception(
        'Saldo insuficiente en la marimba: hay $saldo L disponibles, se intentó despachar $litrosSuministrados L.',
      );
    }
    _saldos[marimbaId] = saldo - litrosSuministrados;
    final despacho = DespachoMarimba(
      id: 'despacho-${_idSeq++}',
      marimbaId: marimbaId,
      vehiculoDestinoId: vehiculoDestinoId,
      destinoTexto: destinoTexto,
      operadorTexto: operadorTexto,
      residenteTexto: residenteTexto,
      sitio: sitio,
      litrosSolicitados: litrosSolicitados,
      litrosSuministrados: litrosSuministrados,
      lecturaMedidor: lecturaMedidor,
      estado: estado,
      fotoEvidenciaPath: fotoEvidenciaPath,
      registradoPor: 'usuario-de-prueba',
      creadoEn: DateTime.now(),
    );
    _despachos.add(despacho);
    return despacho;
  }
}
