import '../core/token_storage.dart';
import '../models/perfil.dart';
import 'api_client.dart';
import 'auth_repository.dart';

/// Implementación real de [AuthRepository]: habla por HTTP con el
/// backend (ver `backend/src/routes/auth.routes.ts`).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client, this._tokenStorage);

  final ApiClient _client;
  final TokenStorage _tokenStorage;
  List<Perfil> _choferes = [];

  ResultadoAuth _aResultado(dynamic data) {
    return (
      perfil: Perfil.fromJson(data['perfil'] as Map<String, dynamic>),
      token: data['token'] as String,
      refreshToken: data['refreshToken'] as String,
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
    required String nombre,
    required String apellidoPaterno,
    String? apellidoMaterno,
    required String correo,
    required String usuario,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/registro-chofer',
        body: {
          'nombre': nombre,
          'apellidoPaterno': apellidoPaterno,
          'apellidoMaterno': apellidoMaterno,
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
  Future<void> cambiarPassword({
    required String passwordActual,
    required String passwordNueva,
  }) async {
    try {
      await _client.post(
        '/cambiar-password',
        body: {
          'passwordActual': passwordActual,
          'passwordNueva': passwordNueva,
        },
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

  @override
  Future<void> cambiarEstado({
    required String usuarioId,
    required bool activo,
  }) async {
    try {
      await _client.patch(
        '/usuarios/$usuarioId/estado',
        body: {'activo': activo},
      );
      final indice = _choferes.indexWhere((p) => p.id == usuarioId);
      if (indice != -1) {
        _choferes = [..._choferes];
        _choferes[indice] = _choferes[indice].copyWith(activo: activo);
      }
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<void> resetearPassword({
    required String usuarioId,
    required String passwordNueva,
  }) async {
    try {
      await _client.post(
        '/usuarios/$usuarioId/resetear-password',
        body: {'passwordNueva': passwordNueva},
      );
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<Perfil> crearAdministrativo({
    required String nombre,
    required String apellidoPaterno,
    required String apellidoMaterno,
    required String usuario,
    required String correo,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/usuarios/administrativos',
        body: {
          'nombre': nombre,
          'apellidoPaterno': apellidoPaterno,
          'apellidoMaterno': apellidoMaterno,
          'usuario': usuario,
          'correo': correo,
          'password': password,
        },
      );
      final perfil = Perfil.fromJson(data as Map<String, dynamic>);
      _choferes = [..._choferes, perfil];
      return perfil;
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.leerRefreshToken();
    if (refreshToken == null) return;
    try {
      await _client.post('/logout', body: {'refreshToken': refreshToken});
    } on ApiException {
      // Best-effort: si el backend no puede invalidar el refresh token
      // (ya expiró, backend caído, etc.), de todos modos se limpia la
      // sesión local — ver `AuthController.logout`.
    }
  }
}
