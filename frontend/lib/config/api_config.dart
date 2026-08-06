class ApiConfig {
  /// URL del backend — configurable en tiempo de compilación vía
  /// `--dart-define=API_BASE_URL=...`, sin tocar código ni recompilar
  /// manualmente entre entornos:
  ///
  ///   flutter run --dart-define=API_BASE_URL=http://192.168.1.83:3000
  ///   flutter build web --dart-define=API_BASE_URL=https://api.indicombustible.com
  ///
  /// Sin ese flag, cae al valor de `defaultValue` de abajo (desarrollo
  /// local en la LAN de la PC) — así el flujo de trabajo diario de
  /// `flutter run`/`flutter test` sigue igual que antes, y un pipeline de
  /// CI/CD real define la URL de producción por fuera del código fuente.
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    // Desarrollo local — IP de LAN de la PC (ver `ipconfig`, adaptador
    // Wi-Fi) mientras celular y PC estén en la misma red. Usa
    // 'http://localhost:3000' para correr solo en el navegador/emulador
    // de la misma PC.
    defaultValue: 'http://192.168.1.83:3000',
  );
}
