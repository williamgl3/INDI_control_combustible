# Despliegue de INDI Control de Combustible

Guía para preproducción y producción. Todos los valores son marcadores; nunca
se deben guardar credenciales reales en Git.

## Arquitectura y requisitos

- Flutter Web se compila a JavaScript estático y se sirve con Nginx.
- Express sobre Node 22 expone la API y `/health`.
- PostgreSQL 18 usa servicio administrado o volumen persistente.
- Las evidencias privadas viven en `UPLOADS_DIR` y solo salen por el endpoint
  autenticado `GET /archivos/:id`.
- Un reverse proxy público termina HTTPS; los puertos del Compose permanecen
  enlazados a `127.0.0.1`.

Servidor recomendado como base: Linux mantenido, Docker/Compose actuales,
DNS y puertos 80/443, reloj sincronizado, 2 CPU y 4 GiB RAM como mínimo a
confirmar con carga real, y espacio para datos, evidencias y dos backups.
Preproducción debe usar dominio, DB, SMTP, volúmenes y cuentas separados.

## Variables por ambiente

Crear `.env` raíz desde `.env.example` y `backend/.env` desde
`backend/.env.example`, con permisos `0600`.

| Variable | Obligatoria | Secreta | Consumidor |
|---|---:|---:|---|
| `PUBLIC_API_BASE_URL` | sí | no | build Flutter |
| `NODE_ENV=production`, `PORT` | sí | no | backend |
| `DATABASE_URL` | sí | sí | backend/migrador |
| `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB` | con Compose | contraseña sí | PostgreSQL |
| `DATABASE_SSL` | según hosting | no | backend |
| `DATABASE_CA_CERT` o `DATABASE_CA_CERT_PATH` | con TLS | no; CA pública | backend |
| `DATABASE_POOL_MAX` | sí | no | pool PostgreSQL |
| `DATABASE_CONNECTION_TIMEOUT_MS`, `DATABASE_IDLE_TIMEOUT_MS` | sí | no | pool PostgreSQL |
| `JWT_SECRET` | sí | sí | autenticación |
| `ACCESS_TOKEN_EXPIRES_IN`, `REFRESH_TOKEN_EXPIRES_IN_DAYS` | sí | no | autenticación |
| `CORS_ORIGIN` | sí | no | backend |
| `UPLOADS_DIR` | sí | no | evidencias |
| `PASSWORD_RESET_EXPIRES_MINUTES`, `PASSWORD_RESET_PUBLIC_URL` | sí | no | reset |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_SECURE`, `SMTP_FROM` | sí | no | correo |
| `SMTP_USER`, `SMTP_PASSWORD` | sí | sí | correo |
| `AUTH_RATE_LIMIT_*`, `LOG_LEVEL` | sí | no | backend |
| `SUPERADMIN_*` | solo bootstrap | contraseña sí | alta inicial |

Marimba no requiere variables externas: utiliza la misma API y PostgreSQL.

## PostgreSQL y migraciones

Crear una base exclusiva y separar, si el proveedor lo permite, el rol
propietario/migrador con DDL del usuario runtime con privilegios mínimos.
Configurar la CA del proveedor. En producción TLS nunca usa
`rejectUnauthorized=false`.

La imagen contiene el runner compilado y los SQL `0001`–`0034`:

```bash
docker compose run --rm backend npm run migrate:prod
docker compose run --rm backend npm run migrate:prod
docker compose exec db psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -c "SELECT count(*) FROM schema_migrations;"
```

Se esperan 34 filas y cero pendientes en la segunda ejecución. Cada migración
corre en una transacción; ante fallo se detiene sin registrarla.

## Evidencias y persistencia

Compose monta `indi_uploads:/app/uploads` y
`indi_pgdata:/var/lib/postgresql`. Sobreviven a restart y `down/up`;
`docker compose down -v` está prohibido en operación normal. Si cambia
`UPLOADS_DIR`, el mount debe coincidir. Nunca publicar el volumen mediante
Nginx o `express.static`.

## SMTP y password reset

Crear credencial SMTP exclusiva y remitente autorizado. Confirmar con el
proveedor si usa 465/TLS (`SMTP_SECURE=true`) o 587/STARTTLS (`false`).
Configurar SPF/DKIM/DMARC donde corresponda.
`PASSWORD_RESET_PUBLIC_URL` debe ser una URL HTTPS pública que termine en
`/restablecer-password`, nunca localhost. Probar entrega, expiración, uso
único, cambio de contraseña e invalidación de refresh tokens.

## CORS y builds Flutter

En producción `CORS_ORIGIN` es obligatorio y debe listar solo orígenes HTTPS
necesarios, separados por coma; no usar `*` ni patrones amplios.

```bash
flutter build web --release --dart-define=API_BASE_URL=https://API_PUBLICA
flutter build appbundle --release \
  --dart-define=API_BASE_URL=https://API_PUBLICA \
  --build-name=VERSION --build-number=NUMERO
