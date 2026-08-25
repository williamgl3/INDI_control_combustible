---
name: indi-flutter-frontend
description: Desarrolla y modifica el frontend Flutter multiplataforma de INDI Combustible, incluidos UI, Riverpod, navegación, repositorios HTTP, offline y pruebas. Úsala para cambios dentro de frontend/; no aplica a cambios exclusivos de la API.
---

# Frontend Flutter de INDI Combustible

Trabaja sobre `frontend/` y conserva la arquitectura existente. Antes de editar, localiza una pantalla o flujo análogo y revisa las reglas visuales en `.claude/skills/design-system/SKILL.md`, los componentes en `.claude/skills/component-library/SKILL.md` y las adaptaciones en `.claude/skills/platform-adaptations/SKILL.md` cuando el cambio afecte UI o plataformas. Esas guías aportan intención, pero el código vigente en `frontend/lib/theme/`, `frontend/lib/widgets/` y `pubspec.yaml` prevalece si difieren.

## Arquitectura que se debe preservar

- Mantén la separación actual: `models/`, contratos y adaptadores en `data/`, providers/servicios en `core/`, rutas en `router/`, pantallas en `screens/`, tokens en `theme/` y componentes compartidos en `widgets/`. No introduzcas una arquitectura `features/` como cambio incidental.
- Usa Riverpod. El estado de sesión vive en `sessionProvider`; los repositorios se inyectan desde `core/providers.dart`. Usa estado local solo para interacción efímera del widget.
- Añade rutas mediante `RoutePaths` y `app_router.dart`. Conserva el guard central por rol y las transiciones de `app_route_transitions.dart`; no uses `Navigator.push` para pantallas completas.
- Trata las interfaces de repositorio como frontera estable. El código de UI no debe conocer HTTP, headers, JSON ni almacenamiento de tokens.
- Configura la API con `ApiConfig.baseUrl` y `--dart-define=API_BASE_URL=...`; no hardcodees hosts.
- Mantén nombres y texto de dominio en español.

## Flujo de implementación

1. Traza el flujo desde pantalla/provider hasta interfaz y adaptador `api_*_repository.dart`. Busca pruebas existentes del mismo dominio.
2. Modela respuestas de red de forma defensiva. Conserva compatibilidad con los contratos vigentes y no conviertas silenciosamente errores o conflictos en éxitos.
3. Para escrituras, contempla doble toque, expiración/refresh de sesión, reintento y conectividad. Solo encola offline operaciones cuyo contrato tenga idempotencia y datos suficientes; las operaciones Marimba/Pipa que no la tengan deben fallar de forma visible.
4. Reutiliza widgets en `lib/widgets/`, tokens de `lib/theme/` y breakpoints de `AppBreakpoints`. Comprueba teclado, áreas seguras, scroll, texto escalado y estados loading/error/empty.
5. Agrega o ajusta pruebas junto al comportamiento: modelos/contratos para serialización, providers/repositorios para estado y widget tests para interacción y responsive.

## Verificación proporcional

Desde `frontend/`, ejecuta primero `dart format` sobre los archivos tocados y luego:

```text
flutter analyze
flutter test
```

Para cambios específicos de plataforma, valida al menos el destino afectado con `flutter build <destino>` o una ejecución manual. Si el wrapper de Flutter queda bloqueado, informa el comando exacto y usa el binario Dart del SDK para análisis cuando sea posible; no afirmes que una plataforma pasó sin compilarla o ejecutarla.
