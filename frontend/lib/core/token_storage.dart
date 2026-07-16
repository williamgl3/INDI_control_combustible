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

  Future<void> guardarToken(String token) {
    return _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> leerToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<void> borrarToken() {
    return _storage.delete(key: _tokenKey);
  }
}
