# INDI Combustible — Frontend

App Flutter (Android, iOS, Web, Windows, macOS, Linux) del sistema de control y
autorización de combustible para vehículos en obra de Grupo INDI.

## Requisitos

- Flutter SDK (canal `stable`) — ver `environment.sdk` en `pubspec.yaml` para la
  versión mínima de Dart.
- El backend corriendo (ver `../backend/README.md`) — sin esto, login/registro
  y todas las pantallas que dependen de datos reales no van a funcionar.

## Levantar el proyecto

```bash
flutter pub get
flutter run            # elige el dispositivo/emulador conectado
flutter run -d windows  # o -d chrome, -d web-server, etc.
```

## Apuntar al backend

`lib/config/api_config.dart` define `ApiConfig.baseUrl` vía
`String.fromEnvironment`, configurable en tiempo de compilación con
`--dart-define` — sin editar código ni recompilar el valor a mano:

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.83:3000
flutter build web --dart-define=API_BASE_URL=https://api.indicombustible.com
flutter build apk --release --dart-define=API_BASE_URL=https://api.indicombustible.com
```

Sin ese flag, cae al `defaultValue` del propio archivo (desarrollo local en la
LAN de la PC) — así `flutter run`/`flutter test` sin argumentos siguen
funcionando igual que siempre. Un pipeline de CI/CD real debe pasar la URL de
producción por este flag, no hardcodearla en el código fuente.

## Pruebas y análisis estático

```bash
flutter analyze
flutter test
```

Ambos se corren automáticamente en CI (`.github/workflows/frontend-ci.yml`) en
cada push/PR que toque `frontend/`.

## Estructura

- `lib/core/` — providers de Riverpod, servicios (auth, foto, OCR, recordatorios,
  logging), validadores.
- `lib/data/` — repositorios: interfaz (`*_repository.dart`), implementación
  real contra el backend (`api_*_repository.dart`) e implementación mock en
  memoria para tests (`mock_*_repository.dart`).
- `lib/models/` — modelos de dominio (`Perfil`, `Vehiculo`, `SolicitudAutorizacion`,
  `Carga`, `CierreDia`, `PrecioCombustible`).
- `lib/screens/` — pantallas, separadas por rol (`chofer/`, `administrativo/`,
  `login/`, etc.).
- `lib/theme/` — design tokens (colores, tipografía, espaciado, radios,
  sombras, motion) — nunca hardcodear estos valores fuera de aquí.
- `lib/widgets/` — componentes compartidos entre pantallas.
- `lib/router/` — rutas (`go_router`) y el guard centralizado por rol.
- `test/` — tests de flujo completo (widget tests) + tests unitarios de lógica
  pura (cálculos de rendimiento, semana laboral, CSV del concentrado).

## Limitaciones conocidas (decisiones, no bugs)

- El tema oscuro existe pero no se ha pulido — `main.dart` fija
  `themeMode: ThemeMode.light` a propósito.
- El offline-first para el rol de chofer (encolar acciones sin conexión y
  sincronizar después) todavía no está implementado — hoy solo hay detección
  de conectividad (banner "Sin conexión a internet") y mensajes de error claros
  cuando una acción falla por falta de red.
