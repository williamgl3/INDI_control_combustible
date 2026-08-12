# INDI Combustible — Backend

API REST (Express + TypeScript + PostgreSQL) para el sistema de control y
autorización de combustible de Grupo INDI. Sirve a la app Flutter en
`../frontend/`.

## Requisitos

- Node.js 20+
- Docker (para levantar Postgres local vía `docker-compose.yml`) — o una
  instancia propia de Postgres 18, ajustando `DATABASE_URL`.

## Levantar el proyecto

```bash
cp .env.example .env      # ajusta JWT_SECRET al menos
npm install
npm run db:up               # Postgres en Docker (puerto 5432)
npm run migrate             # aplica las migraciones pendientes (ver abajo)
npm run seed                # siembra chofer1/admin1 de prueba
npm run dev                  # http://localhost:3000, recarga en caliente
```

## Variables de entorno (`.env`)

| Variable | Qué es |
|---|---|
| `DATABASE_URL` | cadena de conexión de Postgres |
| `PORT` | puerto del servidor (`3000` en desarrollo) |
| `JWT_SECRET` | firma los tokens de sesión — **cambiar en cualquier ambiente real** |
| `JWT_EXPIRES_IN` | legacy — solo se usa como fallback si `ACCESS_TOKEN_EXPIRES_IN` no está definido |
| `ACCESS_TOKEN_EXPIRES_IN` | vigencia del access token (JWT), default `15m` — corto a propósito, ver `POST /auth/refresh` |
| `REFRESH_TOKEN_EXPIRES_IN_DAYS` | vigencia del refresh token en días (default `30`) |
| `UPLOADS_DIR` | carpeta donde se guardan las fotos de ticket/tablero |
| `PRESUPUESTO_SEMANAL_TOTAL` | placeholder del presupuesto semanal en pesos |
| `CORS_ORIGIN` | origin(es) permitidos, separados por coma, admite `*` como comodín (ej. `http://localhost:*`) — si no se define, se permite cualquier origin (solo pensado para dev local) |
| `LOG_LEVEL` | nivel de log de pino (`trace`\|`debug`\|`info`\|`warn`\|`error`\|`fatal`) |
| `AUTH_RATE_LIMIT_WINDOW_MS` | ventana de rate limit para rutas de auth, en ms (default 15 min) |
| `AUTH_RATE_LIMIT_MAX` | intentos máx. por IP en la ventana para login/recuperar-password (default 10) |
| `AUTH_RATE_LIMIT_MAX_NORMAL` | intentos máx. por IP en la ventana para registro-chofer/cambiar-password (default 20) |
| `AUTH_RATE_LIMIT_MAX_REFRESH` | intentos máx. por IP en la ventana para `/auth/refresh` (default 30 — se llama automáticamente, no es un intento manual) |

## Scripts

- `npm run dev` — servidor con recarga en caliente (`ts-node-dev`).
- `npm run build` / `npm start` — compila a `dist/` y corre el JS compilado.
- `npm run migrate` — corre el runner de migraciones (`src/db/migrate.ts`),
  ver detalle abajo.
- `npm run seed` — siembra usuarios/vehículo de prueba (idempotente).
- `npm test` — corre la suite de `vitest`.

## Migraciones (`src/db/migrations/`)

El esquema ya no se aplica de un solo `schema.sql` a mano — vive como una
serie de migraciones numeradas e inmutables una vez mergeadas:

- `src/db/migrations/0001_baseline.sql` — captura tal cual el
  `schema.sql` histórico (idempotente), para que el historial arranque
  limpio.
- `src/db/migrations/000N_algo.sql` — cada cambio posterior de esquema.

El runner (`src/db/migrate.ts`, invocado por `npm run migrate`):

1. Crea la tabla `schema_migrations` si no existe (registra qué
   migraciones ya se aplicaron, por nombre de archivo).
2. Aplica en orden las que falten, cada una dentro de su propia
   transacción — si una falla, hace `ROLLBACK` y se detiene sin aplicar
   las siguientes ni marcarla como aplicada.

**Para agregar una migración nueva:** crea
`src/db/migrations/000N_descripcion.sql` con el siguiente número
consecutivo (revisa el último archivo en la carpeta) y corre
`npm run migrate`. No edites migraciones ya mergeadas — cualquier cambio
de esquema posterior va en un archivo nuevo encima. `src/db/schema.sql`
se conserva solo como referencia histórica de cómo se veía el esquema
antes de este sistema; ya no se aplica directamente.

## Despliegue

Pensado para desplegarse en Railway (variable `baseUrl` en
`frontend/lib/config/api_config.dart`) — **al momento de escribir esto el
despliegue de Railway no está funcionando** (devuelve 404 en toda ruta); para
desarrollo, usa el flujo local de arriba y apunta el frontend a
`http://localhost:3000`.

## Estructura

- `src/routes/` — endpoints Express, con validación `zod` por ruta.
- `src/services/` — lógica de negocio (réplica exacta de las reglas que antes
  vivían en los repositorios mock del frontend — ver comentarios cruzados).
- `src/middleware/` — auth (JWT), manejo de errores, subida de archivos.
- `src/db/` — `schema.sql` (esquema completo, idempotente), `migrate.ts`,
  `seed.ts`.

## CI

`.github/workflows/backend-ci.yml` corre `tsc --noEmit` y aplica el esquema
contra un Postgres efímero en cada push/PR que toque `backend/`.

## Flujo de unidades abastecedoras (migración 0031)

Las operaciones nuevas de Marimba y Pipa usan un único modelo de *unidad
abastecedora*. Una solicitud puede contener `consumo_propio`,
`carga_granel` o ambas partidas. Solo `carga_granel` crea una entrada en
`movimientos_inventario_marimba`; cada despacho a maquinaria crea la salida
correspondiente. El saldo nuevo se deriva exclusivamente de ese libro.

`suministros` es un flujo legado: se conservan tabla y lecturas históricas,
pero `POST /suministros` responde `410 Gone`. Su reemplazo es:

- `carga_partidas`, para distinguir lo cargado por concepto;
- `movimientos_inventario_marimba`, para entradas y salidas;
- `despachos_marimba`, para entregas a maquinaria del catálogo.

La cola offline actual no contiene el contrato suficiente para sincronizar
partidas, comprobantes, el saldo concurrente, el horómetro y la conciliación.
Hasta incorporar una `idempotencyKey` por solicitud, carga, entrada, despacho,
evidencia, cierre e incidencia, estas operaciones exigen conexión y los
conflictos permanecen visibles para reintento; no deben descartarse como
éxitos. Los ajustes, mermas, devoluciones y transferencias también quedan
fuera de 0031 y requieren un flujo administrativo auditado posterior.
