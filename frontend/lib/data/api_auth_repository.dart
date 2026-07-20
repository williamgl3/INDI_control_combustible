import '../models/perfil.dart';
import 'api_client.dart';
import 'auth_repository.dart';

/// Implementación real de [AuthRepository]: habla por HTTP con el
/// backend (ver `backend/src/routes/auth.routes.ts`).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client);

  final ApiClient _client;
  List<Perfil> _choferes = [];

  ResultadoAuth _aResultado(dynamic data) {
    return (
      perfil: Perfil.fromJson(data['perfil'] as Map<String, dynamic>),
      token: data['token'] as String,
    );
  }

  @override
  Future<ResultadoAuth> login({
    required String usuario,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/login',
        body: {'usuario': usuario, 'password': password},
      );
      return _aResultado(data);
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<ResultadoAuth> registrarChofer({
    required String nombreCompleto,
    required int edad,
    required String correo,
    required String usuario,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/registro-chofer',
        body: {
          'nombreCompleto': nombreCompleto,
          'edad': edad,
          'correo': correo,
          'usuario': usuario,
          'password': password,
        },
      );
      return _aResultado(data);
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<void> recuperarPassword({required String usuarioOCorreo}) async {
    try {
      await _client.post(
        '/recuperar-password',
        body: {'usuarioOCorreo': usuarioOCorreo},
      );
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  List<Perfil> listarChoferes() => List.unmodifiable(_choferes);

  @override
  Future<void> cargarChoferes() async {
    final data = await _client.get('/choferes');
    _choferes = (data as List)
        .map((j) => Perfil.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}
