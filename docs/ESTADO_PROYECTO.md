# Estado actual del proyecto

## Preparación de preproducción — 2 de septiembre de 2026

La fase de preparación detectó y corrigió requisitos que no cubrían los builds
debug: la imagen Backend ahora incluye las migraciones SQL y comandos runtime,
ejecuta como usuario no-root y configura límites/timeouts del pool; Android
release declara red, exige HTTPS y contiene reglas R8 acotadas para los módulos
opcionales de ML Kit; el Web Docker usa Flutter 3.44.4 oficial verificado por
SHA-256, lockfile estricto y Nginx con caché/headers operativos.

Se añadió `docs/DEPLOYMENT.md` con variables, migración, persistencia,
SMTP, firma, HTTPS, backup/restore, smoke y rollback. En validación local:
Backend compiló, 212 tests pasaron y 21 quedaron omitidos; PostgreSQL 18
efímero aplicó 34 migraciones, la segunda ejecución quedó sin pendientes y la
integración terminó 233/233; Flutter Analyze quedó sin issues y Flutter Test
terminó 416/416; Web release, las imágenes Docker y el AAB release sin firma
compilaron. La firma Android física, dominio, servidor, SMTP y secretos reales
continúan siendo dependencias externas antes de desplegar.

Fecha de consolidación: 31 de agosto de 2026.

Este documento describe el estado local consolidado de la rama `dev-frontend`.
Las fases acumuladas se separaron en commits funcionales y verificables, sin
publicarlos en un remoto.

## Arquitectura actual

### Frontend

- Aplicación Flutter multiplataforma organizada en core, data, models, router,
  screens, services, theme y widgets.
- Riverpod gestiona estado, sesión, repositorios y coordinadores; GoRouter
  concentra rutas, guards por sesión/rol y transiciones.
- Los repositorios aíslan HTTP y contratos de la interfaz.
- La URL de API se recibe mediante la definición API_BASE_URL.
- Los componentes compartidos cubren autenticación, encabezados, diálogos,
  formularios y navegación responsive.

### Backend

- API Express 5 y TypeScript con Zod, JWT, bcrypt, PostgreSQL, Pino y pruebas
  Vitest/Supertest.
- La estructura separa routes, services, middleware, db, storage, types y utils.
- Los servicios contienen reglas de negocio y transacciones; el pool centraliza
  la conexión PostgreSQL y su configuración TLS.
- Las evidencias del backend se guardan bajo el directorio configurable de
  uploads, persistido mediante volumen cuando se usa Docker.

### PostgreSQL

- PostgreSQL es la fuente de verdad del backend.
- Existen 34 migraciones incrementales, de 0001_baseline.sql a
  0034_password_reset_tokens.sql.
- El runner aplica cada migración dentro de una transacción y registra las ya
  ejecutadas.
- Las migraciones existentes no se editan retroactivamente; los cambios de
  esquema se agregan mediante una migración nueva.

### Docker

- El docker-compose.yml raíz levanta PostgreSQL, backend y frontend.
- backend/docker-compose.yml conserva el flujo local de PostgreSQL y backend.
- PostgreSQL y backend publican puertos solo sobre localhost en las
  configuraciones actuales.
- El backend usa una imagen multi-stage Node 22 y un volumen para uploads.
- El frontend recibe la URL pública del backend como argumento de build.

### CI

- frontend-ci.yml ejecuta instalación, análisis, tests Flutter y build Web.
- backend-ci.yml ejecuta npm ci, build TypeScript, tests unitarios, auditoría y
  una tarea de integración con PostgreSQL 18.
- La integración aplica las migraciones dos veces para verificar que no queden
  pendientes y habilita Marimba, idempotencia y recuperación de contraseña.
- Ambos workflows forman parte del historial local de la rama.

### Almacenamiento offline

- AlmacenamientoOffline ofrece importación, lectura, verificación, existencia,
  eliminación y enumeración.
- Web selecciona AlmacenamientoOfflineWeb, implementado con IndexedDB mediante
  package:web y dart:js_interop.
- Las plataformas Dart IO compatibles seleccionan
  AlmacenamientoOfflineFilesystem, basado en dart:io y path_provider.
- Los imports condicionales evitan cargar filesystem al compilar Web.
- Fotografías y evidencias se copian como bytes a almacenamiento durable antes
  de persistir la operación. La metadata conserva tamaño, SHA-256, MIME, campo
  multipart y clave de almacenamiento.
- Las rutas filesystem se validan y permanecen bajo
  offline/<usuario>/<idLocalOperacion>/.

## Funcionalidades implementadas

- Autenticación, refresh de sesión, registro de chofer, recuperación y
  restablecimiento de contraseña.
- Roles y navegación para chofer, administración, supervisión y superadmin
  según los contratos vigentes.
- Solicitudes y comprobación de carga, cierre de día, incidencias y evidencias.
- Catálogo de unidades, mantenimiento, presupuestos, precios, auditoría y
  paneles administrativos.
- Operación Marimba: recorridos, partidas, despachos, conciliación, historial e
  idempotencia.
- Cola offline por usuario con persistencia, reintentos, clasificación de
  errores, centro de sincronización y protección ante respuestas tardías.
- Persistencia durable de fotografías/evidencias, verificación de integridad y
  limpieza de archivos huérfanos.
- Interfaz responsive para móvil, tablet, escritorio y Web.

## Últimas fases completadas

### Evidencias offline persist-first

Las fotografías se importan a almacenamiento durable antes de guardar la
operación offline. Las colas conservan metadata y hashes, no dependen solo de
rutas temporales del picker y reconstruyen el multipart al sincronizar.

### Almacenamiento Web mediante IndexedDB

