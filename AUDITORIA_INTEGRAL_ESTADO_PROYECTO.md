# Auditoría integral — INDI Control de Combustible

Fecha: 2026-08-20  
Rama auditada: dev-frontend  
Alcance: diagnóstico estático, compilación backend y pruebas disponibles. No se modificó código productivo ni datos.

## 1. Resumen ejecutivo

La aplicación tiene una base funcional amplia: Flutter contiene autenticación, operación de chofer/supervisor, panel administrativo, recorridos Marimba/Pipa, evidencias, offline y navegación por roles. Node.js expone servicios equivalentes con Zod, JWT rotativo, rate limiting, uploads validados y migraciones SQL.

Evidencia positiva:
- Backend TypeScript compila.
- Backend: 109 pruebas aprobadas y 11 omitidas.
- Dart Analyzer: sin issues.
- El árbol de rutas y repositorios cubre los dominios principales.

Bloqueantes:
- Recuperación de contraseña no tiene envío real de correo/SMS, token de restablecimiento ni rutas públicas de reset/verificación.
- Las imágenes se guardan en disco y /uploads se sirve públicamente sin autorización por recurso.
- Android release usa firma debug.
- Docker Engine y PostgreSQL no pudieron verificarse por permisos del entorno.
- Flutter quedó bloqueado por el runner; no hay evidencia de tests/build/render visual.
- /suministros devuelve 410 como endpoint legado.
- Enlaces de términos/privacidad tienen callbacks TODO sin destino.

Conclusión: **lista únicamente para demo local**; no lista para pruebas formales, piloto ni producción.

## 2. Alcance y limitaciones

Se inspeccionaron frontend/lib, frontend/test, backend/src, migraciones, manifests, Docker Compose, pubspec, package.json y configuración de entorno sin leer secretos.

No fue posible:
- Ejecutar Flutter: flutter --version quedó bloqueado y terminó con timeout 124; no se repitió el wrapper.
- Levantar Docker Compose: permiso denegado al Docker Engine.
- Consultar PostgreSQL: psql no está instalado.
- Renderizar Pixel 8, navegador o escritorio.
- Crear usuarios, registros o archivos.
- Verificar migraciones aplicadas, datos, backups o restauración.

## 3. Estado de Git

Comandos:
- git status --short: 35 rutas modificadas y frontend/test/login_wave_clipper_test.dart sin seguimiento.
- git branch --show-current: dev-frontend.
- git log -1 --oneline: cec1f28 widget SectionHeader para una separación uniforme de secciones.
- git diff --check: código 0; advertencias LF/CRLF y acceso a ~/.config/git/ignore.
- git diff --stat: 35 archivos, 953 inserciones y 721 eliminaciones acumuladas.
- git diff --cached --name-only: vacío.

Los cambios son acumulados del usuario (UI/theme, API client, dashboards, auth y tests). No se usó add, commit, push, reset, restore, checkout, clean, stash, rebase ni squash. backend/.env existe pero no se leyó.

## 4. Arquitectura

Frontend:
- Flutter/Dart + Riverpod + GoRouter.
- Capas UI, providers/controllers, repositorios y ApiClient.
- Mocks en tests.
- Cola offline y providers sensibles a la sesión.
- Theme propio con AppColors/AppTheme.

Backend:
- Express 5 + TypeScript + pg/PostgreSQL.
- Servicios por dominio: auth, solicitudes, cargas, cierres, precios, incidencias, evidencias, recorridos/despachos Marimba, vehículos y auditoría.
- Helmet, CORS, rate limiting, JWT, multer/magic bytes, Pino y error handler.
- Migraciones numeradas 0001–0031 y runner transaccional.

## 5. Plataformas y versiones

| Elemento | Evidencia |
|---|---|
| Dart | 3.12.2 stable, obtenido con binario directo. |
| Flutter | No obtenido; wrapper bloqueado. |
| Node/npm | v24.18.0 / 11.16.0. |
| TypeScript | 5.7.3. |
| Docker | 29.6.1; API inaccesible. |
| PostgreSQL | Compose usa postgres:18; versión real no verificada. |
| Plataformas | Android, iOS, Web, Windows, Linux y macOS presentes. |
| Configuración | pubspec.yaml, Dockerfiles, nginx, manifests, Android/iOS runners. |

