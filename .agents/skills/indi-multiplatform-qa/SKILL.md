---
name: indi-multiplatform-qa
description: Valida cambios de INDI Combustible en Web, Android, iOS y escritorio, incluidos responsive, accesibilidad, plugins, conectividad, builds y contrato API. Úsala para planes o ejecución de QA multiplataforma; no la uses como sustituto de pruebas unitarias ordinarias sin impacto de plataforma.
---

# QA multiplataforma de INDI Combustible

Selecciona una matriz por riesgo usando [references/platform-matrix.md](references/platform-matrix.md); no declares soporte basándote solo en que el código compila.

## Flujo

1. Identifica superficies afectadas: layout, navegación/guard, almacenamiento seguro, cámara/galería/OCR, notificaciones, archivos/share, red/offline o configuración de API.
2. Ejecuta primero las puertas baratas: `flutter analyze`, `flutter test`, `npm run build` y `npm test` según el alcance.
3. Prueba tamaños representativos y texto escalado. Busca overflow, clipping, scroll, teclado, foco, orientación, safe areas, contraste y controles solo-icono sin semántica.
4. Para plugins, prueba éxito, cancelación, permiso denegado y denegado permanentemente; confirma manifiestos/entitlements por plataforma.
5. Para red, prueba sin conexión, timeout, `401` con refresh, `403`, `409`, reintento, reinicio con cola pendiente y cambio de sesión. No ocultes conflictos como éxitos.
6. Registra por plataforma: comando/dispositivo, resultado observable, evidencia y limitación. Distingue `aprobado`, `falló`, `bloqueado` y `no ejecutado`.

## Seguridad de ambientes

Usa una API y base de datos de desarrollo/pruebas identificadas. Pasa la URL mediante `--dart-define=API_BASE_URL=...`. No uses seeds, cargas de archivos ni pruebas de escritura contra producción.

