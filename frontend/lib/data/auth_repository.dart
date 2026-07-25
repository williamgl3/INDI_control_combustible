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
/// sesión (de vida corta, 15 min) y el refresh token (de vida larga) que
/// hay que persistir (ver `AuthController._completarSesion`).
typedef ResultadoAuth = ({Perfil perfil, String token, String refreshToken});

/// Interfaz común de autenticación — implementada por [MockAuthRepository]
/// (datos en memoria) y por la implementación real que habla con el
/// backend. Las pantallas y [AuthController] dependen solo de esta
/// interfaz, nunca de una implementación concreta.
abstract class AuthRepository {
  Future<ResultadoAuth> login({required String usuario, required String password});

  Future<ResultadoAuth> registrarChofer({
    required String nombre,
    required String apellidoPaterno,
    String? apellidoMaterno,
    required String correo,
    required String usuario,
    required String password,
  });

  Future<void> recuperarPassword({required String usuarioOCorreo});

  /// Cambiar contraseña estando ya logueado (distinto de
  /// [recuperarPassword], para cuando el usuario la olvidó). Usada por
  /// "Mi perfil".
  Future<void> cambiarPassword({
    required String passwordActual,
    required String passwordNueva,
  });

  /// Lista de choferes ya cargada en memoria — ver [cargarChoferes].
  List<Perfil> listarChoferes();

  /// Trae/actualiza la lista de choferes desde el backend. Se llama una
  /// vez tras iniciar sesión como administrativo (ver
  /// `AuthController._cargarDatosIniciales`). Puede incluir también
  /// usuarios administrativos (ver [Perfil.activo]/[Perfil.rol]).
  Future<void> cargarChoferes();

  /// Activa/desactiva un usuario (chofer o administrativo). Un usuario
  /// desactivado no puede iniciar sesión. Actualiza la copia en memoria
  /// de [listarChoferes] si el usuario está en esa lista.
  Future<void> cambiarEstado({required String usuarioId, required bool activo});

  /// Restablece la contraseña de otro usuario — acción de un
  /// administrativo, distinta de [cambiarPassword] (que es para la
  /// propia sesión).
  Future<void> resetearPassword({
    required String usuarioId,
    required String passwordNueva,
  });

  /// Crea un nuevo usuario con rol administrativo.
  Future<Perfil> crearAdministrativo({
    required String nombre,
    required String usuario,
    required String correo,
    required String password,
  });

  /// Invalida el refresh token en el backend (best-effort — se llama
  /// antes de borrar el storage local en `AuthController.logout`, y si
  /// falla de todos modos se limpia la sesión local).
  Future<void> logout();
}