Dependencias relevantes Flutter: http, Riverpod, GoRouter, secure storage, image_picker, ML Kit, notifications, connectivity, charts, sharing, path provider, archive/csv/intl. Backend: Express, pg, bcrypt, JWT, Zod, multer, Helmet, CORS, rate-limit y Pino.

Variables requeridas, sin valores: DATABASE_URL, DATABASE_SSL, JWT_SECRET, expiraciones JWT/refresh, CORS_ORIGIN, PORT, UPLOADS_DIR, límites de rate-limit, POSTGRES_*, PRESUPUESTO_SEMANAL_TOTAL y PUBLIC_API_BASE_URL.

## 6. Mapa funcional por rol

### Chofer

| Funcionalidad | Flutter | API/BD | Estado |
|---|---|---|---|
| Bienvenida/login/registro/recuperación | /, /login, /registro-chofer, /recuperar-password | /login, /registro-chofer, /recuperar-password | Parcial: recuperación no entrega instrucciones reales. |
| Inicio/perfil/logout | /chofer, /chofer/perfil | sesión, auth, vehículos | Implementado en código; runtime no comprobado. |
| Solicitud vehículo/maquinaria/granel | tipo-operacion y solicitar/:categoria | POST /solicitudes multipart | Contrato y validación presentes; E2E no ejecutado. |
| Historial/estados | mis solicitudes/respuesta | /solicitudes/mias, /folio/:folio | Implementado en contrato. |
| Comprobar carga/evidencias/cierre | comprobar, subir-evidencias, cerrar-dia | /cargas, /evidencias, /cierres-dia | Implementado; cámara/servidor no comprobados. |
| Incidencias | pantallas/dialogs | /incidencias | Implementado en código. |
| Offline | cola_solicitudes_offline y connectivity | reintentos/sincronización | Hay cola/tests; conflictos multi-dispositivo no probados. |

### Supervisor Marimba/Pipa

- Rol, capacidades y guard: implementados en Perfil, capacidades_rol y router.
- Apertura/cierre de recorrido, inventario, saldos y despachos: repositorio y endpoints /recorridos-marimba y /despachos-marimba.
- Conciliación: servicio de recorridos y migraciones 0026–0031.
- Offline: tests específicos presentes, ejecución Flutter bloqueada.
- Propiedad/recorridos ajenos: middleware y servicio presentes, no probado contra BD real.

### Administrativo

Dashboard, autorizaciones, concentrado/reportes, finanzas, vehículos, mantenimiento, Marimba/Pipa, choferes/usuarios, auditoría, perfil y logout existen en tabs y shell administrativo. Hay filtros/paginación en auditoría/recorridos y query schemas; la ejecución responsive real no está comprobada.

### Superadmin

El rol existe en tipos, migración 0011, guards y UI. Crear administrativos está restringido a superadmin; administrar choferes y reset de terceros se comparte con administrativo según reglas de servicio. No hay panel separado: usa el panel administrativo con controles adicionales.

## 7. Rutas y permisos

