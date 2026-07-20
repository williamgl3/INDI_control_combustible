import '../models/perfil.dart';

/// Excepción lanzada por un [AuthRepository] cuando una operación falla,
/// con un mensaje ya listo para mostrar al usuario.
class AuthException implements Exception {
  AuthException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Resultado de login/registro: el perfil autenticado + el token de
/// sesión que hay que persistir (ver `AuthController._completarSesion`).
typedef ResultadoAuth = ({Perfil perfil, String token});

/// Interfaz común de autenticación — implementada por [MockAuthRepository]
/// (datos en memoria) y por la implementación real que habla con el
/// backend. Las pantallas y [AuthController] dependen solo de esta
/// interfaz, nunca de una implementación concreta.
abstract class AuthRepository {
  Future<ResultadoAuth> login({required String usuario, required String password});

  Future<ResultadoAuth> registrarChofer({
    required String nombreCompleto,
    required int edad,
    required String correo,
    required String usuario,
    required String password,
  });

  Future<void> recuperarPassword({required String usuarioOCorreo});

  /// Lista de choferes ya cargada en memoria — ver [cargarChoferes].
  List<Perfil> listarChoferes();

  /// Trae/actualiza la lista de choferes desde el backend. Se llama una
  /// vez tras iniciar sesión como administrativo (ver
  /// `AuthController._cargarDatosIniciales`).
  Future<void> cargarChoferes();
}
