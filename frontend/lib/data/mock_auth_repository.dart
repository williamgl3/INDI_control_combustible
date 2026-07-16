import '../models/perfil.dart';
import '../models/vehiculo.dart';

/// Excepción lanzada por [MockAuthRepository] cuando una operación falla,
/// con un mensaje ya listo para mostrar al usuario.
class AuthException implements Exception {
  AuthException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Repositorio de autenticación MOCK.
///
/// Simula las respuestas del servidor (login, registro de chofer,
/// recuperar contraseña) con datos en memoria y una demora artificial.
/// Cuando el backend esté listo, esta clase se reemplaza por una
/// implementación real con la misma interfaz — las pantallas no deberían
/// necesitar cambios.
class MockAuthRepository {
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
        vehiculo: Vehiculo(
          tipoUnidad: 'Camión',
          modelo: 'Chevrolet NPR 2020',
          placaONumeroEconomico: 'ABC-123',
          tipoCombustible: 'Diésel',
          topeSemanal: 500,
        ),
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

  Future<Perfil> login({required String usuario, required String password}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final registro = _usuarios[usuario];
    if (registro == null || registro.password != password) {
      throw AuthException('Usuario o contraseña incorrectos.');
    }
    return registro.perfil;
  }

  /// Crea el perfil de un chofer nuevo, con su vehículo embebido, en la
  /// misma "transacción" (mock) que crea el perfil.
  ///
  /// TODO-SPEC: `topeSemanal` no se captura en el formulario de registro
  /// porque se asume que es un límite que asigna después el área
  /// administrativa (igual que antes se "asignaba" un vehículo del
  /// catálogo). Se guarda en 0 hasta que un administrativo lo edite desde
  /// EditarChoferDialog. Confirmar este supuesto contra SPEC.md.
  Future<Perfil> registrarChofer({
    required String nombreCompleto,
    required int edad,
    required String correo,
    required String usuario,
    required String password,
    required String tipoUnidad,
    required String modelo,
    required String placaONumeroEconomico,
    required String tipoCombustible,
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
      vehiculo: Vehiculo(
        tipoUnidad: tipoUnidad,
        modelo: modelo,
        placaONumeroEconomico: placaONumeroEconomico,
        tipoCombustible: tipoCombustible,
        topeSemanal: 0,
      ),
    );
    _usuarios[usuario] = (password: password, perfil: perfil);
    return perfil;
  }

  /// Lista de choferes registrados, para el panel administrativo.
  List<Perfil> listarChoferes() {
    return _usuarios.values
        .map((r) => r.perfil)
        .where((p) => p.rol == RolUsuario.chofer)
        .toList();
  }

  /// Actualiza el tope semanal del vehículo de un chofer.
  ///
  /// El tope se asigna desde el panel administrativo (no se captura en
  /// /registro-chofer): ver EditarChoferDialog.
  Future<Perfil> actualizarTopeSemanal({
    required String usuario,
    required double nuevoTope,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final registro = _usuarios[usuario];
    if (registro == null || registro.perfil.rol != RolUsuario.chofer) {
      throw AuthException('No encontramos a ese chofer.');
    }
    final perfilActualizado = registro.perfil.copyWith(
      vehiculo: registro.perfil.vehiculo!.copyWith(topeSemanal: nuevoTope),
    );
    _usuarios[usuario] = (password: registro.password, perfil: perfilActualizado);
    return perfilActualizado;
  }

  /// Simula la solicitud de recuperación de contraseña.
  ///
  /// TODO-SPEC: no implementado en la app original; aquí se define un
  /// mock funcional. Solo falla si el usuario/correo no existe entre los
  /// usuarios de prueba, para poder probar el caso de error en UI.
  Future<void> recuperarPassword({required String usuarioOCorreo}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final existe = _usuarios.values.any(
      (r) => r.perfil.usuario == usuarioOCorreo || r.perfil.correo == usuarioOCorreo,
    );
    if (!existe) {
      throw AuthException('No encontramos una cuenta con ese usuario o correo.');
    }
  }
}
