import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../models/perfil.dart';
import 'app_logger.dart';
import 'cola_solicitudes_offline.dart';
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

    // Precarga ANTES de anunciar la sesión: el guard de rutas navega en
    // cuanto `sessionProvider` cambia, así que si `iniciarSesion` fuera
    // primero, la pantalla de inicio del chofer podría alcanzar a
    // renderizar con listas vacías por un instante antes de que lleguen
    // los datos reales. El token ya está guardado por separado
    // (`TokenStorage`, no depende de `sessionProvider`), así que
    // `_precargarDatos` puede llamar al backend sin problema.
    await _precargarDatos(perfil);
    _ref.read(sessionProvider.notifier).iniciarSesion(perfil);
  }

  Future<void> _completarSesion(ResultadoAuth resultado) async {
    final perfil = resultado.perfil;
    await _ref.read(tokenStorageProvider).guardarToken(resultado.token);
    await _ref
        .read(tokenStorageProvider)
        .guardarRefreshToken(resultado.refreshToken);
    await _ref.read(sessionStorageProvider).guardarPerfil(perfil);
    // Mismo orden que en `restaurarSesionAlIniciar` y por la misma razón.
    await _precargarDatos(perfil);
    _ref.read(sessionProvider.notifier).iniciarSesion(perfil);
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
        if (perfil.esAdministrativo) ...[
          _ref.read(authRepositoryProvider).cargarChoferes(),
          _ref.read(incidenciasRepositoryProvider).cargarTodasLasIncidencias(),
        ] else
          _ref.read(incidenciasRepositoryProvider).cargarMisIncidencias(),
      ]);
    } catch (e) {
      // Antes fallaba en silencio. Ahora, para el chofer (el centro de
      // notificaciones de `notificaciones_provider.dart` solo existe para
      // ese rol), queda un aviso visible — el manejo de conectividad ya
      // está definido (`connectivity_provider.dart` +
      // `cola_solicitudes_offline.dart`).
      if (perfil.esChofer) {
        await _ref
            .read(avisosSincronizacionOfflineProvider)
            .agregar(
              AvisoSincronizacionFallida(
                id: 'aviso-precarga-${DateTime.now().microsecondsSinceEpoch}',
                descripcion: 'Sincronización inicial',
                motivo: 'No pudimos traer tus datos más recientes.',
                ocurridoEn: DateTime.now(),
              ),
            );
      }
      AppLogger.error('AuthController._precargarDatos', e);
    }
    _ref.read(operacionesTickProvider.notifier).state++;
  }
}

final authControllerProvider = Provider<AuthController>(
  (ref) => AuthController(ref),
);
