# Bloque 0 — Validación del entorno local

Fecha de ejecución: 2026-08-20  
Rama esperada: `dev-frontend`  
Alcance: preparación y diagnóstico únicamente. No se implementó el flujo de solicitudes.

## 1. Resumen ejecutivo

El backend local está respondiendo correctamente: `GET /health` terminó con HTTP 200 y reportó `{"status":"ok","db":"ok"}`. `npm run build` y la suite backend terminaron correctamente.

El staging está vacío y no se modificaron datos ni se ejecutaron migraciones. Docker Engine no es accesible desde este wrapper por permisos del named pipe, aunque el servicio HTTP ya estaba disponible. ADB tampoco pudo iniciar porque el entorno no puede crear `\.android`; el AVD `Pixel_8` y los ejecutables sí existen.

Flutter/Dart presenta bloqueo del SDK: el wrapper Flutter no puede abrir `C:\Users\William\develop\flutter\bin\cache\lockfile`; la comprobación de formato sin escritura identificó 31 archivos heredados sin formato. Por ese bloqueo no se pudieron aprobar análisis Flutter, pruebas Flutter, builds ni ejecución en Pixel 8.

**Decisión: Bloque 0 pendiente.** El backend y la salud HTTP están aprobados; la cadena Flutter/Android/Docker/PostgreSQL queda pendiente de una ejecución manual con permisos adecuados.

## 2. Estado Git

| Elemento | Resultado |
|---|---|
| Rama | `dev-frontend` |
| Commit base | `cec1f28 widget SectionHeader para una separación uniforme de secciones` |
| Staging | Vacío (`git diff --cached --name-only` sin archivos) |
| Cambios acumulados | Varias modificaciones Flutter y una modificación previa en `backend/src/middleware/errorHandler.ts` |
| Archivos nuevos | `AUDITORIA_INTEGRAL_ESTADO_PROYECTO.md`, `frontend/test/login_wave_clipper_test.dart`, este reporte |
| `git diff --check` | Código 0; solo advertencias LF/CRLF y acceso denegado a `C:\Users\William\.config\git\ignore` |

No se ejecutaron `git add`, commit, push ni comandos destructivos.

## 3. Herramientas y versiones

| Comando | Resultado |
|---|---|
| `where.exe flutter` | Falló: no está en `PATH`; SDK confirmado en `C:\Users\William\develop\flutter` |
| `where.exe dart` | Falló: no está en `PATH`; ejecutable directo confirmado |
| `where.exe adb` | Falló: no está en `PATH`; ejecutable confirmado en Android SDK |
| `where.exe node` | 0 — `C:\Program Files\nodejs\node.exe` |
| `where.exe npm` | 0 — `npm` y `npm.cmd` |
| `where.exe docker` | 0 — Docker CLI instalado |
| Dart directo `--version` | 0 — Dart SDK 3.12.2 stable |
| Flutter `--version` directo | Bloqueado por timeout (30 s), sin código 0 |
| `flutter doctor -v` | No repetido tras el bloqueo del SDK |
| Node | v24.18.0 |
| npm | 11.16.0 |
| Docker | 29.6.1 |
| Docker Compose | v5.2.0 |

El bloqueo de Flutter deja procesos Dart activos y un `cache\lockfile` de longitud 0; no se eliminó ni se alteró ese lockfile.

## 4. Android y Pixel 8

| Comprobación | Resultado |
|---|---|
| `platform-tools\adb.exe` existe | Sí |
| `emulator\emulator.exe` existe | Sí |
| AVD detectado | `Pixel_8.avd` |
| `adb devices -l` | Bloqueado: `adb_utils.cpp:315 Cannot mkdir '\\.android': Permission denied` |
| Estado `emulator-5554` | No comprobable desde este wrapper |
| `flutter devices` | No ejecutado porque Flutter quedó bloqueado |

Comando manual recomendado, en una PowerShell con perfil Android escribible:

```powershell
$adb = "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe"
& $adb devices -l
& $adb -s emulator-5554 get-state
& $adb -s emulator-5554 shell getprop sys.boot_completed
```

No se reinició ADB ni se modificó el AVD.

## 5. Docker y servicios

Directorio utilizado: `backend/`.

| Comando | Resultado |
|---|---|
| `docker info` | Falló: permiso denegado al named pipe `npipe:////./pipe/docker_engine` |
| `docker compose config --services` | 0 — servicios `db` y `backend` |
| `docker compose ps` | Falló por el mismo permiso del Docker Engine |

Docker CLI funciona, pero el Engine no es accesible desde el proceso actual. No se ejecutó `up`, no se recrearon contenedores y no se tocaron volúmenes.

## 6. Salud del backend

Comando desde `backend/`:

```text
curl.exe -i --max-time 10 http://localhost:3000/health
```

Resultado: código 0, HTTP 200, cuerpo no sensible:

```json
{"status":"ok","db":"ok"}
```

La respuesta demuestra que el proceso HTTP está accesible y que su comprobación de base de datos fue satisfactoria en ese momento. No se imprimieron variables de entorno ni credenciales.

## 7. PostgreSQL y migraciones

`psql` no está instalado en Windows y Docker no pudo abrirse, por lo que no fue posible ejecutar consultas de solo lectura contra la instancia activa.

Inventario estático de migraciones disponibles: 31 archivos, desde `0001_baseline.sql` hasta `0031_marimba_partidas_inventario.sql`. El runner no pudo comprobar `schema_migrations`, última migración aplicada, constraints, índices ni conteos de tablas.

