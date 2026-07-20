import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../models/perfil.dart';
import 'providers.dart';
import 'session_provider.dart';

/// Orquesta login / registro de chofer / recuperar contraseña: llama al
/// repositorio real, y si hay éxito persiste token + perfil, precarga
/// los datos que las pantallas necesitan, y actualiza [sessionProvider].
/// El guard de rutas reacciona solo al cambio de sesión.
class AuthController {
  AuthController(this._ref);
  final Ref _ref;

  Future<void> login({
    required String usuario,
    required String password,
  }) async {
    final resultado = await _ref
        .read(authRepositoryProvider)
        .login(usuario: usuario, password: password);
    await _completarSesion(resultado);
  }

  Future<void> registrarChofer({
    required String nombreCompleto,
    required int edad,
    required String correo,
    required String usuario,
    required String password,
  }) async {
    final resultado = await _ref
        .read(authRepositoryProvider)
        .registrarChofer(
          nombreCompleto: nombreCompleto,
          edad: edad,
          correo: correo,
          usuario: usuario,
          password: password,
        );
    await _completarSesion(resultado);
  }

  Future<void> recuperarPassword({required String usuarioOCorreo}) {
    return _ref
        .read(authRepositoryProvider)
        .recuperarPassword(usuarioOCorreo: usuarioOCorreo);
  }

  Future<void> logout() async {
    await _ref.read(tokenStorageProvider).borrarToken();
    await _ref.read(sessionStorageProvider).borrarPerfil();
    _ref.read(sessionProvider.notifier).cerrarSesion();
  }

  /// Se llama una sola vez al arrancar la app (ver `restaurarSesionProvider`
  /// en providers.dart): si hay un token+perfil guardados de una sesión
  /// anterior, la restaura y precarga sus datos — sin esto, el usuario
  /// volvería al login en cada reinicio de la app aunque su sesión siga
  /// vigente.
  Future<void> restaurarSesionAlIniciar() async {
    final token = await _ref.read(tokenStorageProvider).leerToken();
    final perfil = await _ref.read(sessionStorageProvider).leerPerfil();
    if (token == null || perfil == null) return;

    _ref.read(sessionProvider.notifier).iniciarSesion(perfil);
    await _precargarDatos(perfil);
  }

  Future<void> _completarSesion(ResultadoAuth resultado) async {
    final perfil = resultado.perfil;
    await _ref.read(tokenStorageProvider).guardarToken(resultado.token);
    await _ref.read(sessionStorageProvider).guardarPerfil(perfil);
    _ref.read(sessionProvider.notifier).iniciarSesion(perfil);
    await _precargarDatos(perfil);
  }

  Future<void> _precargarDatos(Perfil perfil) async {
    // Con la sesión ya lista (token guardado, así que el ApiClient lo
    // manda en cada petición), se precarga todo lo que las pantallas
    // leen de forma síncrona de los repositorios (ver
    // `operacionesTickProvider`). Si falla (sin conexión, etc.), no se
    // interrumpe el login — las pantallas simplemente verán listas
    // vacías hasta que se reintente.
    try {
      await Future.wait([
        _ref.read(vehiculosRepositoryProvider).cargarVehiculos(),
        _ref
            .read(operacionesRepositoryProvider)
            .cargarDatosIniciales(perfil: perfil),
        if (perfil.esAdministrativo)
          _ref.read(authRepositoryProvider).cargarChoferes(),
      ]);
    } catch (_) {
      // TODO-BACKEND: mostrar un aviso de "no se pudo sincronizar" en vez
      // de fallar en silencio, cuando se defina el manejo de conectividad.
    }
    _ref.read(operacionesTickProvider.notifier).state++;
  }
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);