```

Los defaults localhost/`10.0.2.2` son exclusivamente de desarrollo. Inspeccionar
el artefacto y no distribuir builds debug ni builds sin HTTPS.
El builder Docker está fijado a Flutter 3.44.4 y verifica el archivo oficial
por SHA-256; `pubspec.lock` se aplica con `--enforce-lockfile`.
El manifest release bloquea tráfico cleartext; el permiso temporal para HTTP
local existe únicamente en el manifest debug.

## Firma Android

Confirmar antes de la primera publicación la propiedad del `applicationId`
`com.indi.indi_combustible`. Generar el keystore fuera del repositorio, copiar
`frontend/android/key.properties.example` a `key.properties` y guardar
keystore/contraseñas en un gestor de secretos y backup cifrado. Validar en un
Android físico la instalación release, login, teclado, Back, cámara/galería,
evidencia, reapertura offline y sincronización.

## Docker, arranque y logs

```bash
docker compose config
docker compose build --pull
docker compose run --rm backend npm run migrate:prod
docker compose up -d
docker compose ps
curl --fail http://127.0.0.1:3000/health
docker compose logs --since=30m backend frontend db
```

Backend ejecuta como usuario `node`, usa `npm ci`, contiene dependencias de
runtime y recibe secretos al arrancar. Los servicios tienen health checks y
`restart: unless-stopped`.

## Nginx y HTTPS

El Nginx de la imagen resuelve fallback SPA, revalida `index.html`, cachea
assets, comprime y añade headers básicos. El reverse proxy del host debe
redirigir HTTP a HTTPS, reenviar `Host`, `X-Forwarded-For` y
`X-Forwarded-Proto`, y permitir multipart con margen sobre el límite actual de
5 MiB por imagen. No debe servir el volumen privado.

Con un servidor/dominio reales, emitir Let's Encrypt/Certbot, habilitar su
timer y ejecutar `certbot renew --dry-run`. No emitir certificados antes de
tener DNS definitivo.

## Superadmin inicial

No ejecutar `npm run seed` fuera de desarrollo: crea cuentas de demostración.
Inyectar temporalmente `SUPERADMIN_USERNAME`, `SUPERADMIN_PASSWORD`,
`SUPERADMIN_NOMBRE` y `SUPERADMIN_CORREO`, ejecutar y retirar la contraseña:

```bash
docker compose exec backend npm run seed:superadmin:prod
```

El comando es idempotente, no reemplaza usuarios existentes y no imprime la
contraseña.

## Backup y restauración

Como base: diario por 7 días y semanal por 4 semanas en preproducción;
producción requiere RPO/RTO aprobados. Cifrar y mantener una copia fuera del
servidor.

```bash
mkdir -p respaldos
docker compose exec -T db pg_dump -U "$POSTGRES_USER" -d "$POSTGRES_DB" \
  -Fc > respaldos/indi_FECHA.dump
docker run --rm -v indi_uploads:/source:ro -v "$PWD/respaldos:/backup" alpine \
  tar -czf /backup/evidencias_FECHA.tar.gz -C /source .
```

Restaurar primero en una DB y volumen aislados:

```bash
createdb indi_restore_test
pg_restore --exit-on-error --clean --if-exists -d indi_restore_test \
  respaldos/indi_FECHA.dump
docker run --rm -v indi_uploads_restore:/target -v "$PWD/respaldos:/backup:ro" alpine \
  tar -xzf /backup/evidencias_FECHA.tar.gz -C /target
```

Verificar conteos y descargar autenticadamente una evidencia conocida. Un
backup DB sin el backup de evidencias está incompleto.

## Smoke de preproducción

1. Servidor: `/health`, restart Backend/PostgreSQL y persistencia.
2. Auth: login/logout, guards, correo real y reset de un uso.
3. Chofer: solicitud, historial, detalle, evidencia, perfil y consumo.
4. Admin: aprobar, ajustar, rechazar, notificación, resumen y finanzas.
5. Offline: desconectar, operar, cerrar/reabrir, reconectar y sincronizar.
6. Web: IndexedDB, refresh y reapertura en Chrome.
7. Android físico: release firmado, Back, teclado, cámara/galería y offline.
8. Backup: restore de DB/evidencias en destino aislado.

## Rollback

- Antes de migrar, respaldar DB y evidencias y registrar hashes de imágenes.
- Backend: volver a imagen anterior solo si es compatible con el esquema.
- Web: volver a imagen anterior; `index.html` no queda cacheado.
- No ejecutar migraciones descendentes destructivas: no existen en el proyecto.
- Si una migración falla, detener y conservar logs; probar restauración aparte.
- Si SMTP falla, no exponer tokens por canales alternos.
- Si PostgreSQL falla, `/health` responde 503; no aceptar escrituras hasta
  recuperar y validar integridad.

## Promoción

`dev-frontend` pasa por CI, nuevo RC, preproducción y QA antes de una versión
estable. El despliegue permanece manual/controlado hasta contar con servidor,
dominio, secretos y aprobaciones. Nunca auto-desplegar producción desde un push
a `dev-frontend`.