Estado: **no comprobado**, no una afirmación de migraciones pendientes. No se ejecutaron migraciones, seeds ni escrituras.

Comprobación manual pendiente (solo lectura, desde un contenedor con el cliente disponible):

```powershell
docker compose exec db psql -U <usuario-runtime> -d <base> -c "SELECT version();"
docker compose exec db psql -U <usuario-runtime> -d <base> -c "SELECT * FROM schema_migrations ORDER BY version DESC;"
```

Los placeholders deben resolverse localmente sin imprimir secretos.

## 8. Backend: build y pruebas

Directorio: `backend/`.

| Comando | Código | Resultado |
|---|---:|---|
| `npm run build` | 0 | TypeScript compiló correctamente |
| `npm test` | 0 | 19 archivos aprobados, 2 omitidos; 109 pruebas aprobadas, 11 omitidas |
| `npm run lint` | No ejecutado | No existe script declarado |
| `npm run typecheck` | No ejecutado | No existe script declarado |
| `npm audit --omit=dev --audit-level=high` | 1 | Bloqueado por certificado TLS del registry; no es una confirmación de vulnerabilidad |

## 9. Frontend Flutter

Directorio: `frontend/`.

| Comando | Resultado |
|---|---|
| `dart format --output=none --set-exit-if-changed lib test` | Timeout del wrapper |
| Dart directo equivalente | Código 1: identificó 31 archivos heredados que requieren formato; no se escribieron archivos |
| `flutter analyze` | Bloqueado por `cache\lockfile` |
| `flutter test --reporter expanded` | No ejecutado después del bloqueo de Flutter |
| `flutter build apk --debug` | No ejecutado |
| `flutter build web` | No ejecutado |

No se hizo formato masivo ni se modificaron los 31 archivos heredados detectados.

## 10. Instalación y arranque Android

No se ejecutó `flutter install` ni `flutter run`, porque no hubo build APK aprobado y ADB no pudo iniciar. No hay evidencia nueva de instalación, activity resoluble o ausencia de crash en esta ejecución.

## 11. Conectividad

| Tramo | Resultado |
|---|---|
| Windows → backend `localhost:3000` | Comprobado, HTTP 200 |
| Backend → PostgreSQL | Reportado por `/health` como `db: ok`; no se hizo consulta independiente |
| Android Emulator → backend `10.0.2.2:3000` | Pendiente por ADB bloqueado |
| Configuración Flutter Android | Pendiente de inspección/ejecución con Flutter operativo |

No se envió ninguna solicitud de combustible.

## 12. Validación visual

No se obtuvieron capturas nuevas. Bienvenida, login, Pixel 8, teclado, tema oscuro y shell autenticado quedan pendientes de comprobación manual. No se declara ausencia de overflows o crash Android.

## 13. Advertencias no bloqueantes

- Advertencias LF/CRLF de Git.
- `C:\Users\William\.config\git\ignore` y `C:\Users\William\.docker\config.json` no son legibles desde este contexto.
- Docker CLI está instalado, pero el Engine requiere un terminal con permisos/conexión al named pipe.
- `npm audit` requiere corregir la confianza TLS del entorno o ejecutar desde una PowerShell configurada, sin usar `audit fix`.

## 14. Bloqueos reales

1. Lockfile/permisos del SDK Flutter: impide `flutter doctor`, analyze, tests y builds.
2. ADB no puede crear `\.android`: impide verificar `emulator-5554`, instalar APK y probar conectividad Android.
3. Docker Engine named pipe denegado: impide `docker ps` y consultas PostgreSQL directas.
4. Formato global heredado: 31 archivos fuera del bloque actual requieren formato; no se alteraron.

## 15. Secuencia manual reproducible pendiente

1. Abrir Docker Desktop y una PowerShell con acceso al Docker named pipe.
2. Iniciar el AVD `Pixel_8` y comprobar `adb devices -l` como `device`.
3. Desde `backend/`, ejecutar `docker compose ps` y confirmar `db`/`backend` saludables.
4. Verificar `curl.exe -i http://localhost:3000/health`.
5. Desde `frontend/`, ejecutar Flutter con el SDK desbloqueado:

```powershell
flutter analyze
flutter test --reporter expanded
flutter build apk --debug
flutter build web
flutter install -d emulator-5554
```

6. Comprobar desde el emulador `http://10.0.2.2:3000/health` sin enviar solicitudes de combustible.
7. Capturar logs del paquete y verificar que no exista crash inmediato.

## 16. Decisión final

**Bloque 0 pendiente.**

Validaciones con código 0: Git diff check, `where.exe` de Node/npm/Docker, Dart versión, Docker Compose config de servicios, backend health, `npm run build`, `npm test`, existencia de SDK/AVD.  
Validaciones pendientes o bloqueadas: Flutter doctor/analyze/tests/builds, ADB/Pixel 8, Docker Engine/psql, migraciones aplicadas, instalación Android, conectividad `10.0.2.2` y validación visual.

No es seguro avanzar al Bloque 1 desde este contexto porque faltan las puertas Flutter, Android y verificación directa de PostgreSQL. El único punto del Bloque 1 que se evitó deliberadamente fue enviar solicitudes de combustible.

## Cierre obligatorio

- No se modificó código productivo.
- Solo se creó/actualizó este reporte.
- No se alteraron datos.
- No se ejecutaron migraciones ni seeds.
- No hubo staging, commit ni push.
- Los comandos aprobados y bloqueados están enumerados con su código/resultado arriba.
