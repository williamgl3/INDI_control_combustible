import 'package:flutter/foundation.dart';

/// URL del backend, resuelta en este orden:
///
/// 1. `--dart-define=API_BASE_URL=...` si se pasó al compilar/correr —
///    así producción apunta a un dominio HTTPS sin tocar código:
///
///      flutter build web --dart-define=API_BASE_URL=https://api.indicombustible.com
///      flutter build apk --release --dart-define=API_BASE_URL=https://api.indicombustible.com
///
/// 2. Si no se pasó el flag, un default según la plataforma de destino
///    (desarrollo local, con el backend corriendo en la misma PC):
///
///      - Emulador de Android: `http://10.0.2.2:3000` — dentro del
///        emulador, `localhost` apunta al propio emulador, no al host;
///        `10.0.2.2` es el alias especial que Android mapea al
///        `localhost` de la PC que lo corre.
///        Comando: `flutter run` (con el emulador ya iniciado).
///      - Web / desktop (Chrome, Windows, etc.): `http://localhost:3000`.
///        Comando: `flutter run -d chrome` (o `-d windows`, etc.).
class ApiConfig {
  static const String _envOverride = String.fromEnvironment('API_BASE_URL');

  static String get baseUrl {
    if (_envOverride.isNotEmpty) return _envOverride;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:3000';
    }
    return 'http://localhost:3000';
  }
}
