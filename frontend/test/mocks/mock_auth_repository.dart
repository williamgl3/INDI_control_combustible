import 'package:indi_combustible/data/auth_repository.dart';
import 'package:indi_combustible/models/perfil.dart';

/// Repositorio de autenticación MOCK.
///
/// Simula las respuestas del servidor (login, registro de chofer,
/// recuperar contraseña) con datos en memoria y una demora artificial.
/// Útil para tests de widgets (evita depender de un backend real) y como
/// referencia de la interfaz que implementa `ApiAuthRepository`.
class MockAuthRepository implements AuthRepository {
  MockAuthRepository();

  /// Usuarios de prueba precargados para poder probar el login sin pasar
  /// por /registro-chofer.
  final Map<String, ({String password, Perfil perfil})> _usuarios = {
    'chofer1': (
      password: 'chofer123',
      perfil: Perfil(
        id: 'mock-chofer-1',
        usuario: 'chofer1',
        nombre: 'Juan',
        apellidoPaterno: 'Pérez',
        correo: 'chofer1@example.com',
        fechaNacimiento: DateTime(1996, 3, 10),
        rol: RolUsuario.chofer,
      ),
    ),
    'admin1': (
      password: 'admin1234',
      perfil: Perfil(
        id: 'mock-admin-1',
        usuario: 'admin1',
        nombre: 'Ana',
        apellidoPaterno: 'Torres',
        correo: 'admin1@example.com',
        fechaNacimiento: DateTime(1991, 8, 22),
        rol: RolUsuario.administrativo,
      ),
    ),
    'superadmin1': (
      password: 'superadmin1234',
      perfil: Perfil(
        id: 'mock-superadmin-1',
        usuario: 'superadmin1',
        nombre: 'Sofía',
        apellidoPaterno: 'Reyes',
        correo: 'superadmin1@example.com',
        rol: RolUsuario.superadmin,
      ),
    ),
  };

