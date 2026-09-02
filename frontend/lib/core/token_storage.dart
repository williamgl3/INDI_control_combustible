import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Timeout defensivo para toda operación de `flutter_secure_storage`. El
/// backend de Windows (Administrador de Credenciales vía win32) tiene
/// bugs conocidos de bloqueo indefinido en ciertas condiciones — sin este
/// límite, un `await` colgado ahí congela la app entera (pantalla negra
/// que ni redimensionar la ventana repinta, porque el hilo de UI está
/// esperando ese Future que nunca resuelve). Con el timeout, en el peor
/// caso la sesión no se guarda/lee y hay que volver a iniciar sesión —
/// mucho mejor que un freeze total.
const _timeoutStorage = Duration(seconds: 4);

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
    return _storage
        .write(key: _tokenKey, value: token)
        .timeout(_timeoutStorage, onTimeout: () {});
  }

  Future<String?> leerToken() {
    return _storage
        .read(key: _tokenKey)
        .timeout(_timeoutStorage, onTimeout: () => null);
  }

  Future<void> borrarToken() {
    return _storage
        .delete(key: _tokenKey)
        .timeout(_timeoutStorage, onTimeout: () {});
  }

  /// El refresh token (vida larga) se guarda aparte del access token (vida
  /// corta, 15 min) — ver `ApiClient._conRefresh`, que lo usa para pedir
  /// un access token nuevo cuando el actual expira.
  Future<void> guardarRefreshToken(String refreshToken) {
    return _storage
        .write(key: _refreshTokenKey, value: refreshToken)
        .timeout(_timeoutStorage, onTimeout: () {});
  }

  Future<String?> leerRefreshToken() {
    return _storage
        .read(key: _refreshTokenKey)
        .timeout(_timeoutStorage, onTimeout: () => null);
  }

  Future<void> borrarRefreshToken() {
    return _storage
        .delete(key: _refreshTokenKey)
        .timeout(_timeoutStorage, onTimeout: () {});
  }
}
