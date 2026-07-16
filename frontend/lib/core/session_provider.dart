import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/perfil.dart';

/// Estado de sesión actual. `perfil == null` significa "sin sesión".
///
/// Por ahora es un provider mock sin lógica de autenticación real —
/// Login (tanda futura) lo actualizará tras validar credenciales y leer
/// [SessionStorage].
class SessionController extends Notifier<Perfil?> {
  @override
  Perfil? build() => null;

  void iniciarSesion(Perfil perfil) => state = perfil;

  void cerrarSesion() => state = null;
}

final sessionProvider = NotifierProvider<SessionController, Perfil?>(
  SessionController.new,
);