  /// Usuario de la última sesión iniciada — necesario porque este mock
  /// no tiene un token/contexto real de sesión, a diferencia del backend
  /// (que identifica al usuario por el JWT en `cambiarPassword`).
  String? _usuarioActual;

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
    if (!registro.perfil.activo) {
      throw AuthException('Este usuario está desactivado.');
    }
    _usuarioActual = usuario;
    return (
      perfil: registro.perfil,
      token: 'mock-token-${registro.perfil.id}',
      refreshToken: 'mock-refresh-${registro.perfil.id}',
    );
  }

  /// Crea el perfil de un chofer nuevo — solo datos personales. El
  /// vehículo ya NO se captura aquí: se elige del catálogo compartido
  /// (`Vehiculo`) en cada solicitud/comprobación de carga, porque
  /// distintos choferes pueden usar distintas unidades en días distintos.
  @override
  Future<ResultadoAuth> registrarChofer({
    required String nombre,
    required String apellidoPaterno,
    String? apellidoMaterno,
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
      nombre: nombre,
      apellidoPaterno: apellidoPaterno,
      apellidoMaterno: apellidoMaterno,
      correo: correo,
      rol: RolUsuario.chofer,
    );
    _usuarios[usuario] = (password: password, perfil: perfil);
    _usuarioActual = usuario;
    return (
      perfil: perfil,
      token: 'mock-token-${perfil.id}',
      refreshToken: 'mock-refresh-${perfil.id}',
    );
  }

  @override
  Future<void> cambiarPassword({
    required String passwordActual,
    required String passwordNueva,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final usuario = _usuarioActual;
    final registro = usuario == null ? null : _usuarios[usuario];
    if (registro == null || registro.password != passwordActual) {
      throw AuthException('La contraseña actual no es correcta.');
    }
    _usuarios[usuario!] = (password: passwordNueva, perfil: registro.perfil);
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
  Future<PaginaChoferes> cargarChoferes({
    String buscar = '',
    String estado = 'todos',
    int pagina = 1,
    int limite = 25,
  }) async {
    var datos = listarChoferes()
        .where(
          (p) =>
              (estado == 'todos' || (estado == 'activo') == p.activo) &&
              (buscar.isEmpty ||
                  p.nombreCompleto.toLowerCase().contains(
                    buscar.toLowerCase(),
                  ) ||
                  p.usuario.toLowerCase().contains(buscar.toLowerCase())),
        )
        .toList();
    return (
      datos: datos,
      pagina: pagina,
      limite: limite,
      total: datos.length,
      totalPaginas: datos.isEmpty ? 0 : 1,
    );
  }

  @override
  Future<DetalleChofer> obtenerChofer(String usuarioId) async {
    final p = listarChoferes().firstWhere(
      (p) => p.id == usuarioId,
      orElse: () => throw AuthException('Chofer no encontrado.'),
    );
    return (
      chofer: p,
      actividad: (
        solicitudes: 0,
        cargas: 0,
        evidencias: 0,
        incidencias: 0,
        cierres: 0,
        recorridos: 0,
        despachos: 0,
        auditoria: 0,
      ),
    );
  }

  @override
  Future<Perfil> editarChofer({
    required String usuarioId,
    required String version,
    required Map<String, dynamic> cambios,
  }) async {
    final entrada = _usuarios.entries.firstWhere(
      (e) => e.value.perfil.id == usuarioId,
      orElse: () => throw AuthException('Chofer no encontrado.'),
    );
    final p = entrada.value.perfil;
    final actualizado = p.copyWith(
      nombre: cambios['nombre'] as String?,
      apellidoPaterno: cambios['apellidoPaterno'] as String?,
      apellidoMaterno: cambios['apellidoMaterno'] as String?,
      correo: cambios['correo'] as String?,
      usuario: cambios['usuario'] as String?,
      version: '${int.tryParse(p.version) ?? 0 + 1}',
    );
    _usuarios.remove(entrada.key);
    _usuarios[actualizado.usuario] = (
      password: entrada.value.password,
      perfil: actualizado,
    );
    return actualizado;
  }

  @override
  Future<Perfil> cambiarEstado({
    required String usuarioId,
    required bool activo,
    required String motivo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final entrada = _usuarios.entries.firstWhere(
      (e) => e.value.perfil.id == usuarioId,
      orElse: () => throw AuthException('Usuario no encontrado.'),
    );
    _usuarios[entrada.key] = (
      password: entrada.value.password,
      perfil: entrada.value.perfil.copyWith(activo: activo),
    );
    return _usuarios[entrada.key]!.perfil;
  }

  @override
  Future<String> resetearPassword({
    required String usuarioId,
    required String motivo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    _usuarios.entries.firstWhere(
      (e) => e.value.perfil.id == usuarioId,
      orElse: () => throw AuthException('Usuario no encontrado.'),
    );
    return 'La solicitud quedó registrada. El envío seguro aún no está configurado; la contraseña no fue modificada.';
  }

  @override
  Future<ElegibilidadEliminacion> consultarElegibilidadEliminacion(
    String usuarioId,
  ) async => (elegible: true, tieneRelaciones: false);

  @override
  Future<void> eliminarChofer({
    required String usuarioId,
    required String usuarioConfirmado,
    required String motivo,
  }) async {
    final entrada = _usuarios.entries.firstWhere(
      (e) => e.value.perfil.id == usuarioId,
      orElse: () => throw AuthException('Chofer no encontrado.'),
    );
    if ('@${entrada.value.perfil.usuario}' != usuarioConfirmado) {
      throw AuthException('La confirmación no coincide.');
    }
    _usuarios.remove(entrada.key);
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
    await Future.delayed(const Duration(milliseconds: 300));
    if (_usuarios.containsKey(usuario)) {
      throw AuthException('Ese usuario ya está en uso.');
    }
    final perfil = Perfil(
      id: 'mock-admin-${_usuarios.length + 1}',
      usuario: usuario,
      nombre: nombre,
      apellidoPaterno: apellidoPaterno,
      apellidoMaterno: apellidoMaterno,
      correo: correo,
      fechaNacimiento: DateTime(1990, 1, 1),
      rol: RolUsuario.administrativo,
    );
    _usuarios[usuario] = (password: password, perfil: perfil);
    return perfil;
  }

  /// No hay backend que invalidar — no hace nada.
  @override
  Future<void> logout() async {}

  /// Simula la solicitud de recuperación de contraseña.
  ///
  /// Solo falla si el usuario/correo no existe entre los usuarios de
  /// prueba, para poder probar el caso de error en UI.
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