La implementación Web usa las APIs actuales de package:web. Soporta
apertura/creación, escritura y recuperación de bytes, enumeración, eliminación,
transacciones y errores.

### Selección de storage según plataforma

La factory usa imports condicionales: Web recibe IndexedDB y las plataformas IO
compatibles reciben filesystem. Web no instancia la implementación filesystem.

### Recuperación de contraseña con PostgreSQL real

La invalidación de tokens anteriores y la inserción del nuevo token usan una
conexión y transacción explícita: BEGIN, operaciones parametrizadas, COMMIT,
ROLLBACK ante error y liberación en finally. La migración 0034 agrega la
persistencia correspondiente.

### Limpieza de archivos offline huérfanos

La enumeración devuelve idLocalOperacion y storageKey. La limpieza elimina el
archivo exacto dentro del usuario y operación, protege rutas, conserva archivos
referenciados y solo incrementa el contador ante una eliminación confirmada.

### Header y logo responsive de autenticación

El header compartido usa logo_indi_mark_header.png, asset existente con menos
margen transparente. El tamaño se calcula con el ancho disponible real,
mantiene BoxFit.contain y reduce la altura azul. Login, bienvenida, registro,
recuperación y restablecimiento comparten el componente.

## Validaciones actuales

Resultados reproducidos localmente durante las fases de corrección y cierre:

| Validación | Resultado |
|---|---|
| Backend npm run build | Exitoso |
| Backend npm test | 206 passed, 21 skipped, 0 failed; 26 archivos passed y 4 skipped |
| PostgreSQL real npm run test:integration | 227 passed, 0 skipped, 0 failed; 30 archivos passed |
| Integración aislada de password reset | 2 passed, 0 failed |
| flutter analyze | No issues found: 0 errors, 0 warnings, 0 infos |
| Suite Flutter VM completa | 414 passed, 0 failed |
| Tests afectados del header de autenticación | 23 passed, 0 failed |
| flutter build web --no-pub --no-tree-shake-icons | Exitoso; generó build/web |
| flutter build apk --debug --no-pub | Exitoso; generó app-debug.apk |
| git diff --check | Exit code 0; solo avisos de futura conversión LF a CRLF |

Las suites y builds anteriores se repitieron durante la consolidación antes de
crear los commits correspondientes.

## Problemas conocidos

- offline_almacenamiento_web_test.dart con platform chrome se detiene después de
  lanzar Chrome y antes del primer caso. El runner sirve HTTP 200, abre DevTools
  y establece conexiones, pero queda en Running test suite; no alcanza
  IndexedDB. El build Web JavaScript sí compila.
- flutter_secure_storage_web 1.2.1 usa dart:html, dart:js_util y package:js, por
  lo que el dry-run de Wasm informa incompatibilidades.
- flutter pub get informa 42 paquetes con versiones posteriores incompatibles
  con las restricciones actuales. No se hizo una actualización masiva.
- En este entorno, flutter run con web-server produjo un crash interno de DWDS
  en loadDwdsDirectory; el artefacto Web se sirvió y revisó por separado.
- Git emite avisos LF a CRLF en Windows. No son errores de diff --check.
- No existe AGENTS.md en el repositorio.
- La sintaxis YAML se revisó manualmente: el entorno no dispone de un parser
  YAML independiente instalado y no se agregaron dependencias solo para ello.

## Decisiones técnicas vigentes

- Web usa IndexedDB para persistencia durable offline.
- Las plataformas compatibles con Dart IO usan filesystem.
- Fotografías y evidencias offline se almacenan como bytes durables con metadata
  e integridad SHA-256.
- La recuperación de contraseña usa transacciones PostgreSQL y consultas
  parametrizadas.
- Las migraciones aplicadas no se modifican retroactivamente.
- Wasm no es un requisito actual; el objetivo Web vigente es JavaScript.
- No se usa filesystem como fallback Web.
- La limpieza offline queda limitada a usuario, operación y storage key
  validados.

## Estado Git

- Rama observada: `dev-frontend`.
- Rama local de salvaguarda: `backup/pre-consolidacion-indi-20260831`.
- Se crearon 14 commits funcionales antes de este documento, desde
  `3c652b3 chore(git): proteger secretos y artefactos locales` hasta
  `48dd32c ci: validar backend, PostgreSQL y frontend`.
- La migración 0034, password reset, TLS, offline, IndexedDB, sincronización,
  UI, navegación y CI ya forman parte del historial local.
- Al finalizar este documento no deben quedar cambios productivos pendientes;
  el estado limpio se confirma después de crear el commit documental.
- No se detectaron secretos versionados; `backend/.env` permanece ignorado y
  las credenciales visibles en CI son exclusivas de una base efímera de pruebas.

## Próximas tareas recomendadas

### P1 — Calidad

- Ejecutar el test IndexedDB en Chrome en CI o en otra instalación limpia y
  capturar logs del handshake. Mantener separado el diagnóstico ambiental de la
  lógica IndexedDB.
- Confirmar la ejecución real de los workflows nuevos cuando el equipo autorice
  commits y push.

### P2 — Deuda técnica

- Planificar actualizaciones por grupos pequeños, con atención a
  flutter_secure_storage, Riverpod y navegación. No actualizar masivamente.
- Definir una política consistente de finales de línea para Windows y CI.
- Evaluar la creación futura de AGENTS.md en una fase expresamente autorizada.

### P3 — Mejoras futuras

- Reevaluar Wasm solo si se convierte en requisito de producto. Mientras el
  objetivo sea JavaScript, no cambiar arquitectura para silenciar el dry-run.
- Ampliar la matriz visual automatizada si se incorpora un runner estable.
