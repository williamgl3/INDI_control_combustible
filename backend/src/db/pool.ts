import dotenv from 'dotenv';
import { Pool } from 'pg';
import { logger } from '../utils/logger';

// Se carga aquí (no solo en index.ts) porque los `import` de ES/TS se
// izan (hoisting) antes que cualquier código del módulo que importa este
// archivo — si `dotenv.config()` corriera solo en el entrypoint, este
// Pool ya se habría construido con `DATABASE_URL` undefined para
// cualquier script que haga `import { pool } from './pool'` antes de
// configurar dotenv él mismo (ej. `migrate.ts`, `seed.ts`).
dotenv.config({ quiet: true });

/// Pool de conexiones a Postgres, compartido por todos los servicios.
/// `DATABASE_URL` viene de `.env` (ver `.env.example`). `DATABASE_SSL=true`
/// habilita TLS — AWS RDS lo requiere por defecto en la mayoría de
/// parameter groups (`rds.force_ssl`). `rejectUnauthorized: false` acepta
/// el certificado autofirmado que expone RDS sin tener que empaquetar su
/// CA bundle; sigue siendo tráfico cifrado, solo no valida la cadena de
/// certificación — suficiente para este proyecto, no para datos regulados.
export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl:
    process.env.DATABASE_SSL === 'true'
      ? { rejectUnauthorized: false }
      : undefined,
});

pool.on('error', (err) => {
  logger.error({ err }, 'Error inesperado en el pool de Postgres');
});
