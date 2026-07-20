---
name: flutter-conventions
description: "Usa esta skill siempre que crees nuevos archivos Dart, features, widgets o pantallas en este proyecto Flutter. Define la estructura de carpetas, convenciones de nombres y gestión de estado que debe seguir todo el código nuevo para mantener consistencia."
---

# Convenciones del proyecto Flutter — INDI Combustible

## Estructura de carpetas real
```
lib/
  config/         -> api_config.dart (config de entorno/API)
  core/           -> providers.dart (Riverpod), servicios (foto_picker,
                     ticket_ocr_service, recordatorio_service, exportador_service),
                     auth_controller, session_provider/session_storage,
                     token_storage, validators, semana_util, catalogos_vehiculo
  data/           -> mock_*_repository.dart — TODO-BACKEND: reemplazables por
                     repos reales con la misma interfaz pública
  models/         -> entidades inmutables (@immutable, copyWith/fromJson/toJson)
  router/         -> app_router.dart (go_router + GoRoute), route_paths.dart
                     (rutas centralizadas), placeholder_screen.dart
  screens/
    login/, registro_chofer/, recuperar_password/   -> pantallas públicas
    chofer/         -> pantallas + diálogos de la app del chofer
    administrativo/
      tabs/         -> una pestaña del panel admin por archivo
      *_dialog.dart -> diálogos específicos de una pantalla admin
  theme/          -> tokens de design-system (ver esa skill) + app_theme.dart
                     (arma el ThemeData y expone context.colors/context.shadows)
  widgets/        -> componentes compartidos entre features (ver skill
                     component-library) — carpeta PLANA, sin subcarpetas
```

No existe una carpeta `features/`; el proyecto separa por tipo (screens/widgets/
models/data) en vez de por feature verticalizada. No la introduzcas sin discutirlo
primero — sería una reestructuración grande, no un cambio incremental.

## Gestión de estado
**Riverpod** (`flutter_riverpod`), no Provider a secas. Patrones establecidos:
- Providers globales centralizados en `lib/core/providers.dart` (uno por
  repositorio/servicio: `authRepositoryProvider`, `operacionesRepositoryProvider`,
  `vehiculosRepositoryProvider`, `exportadorServiceProvider`, etc.).
- `ConsumerWidget`/`ConsumerStatefulWidget` para cualquier widget que lea un
  provider; `setState` solo para estado puramente local (texto de un controller,
  toggle de un valor visual) que no vive en un repositorio.
- **Patrón `operacionesTickProvider`**: los repos mock (`MockOperacionesRepository`,
  `MockVehiculosRepository`) son objetos mutables en memoria, no `StateNotifier` —
  mutarlos no notifica a Riverpod, y GoRouter a veces reutiliza una pantalla ya
  en el stack sin reconstruirla. Cualquier pantalla que lea datos de estos repos
  debe hacer `ref.watch(operacionesTickProvider)` ADEMÁS de `ref.watch(elRepoProvider)`;
  cualquier acción que mute el repo debe incrementar
  `ref.read(operacionesTickProvider.notifier).state++` al terminar. Sin esto, la
  UI no refleja cambios recién guardados.

## Nombres
- Archivos: `snake_case.dart`
- Clases: `PascalCase`
- Widgets de pantalla completa: sufijo `Screen` (ej. `MantenimientoTab` es una
  excepción intencional — las pestañas del panel admin usan sufijo `Tab`, no
  `Screen`, porque viven dentro del shell de `AdministrativoHomeScreen`)
- Diálogos modales: sufijo `Dialog`, con un método estático `show(context, ...)`
  que llama a `mostrarDialogoApp` (ver skill `component-library`)
- Widgets privados de un archivo: prefijo `_`, nombre descriptivo en español
  acorde al dominio (ej. `_ItemSidebar`, `_TarjetaMantenimiento`, `_BotonPaso`)
- Modelos: nombre singular en `PascalCase` (ej. `Vehiculo`, `CierreDia`)
- El código de dominio (nombres de clases, variables, comentarios, mensajes de
  UI) está en **español** — sigue esa convención en archivos nuevos, no mezcles
  inglés salvo términos técnicos sin traducción natural (`Screen`, `Dialog`, `Tab`).

## Navegación
`go_router` con rutas centralizadas en `lib/router/route_paths.dart`
(`RoutePaths`) y registradas en `lib/router/app_router.dart`. Todas las páginas
usan el helper `_conTransicion(state, child)` (fade + slide sutil con
`AppMotion.base`/`AppMotion.curve`) en vez de la transición default de la
plataforma — no uses `MaterialPageRoute`/`Navigator.push` directo para navegación
de pantalla completa. `Navigator.of(context).pop(valor)` sigue siendo correcto
para cerrar diálogos (`mostrarDialogoApp` ya maneja la apertura).

El guard de sesión (`_redirigirSegunSesion` en `app_router.dart`) centraliza
las reglas de acceso por rol (chofer/administrativo) — no agregues checks de
sesión ad-hoc dentro de una pantalla.

## Responsive
Usa `AppBreakpoints` (`lib/theme/app_breakpoints.dart`), no números sueltos:
`AppBreakpoints.isMobile(width)` / `isTabletOrDesktop(width)` contra
`MediaQuery.sizeOf(context).width`. Confirmado por el usuario: el panel
administrativo es sidebar en tablet/desktop (`>= 700`) y bottom nav en móvil
(`< 700`) — ver `AdministrativoHomeScreen` como referencia de implementación.

## Mocks y TODO-BACKEND
Todo repositorio en `lib/data/` es un mock en memoria pensado para ser
reemplazado por un cliente HTTP real con la MISMA interfaz pública — manténla
estable (mismos nombres de métodos, mismos tipos de retorno) al modificar mocks,
y marca con un comentario `TODO-BACKEND` cualquier decisión que dependa de cómo
se implemente el backend real. Usa `TODO-SPEC` para valores placeholder
(intervalos, umbrales, catálogos) pendientes de confirmar contra una
especificación formal.
