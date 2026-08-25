import '../models/registro_auditoria.dart';
import 'api_client.dart';
import 'auditoria_repository.dart';

/// Implementación real de [AuditoriaRepository]: habla por HTTP con el
/// backend (`GET /auditoria?limit=&before=`).
class ApiAuditoriaRepository implements AuditoriaRepository {
  ApiAuditoriaRepository(this._client);

  final ApiClient _client;

  List<RegistroAuditoria> _registros = [];
  bool _sinMasRegistros = false;

  @override
  List<RegistroAuditoria> get registros => List.unmodifiable(_registros);

  @override
  bool get sinMasRegistros => _sinMasRegistros;

  Future<List<RegistroAuditoria>> _traerPagina({
    required int limit,
    String? before,
  }) async {
    final query = <String>[
      'limit=$limit',
      if (before != null) 'before=$before',
    ];
    final data = await _client.get('/auditoria?${query.join('&')}');
    if (data is! Map) {
      throw const FormatException('La respuesta de auditoría no es un objeto.');
    }
    final lista = data['registros'];
    if (lista is! List) {
      throw const FormatException(
        'La respuesta de auditoría no contiene registros.',
      );
    }
    return List<RegistroAuditoria>.unmodifiable(
      lista.map((registro) {
        if (registro is! Map) {
          throw const FormatException('Un registro de auditoría no es válido.');
        }
        return RegistroAuditoria.fromJson(Map<String, dynamic>.from(registro));
      }),
    );
  }

  @override
  Future<void> cargarRegistros({int limit = 30}) async {
    final pagina = await _traerPagina(limit: limit);
    _registros = pagina;
    _sinMasRegistros = pagina.length < limit;
  }

  @override
  Future<void> cargarMasRegistros({int limit = 30}) async {
    if (_registros.isEmpty) {
      return cargarRegistros(limit: limit);
    }
    final cursor = _registros.last.creadoEn.toIso8601String();
    final pagina = await _traerPagina(limit: limit, before: cursor);
    _registros = [..._registros, ...pagina];
    _sinMasRegistros = pagina.length < limit;
  }
}
