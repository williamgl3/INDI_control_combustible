import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Interfaz simple de almacenamiento seguro del token de sesión.
///
/// No implementa lógica de autenticación todavía — solo guardar / leer /
/// borrar, para que Login (tanda futura) no tenga que migrar desde
/// SharedPreferences.
class TokenStorage {
  TokenStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'auth_refresh_token';

  Future<void> guardarToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> leerToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> borrarToken() {
    return _storage.delete(key: _tokenKey);
  }

  /// El refresh token (vida larga) se guarda aparte del access token (vida
  /// corta, 15 min) — ver `ApiClient._conRefresh`, que lo usa para pedir
  /// un access token nuevo cuando el actual expira.
  Future<void> guardarRefreshToken(String refreshToken) {
    return _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> leerRefreshToken() {
    return _storage.read(key: _refreshTokenKey);
  }

  Future<void> borrarRefreshToken() {
    return _storage.delete(key: _refreshTokenKey);
  }
}
