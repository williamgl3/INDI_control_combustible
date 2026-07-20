import '../models/perfil.dart';
import 'auth_repository.dart';

/// Repositorio de autenticación MOCK.
///
/// Simula las respuestas del servidor (login, registro de chofer,
/// recuperar contraseña) con datos en memoria y una demora artificial.
/// Útil para tests de widgets (evita depender de un backend real) y como
/// referencia de la interfaz que implementa `ApiAuthRepository`.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  /// Usuarios de prueba precargados para poder probar el login sin pasar
  /// por /registro-chofer. TODO-SPEC: eliminar/ajustar cuando exista
  /// backend real.
  final Map<String, ({String password, Perfil perfil})> _usuarios = {
    'chofer1': (
      password: 'chofer123',
      perfil: const Perfil(
        id: 'mock-chofer-1',
        usuario: 'chofer1',
        nombreCompleto: 'Juan Pérez',
        correo: 'chofer1@example.com',
        edad: 30,
        rol: RolUsuario.chofer,
      ),
    ),
    'admin1': (
      password: 'admin1234',
      perfil: const Perfil(
        id: 'mock-admin-1',
        usuario: 'admin1',
        nombreCompleto: 'Ana Torres',
        correo: 'admin1@example.com',
        edad: 35,
        rol: RolUsuario.administrativo,
      ),
    ),
  };

  @override
  Future<ResultadoAuth> login({
    required String usuario,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final registro = _usuarios[usuario];
    if (registro == null || registro.password != password) {
      throw AuthException('Usuario o contraseña incorrectos.');
    }
    return (perfil: registro.perfil, token: 'mock-token-${registro.perfil.id}');
  }

  /// Crea el perfil de un chofer nuevo — solo datos personales. El
  /// vehículo ya NO se captura aquí: se elige del catálogo compartido
  /// (`Vehiculo`) en cada solicitud/comprobación de carga, porque
  /// distintos choferes pueden usar distintas unidades en días distintos.
  @override
  Future<ResultadoAuth> registrarChofer({
    required String nombreCompleto,
    required int edad,
    required String correo,
    required String usuario,
    required String password,
  }) async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (_usuarios.containsKey(usuario)) {
      throw AuthException('Ese usuario ya está en uso.');
    }
    final perfil = Perfil(
      id: 'mock-chofer-${_usuarios.length + 1}',
      usuario: usuario,
      nombreCompleto: nombreCompleto,
      correo: correo,
      edad: edad,
      rol: RolUsuario.chofer,
    );
    _usuarios[usuario] = (password: password, perfil: perfil);
    return (perfil: perfil, token: 'mock-token-${perfil.id}');
  }

  /// Lista de choferes registrados, para el panel administrativo.
  @override
  List<Perfil> listarChoferes() {
    return _usuarios.values
        .map((r) => r.perfil)
        .where((p) => p.rol == RolUsuario.chofer)
        .toList();
  }

  /// Ya están "cargados" desde el constructor — no hace nada.
  @override
  Future<void> cargarChoferes() async {}

  /// Simula la solicitud de recuperación de contraseña.
  ///
  /// TODO-SPEC: no implementado en la app original; aquí se define un
  /// mock funcional. Solo falla si el usuario/correo no existe entre los
  /// usuarios de prueba, para poder probar el caso de error en UI.
  @override
  Future<void> recuperarPassword({required String usuarioOCorreo}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final existe = _usuarios.values.any(
      (r) =>
          r.perfil.usuario == usuarioOCorreo ||
          r.perfil.correo == usuarioOCorreo,
    );
    if (!existe) {
      throw AuthException(
        'No encontramos una cuenta con ese usuario o correo.',
      );
    }
  }
}
