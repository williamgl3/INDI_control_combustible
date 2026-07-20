import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/perfil.dart';

/// Almacenamiento local del perfil de sesión completo (incluyendo, si el
/// rol es chofer, sus datos de vehículo embebidos).
///
/// Se guarda junto al token para que, tras iniciar sesión, el perfil esté
/// disponible de inmediato sin volver a pedirlo — en particular para
/// precargar modelo/placa en /chofer/comprobar.
///
/// Por ahora es solo la interfaz: se llenará con datos mock en la tanda
/// donde se construyan Login/Registro.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _perfilKey = 'perfil_sesion';

  Future<void> guardarPerfil(Perfil perfil) {
    return _storage.write(key: _perfilKey, value: jsonEncode(perfil.toJson()));
  }

  Future<Perfil?> leerPerfil() async {
    final raw = await _storage.read(key: _perfilKey);
    if (raw == null) return null;
    return Perfil.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> borrarPerfil() {
    return _storage.delete(key: _perfilKey);
  }
}
