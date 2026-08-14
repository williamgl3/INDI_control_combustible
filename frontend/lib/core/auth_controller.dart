import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../models/perfil.dart';
import 'app_logger.dart';
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
    required String nombre,
    required String apellidoPaterno,
    String? apellidoMaterno,
    required String correo,
    required String usuario,
    required String password,
  }) async {
    final resultado = await _ref
        .read(authRepositoryProvider)
        .registrarChofer(
          nombre: nombre,
          apellidoPaterno: apellidoPaterno,
          apellidoMaterno: apellidoMaterno,
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

  Future<void> cambiarPassword({
    required String passwordActual,
    required String passwordNueva,
  }) {
    return _ref
        .read(authRepositoryProvider)
        .cambiarPassword(
          passwordActual: passwordActual,
          passwordNueva: passwordNueva,
        );
  }

  Future<void> logout() async {
    // Best-effort: si falla la llamada al backend (sin conexión, refresh
    // token ya expirado, etc.) de todos modos se limpia la sesión local.
    try {
      await _ref.read(authRepositoryProvider).logout();
    } catch (e) {
      AppLogger.error('AuthController.logout', e);
    }
    await _ref.read(tokenStorageProvider).borrarToken();
    await _ref.read(tokenStorageProvider).borrarRefreshToken();
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
    unawaited(precargarDatosDeSesion(perfil));
  }

  Future<void> _completarSesion(ResultadoAuth resultado) async {
    final perfil = resultado.perfil;
    await _ref.read(tokenStorageProvider).guardarToken(resultado.token);
    await _ref
        .read(tokenStorageProvider)
        .guardarRefreshToken(resultado.refreshToken);
    await _ref.read(sessionStorageProvider).guardarPerfil(perfil);
    _ref.read(sessionProvider.notifier).iniciarSesion(perfil);
    unawaited(precargarDatosDeSesion(perfil));
  }

  /// Inicia cargas independientes para la sesión ya autenticada. Es
  /// público para poder validar la matriz de roles sin iniciar navegación.
  Future<void> precargarDatosDeSesion(Perfil perfil) async {
    Future<void> aislada(String nombre, Future<void> Function() carga) async {
      try {
        await carga();
      } catch (e) {
        AppLogger.error('AuthController.precargarDatosDeSesion.$nombre', e);
      }
    }

    await Future.wait([
      aislada('unidades', () async {
        await _ref.read(catalogoUnidadesProvider.future);
      }),
      aislada('operaciones', () async {
        await _ref
            .read(operacionesRepositoryProvider)
            .cargarDatosIniciales(perfil: perfil);
        if (_ref.read(sessionProvider)?.id == perfil.id) {
          _ref.read(operacionesTickProvider.notifier).state++;
        }
      }),
      if (perfil.esAdministrativo) ...[
        aislada(
          'usuarios',
          () => _ref.read(authRepositoryProvider).cargarChoferes(),
        ),
        aislada(
          'incidencias',
          () => _ref
              .read(incidenciasRepositoryProvider)
              .cargarTodasLasIncidencias(),
        ),
        aislada(
          'evidencias',
          () => _ref
              .read(evidenciasRepositoryProvider)
              .cargarTodasLasEvidencias(),
        ),
      ] else
        aislada(
          'incidencias',
          () => _ref.read(incidenciasRepositoryProvider).cargarMisIncidencias(),
        ),
    ]);
  }
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);
