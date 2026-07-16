import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/perfil.dart';
import 'providers.dart';
import 'session_provider.dart';

/// Orquesta login / registro de chofer / recuperar contraseña: llama al
/// repositorio (mock por ahora), y si hay éxito persiste token + perfil
/// y actualiza [sessionProvider]. El guard de rutas reacciona solo al
/// cambio de sesión.
class AuthController {
  AuthController(this._ref);
  final Ref _ref;

  Future<void> login({required String usuario, required String password}) async {
    final perfil = await _ref
        .read(authRepositoryProvider)
        .login(usuario: usuario, password: password);
    await _completarSesion(perfil);
  }

  Future<void> registrarChofer({
    required String nombreCompleto,
    required int edad,
    required String correo,
    required String usuario,
    required String password,
  }) async {
    final perfil = await _ref.read(authRepositoryProvider).registrarChofer(
          nombreCompleto: nombreCompleto,
          edad: edad,
          correo: correo,
          usuario: usuario,
          password: password,
        );
    await _completarSesion(perfil);
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

  Future<void> _completarSesion(Perfil perfil) async {
    await _ref.read(tokenStorageProvider).guardarToken('mock-token-${perfil.id}');
    await _ref.read(sessionStorageProvider).guardarPerfil(perfil);
    _ref.read(sessionProvider.notifier).iniciarSesion(perfil);
  }
}

final authControllerProvider = Provider<AuthController>((ref) => AuthController(ref));