| Ruta | Sin sesión | Chofer | Supervisor | Admin | Superadmin |
|---|---:|---:|---:|---:|---:|
| /, /login, /registro-chofer, /recuperar-password | Sí | redirige | redirige | redirige | redirige |
| /chofer/** | No | Sí | según capacidad | No | No |
| /chofer/recorrido-marimba | No | No | Sí | No | No |
| /administrativo/** | No | No | No | Sí | Sí |
| /administrativo/chofer | No | No | No | Sí | Sí |
| /chofer/respuesta, comprobar, cerrar-dia | No | Sí | Sí | No | No |

El guard está centralizado en app_router.dart. No existen deep links de restablecimiento por token, verificación OTP ni rutas públicas de reset.

## 8. Controles

La búsqueda no encontró callbacks vacíos obvios en frontend/lib. Hallazgos:
- Términos y privacidad en login_screen.dart tienen recognizers, pero _abrirTerminos/_abrirPrivacidad son TODO vacíos.
- Recuperar contraseña muestra respuesta genérica, sin proveedor ni siguiente paso.
- /suministros siempre devuelve 410; clientes legados fallan explícitamente.
- Los formularios principales tienen estados _cargando y validación.
- Hay Semantics/tooltips en varios iconos, pero no una matriz completa de accesibilidad ni prueba de teclado.
- Doble pulsación/idempotencia no está demostrada para todos los controles de escritura.

## 9. Responsive y visual

Inspección de código:
- AuthScreenShell usa SafeArea, LayoutBuilder, viewInsets y SingleChildScrollView.
- Dashboard cambia composición móvil mediante AppBreakpoints.
- Existen tamaños fijos y diálogos/formularios largos que requieren render real.
- Sidebars, charts y tablas tienen ramas de layout.

No se verificaron por render 360x640, 390x844, 412x915, 430x932, 768x1024, 1024x768, 1280x720, 1366x768, 1440x900 ni 1920x1080. No se puede afirmar ausencia de overflows, clipping, problemas de teclado, orientación o contraste.

## 10. Accesibilidad

Fortalezas: labels de campos, Semantics para contraseñas, tooltips y componentes Material.

Pendientes:
- Orden Tab/Shift+Tab/Enter/Escape/flechas.
- Lectores de pantalla.
- Contraste de todos los badges/estados.
- Labels de todos los icon-only controls.
- Texto 1.5/2.0 y foco con teclado.
- No hay suite dedicada de accesibilidad.

## 11. Estado frontend

Riverpod liga repositorios a sessionProvider.select(id); ApiClient coordina un refresh concurrente y notifica sesión expirada; CatalogoUnidadesController deduplica cargas; existe cola offline.

Riesgos no ejecutados:
- Respuestas tardías después de logout.
- Cancelación y reintento multipart.
- Cambio de sesión durante solicitudes.
- Reinicio con cola pendiente.
- Plugins de cámara, OCR, notificaciones, sharing y secure storage en plataformas reales.

ApiConfig usa API_BASE_URL si existe; por defecto Android no-Web usa http://10.0.2.2:3000 y Web/desktop localhost:3000. Es correcto para desarrollo, no para producción.

## 12. Backend y contratos

Endpoints montados: auth, vehículos, solicitudes, cargas, cierres-dia, precios, incidencias, usuarios, auditoría, evidencias, suministros, despachos-marimba y recorridos-marimba.

La correspondencia repositorio/API es amplia. Riesgos:
- /suministros devuelve 410.
- Recuperación carece de proveedor y reset.
- Multipart con partidas/comprobantes/folios depende de JSON embebido.
- No hay OpenAPI/generación de contrato; compatibilidad se mantiene manualmente.
- No hubo ejecución contra backend/BD levantados en esta auditoría.

## 13. Base de datos y migraciones

Hay 31 migraciones, runner con schema_migrations, transacciones, índices, FK, checks y unicidad para recorridos/movimientos.

No se pudieron consultar datos. Quedan desconocidos: migraciones aplicadas, huérfanos, duplicados, valores negativos, integridad de folios/evidencias, timezone, backups, restauración y privilegios runtime.

schema.sql inicial solo declara roles chofer/administrativo; 0011 y 0016 agregan superadmin/supervisor. Usar schema.sql sin runner deja el despliegue incompleto.

## 14. Seguridad

Fortalezas: bcrypt 12, JWT con token_version, refresh rotativo/hash, requireAuth/requireRole, Zod, rate limits, Helmet, CORS configurable, magic bytes y límite de 10 MB.

Hallazgos:
- **SEC-01 Alto:** express.static(UPLOADS_DIR) publica fotos de tickets/tableros/evidencias sin autorización por recurso. Usar storage privado/endpoints autorizados/URLs firmadas.
- **SEC-02 Alto:** recuperación no tiene token, expiración, consumo único, proveedor ni reset público.
- **SEC-03 Alto producción:** DATABASE_SSL acepta rejectUnauthorized:false.
- **SEC-04 Alto producción:** release Android usa signingConfig debug.
- **SEC-05 Medio:** defaults HTTP/cleartext solo sirven para desarrollo.
- **SEC-06 Medio:** CORS permite cualquier origin fuera de producción si no se define CORS_ORIGIN.
- **SEC-07 Medio:** seed.ts contiene credenciales de demo; nunca usar en producción.
- **SEC-08 Medio:** rate limit en memoria no coordina réplicas.
- **SEC-09 Medio:** npm audit no pudo consultar registry por certificado.

No se imprimieron secretos, tokens, cookies ni valores de .env.

## 15. Offline, concurrencia e integridad

Hay cola offline, refresh coordinado y constraints de unicidad. No hay evidencia ejecutada de dos dispositivos, pérdida durante multipart, cierre de app, reordenamiento de cola, inventario concurrente o conflictos.

Las escrituras críticas deberían tener idempotency key, transacción/constraint y pruebas de reintento seguro.

## 16. Cámara, archivos y permisos

Android declara cámara/notificaciones/boot; iOS tiene cámara/fototeca; plugins están declarados. Backend valida MIME, magic bytes y tamaño.

Pendientes: permisos denegados/permanentes, HEIC, orientación, compresión, cleanup, interrupción, Web/Windows/macOS y builds por plataforma.

## 17. Calidad

Fortalezas: capas claras, dispose frecuente, const, servicios separados y tests por dominio.

Deuda:
- Widgets/tabs grandes.
- Comentarios obsoletos sobre ondas/gradientes.
- TODO-BACKEND/TODO-SPEC pendientes.
- schema.sql puede divergir de migraciones.
- package.json no tiene script lint/typecheck separado.
- No hay contrato OpenAPI ni CI visible.

## 18. Cobertura real

Inventario textual: 45 archivos Dart de test y aproximadamente 196 declaraciones.

| Área | Resultado |
|---|---|
| Backend unit/integration/roles | 19 archivos pasaron; 2 suites omitidas; 109 passed/11 skipped. |
| Backend build | Aprobado. |
| Flutter analyzer | Dart directo aprobado; Flutter wrapper bloqueado. |
| Flutter widgets/integration | No ejecutado. |
| Router/auth/offline | Tests presentes, ejecución bloqueada. |
| Responsive/accessibility | Tests parciales, sin render real. |
| E2E Android/Web | No ejecutado. |
| Security/dependencies | npm audit bloqueado por certificado. |

## 19. Comandos y resultados

| Directorio | Comando | Resultado |
|---|---|---|
| raíz | git status/branch/log/diff-check/diff-stat/cached | Estado documentado; staging vacío. |
| frontend | dart analyze lib test (SDK absoluto) | 0, sin issues. |
| frontend | dart format --output=none --set-exit-if-changed lib test | 1; 31 archivos requieren formato, no se escribieron cambios. |
| frontend | flutter --version | timeout 124 a 30 s. |
| backend | npm run build | 0. |
| backend | npm test | 0; 109 passed, 11 skipped. |
| backend | npm audit --omit=dev --audit-level=high | 1 por certificado de registry. |
| backend | docker compose ps | 1 por permiso Docker Engine. |
| raíz | psql --version | 1; no instalado. |

No se ejecutaron flutter analyze/test/build apk/build web después del bloqueo del runner.

## 20. Checklist manual Pixel 8

1. Levantar BD/backend de prueba desde backend/ sin usar datos productivos.
2. Aplicar migraciones en la BD de prueba y verificar /health.
3. Arrancar Flutter con API_BASE_URL=http://10.0.2.2:3000.
4. Probar registro/login/logout por cada rol.
5. Probar recuperación y documentar la ausencia de correo/reset.
6. Probar solicitudes, validaciones y doble pulsación.
7. Desconectar red, crear operación offline, cerrar/reabrir y reconectar.
8. Probar comprobación, cámara, galería, permisos denegados y evidencias.
9. Probar cierre de jornada y reintento.
10. Probar supervisor: recorrido, inventario, despacho y conciliación.
11. Probar administrativo/superadmin: autorización, vehículos, usuarios, auditoría.
12. Repetir con teclado, rotación, tema oscuro, texto 1.5/2.0 y Atrás.
13. Capturar logs/respuestas redactados y cualquier overflow.

## 21. Preparación por ambiente

Demo local: suficiente código/mocks, condicionado a poder iniciar herramientas.

Pruebas internas: falta ejecutar Flutter, BD real, E2E, permisos y red/offline.

Piloto: faltan recuperación real, storage privado, firma release, HTTPS/TLS, backups, monitoreo, conflictos multi-dispositivo y procedimientos.

Producción: faltan además CI/CD, secretos gestionados, dominio/CORS estricto, release firmado, privacidad/términos operativos, rollback, retención y revisión de dependencias.

## 22. Funcionalidades completas según contrato

Login/refresh/logout/revocación; registro; guards/roles; vehículos/mantenimiento; solicitudes/autorizaciones/cancelación; cargas/cierres/incidencias/evidencias; recorridos/despachos Marimba; auditoría. “Completa” significa contrato y pruebas de backend presentes, no E2E visual aprobado.

## 23. Parciales

Recuperación; offline/concurrencia; notificaciones; responsive/accesibilidad; superadmin (integrado, sin panel propio); exportación/reportes y permisos reales de archivos.

## 24. Rotas o no disponibles

- /suministros devuelve 410 por diseño legado.
- Términos y privacidad no tienen navegación.
- Reset público/OTP/verificación no existen.
- Las imágenes quedan públicas por URL.

## 25. Tabla de hallazgos

| ID | Sev. | Área/rol/plataforma | Archivo | Evidencia/impacto | Corrección/prueba | Est. | Bloquea |
|---|---|---|---|---|---|---|---|
| AUD-001 | Crítico | Seguridad/todos | backend/src/index.ts | /uploads público; posible exposición de fotos. | Storage privado + autorización + test 401/403. | L | Piloto/Prod |
| AUD-002 | Alto | Auth/todos | authService.ts | Recuperación no envía correo ni crea token. | Token hash/expiración/reset + E2E. | XL | Piloto/Prod |
| AUD-003 | Alto | Android | app/build.gradle.kts | Release firma con debug. | Keystore/CI + build firmado. | M | Prod |
| AUD-004 | Alto | BD/TLS | db/pool.ts | rejectUnauthorized:false. | CA válida + test TLS. | M | Prod |
| AUD-005 | Alto | BD/operación | Docker Compose | Estado BD/migraciones no verificable. | Entorno de prueba + queries read-only + restore. | M | Piloto |
| AUD-006 | Medio | UX | login_screen.dart | Links legales callbacks TODO. | URLs/pantallas reales + test tap. | S | Piloto |
| AUD-007 | Medio | Legacy/API | suministros.routes.ts | POST siempre 410. | Retirar consumidor o completar migración + contrato. | S/M | Si se usa |
| AUD-008 | Medio | QA | Flutter runner | Tests/builds bloqueados. | Reparar SDK/CI + suite completa. | M | Pruebas |
| AUD-009 | Medio | Dependencias | package.json | npm audit bloqueado por certificado. | Audit reproducible en CI. | S | Piloto |
| AUD-010 | Medio | Offline | cola/repositorios | Sin prueba de dos dispositivos/reintentos. | Idempotencia + integration tests. | L | Piloto |
| AUD-011 | Medio | Plugins | Android/iOS/Web/desktop | Permisos/builds no ejecutados. | Matriz de plataforma + manual Pixel 8. | M | Piloto |
| AUD-012 | Bajo | Web | web/index.html | Metadata genérica de plantilla. | Metadata/manifest/política. | XS | Prod |
| AUD-013 | Bajo | Esquema | schema.sql/migrations | Roles requieren migraciones posteriores. | Drift check/recreate+migrate. | M | Piloto |
| AUD-014 | Bajo | Formato | frontend/lib,test | 31 archivos reportados no formateados. | Formateo separado y revisión de diff. | S | Pruebas |

## 26. Priorización

### P0 — bloqueantes críticos
1. Proteger evidencias (AUD-001).
2. Recuperación/restablecimiento seguro (AUD-002).
3. Verificar migraciones, BD, backup y restore (AUD-005/AUD-013).
4. Firma Android y secretos release (AUD-003).

### P1 — piloto
1. Desbloquear Flutter y ejecutar analyzer/test/build (AUD-008/AUD-011/AUD-014).
2. E2E por rol y propiedad.
3. Offline, doble envío, reinicio y dos dispositivos (AUD-010).
4. Retirar/completar /suministros (AUD-007).
5. HTTPS, CORS estricto, TLS validado y rate-limit distribuido.

### P2 — calidad
Accesibilidad/foco, links legales, mensajes, responsive visual, lint y contrato API automatizado.

### P3 — futuro
Optimización, goldens, observabilidad avanzada, metadata Web y refactors de widgets grandes.

## 27. Puertas de calidad

| Puerta | Estado | Evidencia |
|---|---|---|
| A Compilación | Pendiente | Backend sí; Flutter builds/analyze no ejecutados. |
| B Pruebas | Pendiente | Backend sí; Flutter bloqueado; E2E no ejecutado. |
| C Funcionalidad | Pendiente | Recuperación y links incompletos. |
| D Datos | Pendiente | Migraciones presentes; BD/backups no verificados. |
| E Seguridad | Pendiente | JWT bueno; uploads públicos, TLS/release pendientes. |
| F Experiencia | Pendiente | Sin render real. |
| G Operación | Pendiente | Docker/CI/monitoring/rollback no verificados. |

Preparación estimada: **35%**. Fórmula: promedio simple de A=1/4, B=1/4, C=2/4, D=1/4, E=2/4, F=2/4 y G=1/4, redondeado y limitado por los bloqueantes. No es porcentaje de código.

## 28. Plan de trabajo por bloques

| Bloque | Objetivo | Archivos/áreas | Dependencias | Salida |
|---|---|---|---|---|
| P0.1 | Privacidad de evidencias | upload/index, storage, rutas | Decisión de storage | 401/403/200 y URLs privadas. |
| P0.2 | Recuperación real | auth routes/service, migración, Flutter auth | Proveedor correo/SMS | Token expirado/único y UI completa. |
| P0.3 | BD reproducible | migrations/schema/Compose | Docker/DB de prueba | migrate + restore verificados. |
| P0.4 | Release seguro | Gradle, secrets, CI | Keystore | APK firmado verificable. |
| P1.1 | QA Flutter | tests/build/CI | SDK funcional | analyzer/test/apk/web código 0. |
| P1.2 | Campo/offline | cola, API, servicios | BD multi-cliente | reintentos/idempotencia/conflictos. |
| P1.3 | E2E roles | router, endpoints, fixtures | entorno de prueba | matriz de permisos aprobada. |
| P2 | UX/a11y | widgets/theme/tests | ejecución Flutter | sin overflow, foco/labels/contraste. |

No se implementa este plan en esta fase.

## 29. Decisión final

**Lista únicamente para demo local.**

No lista para pruebas formales, piloto controlado ni producción. Próximo bloque recomendado: AUD-001 (storage privado) y AUD-002 (recuperación real), mientras se habilita un runner Flutter/Docker reproducible.

## 30. Confirmación de restricciones

- No se modificó código productivo.
- No se alteraron datos.
- No se ejecutaron migraciones ni seeds.
- No se creó staging.
- No hubo commit ni push.
- No se ejecutó git add.
- Staging permanece vacío.
- Código 0: Dart Analyzer, npm run build, npm test, git diff --check.
- Pendiente/bloqueado: Flutter analyze/test/build, Docker/BD, npm audit, validación visual y manual Pixel 8.
