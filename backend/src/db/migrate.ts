import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { pool } from './pool';
import { logger } from '../utils/logger';

/// Runner de migraciones versionado y minimalista (sin ORM/framework
/// nuevo, sigue usando `pg` crudo).
///
/// - `src/db/migrations/*.sql` — archivos numerados (`0001_...sql`,
///   `0002_...sql`, ...), cada uno una migración inmutable una vez
///   mergeada. El primero (`0001_baseline.sql`) captura el `schema.sql`
///   histórico tal cual, para que el historial arranque limpio.
/// - Tabla `schema_migrations` — registra qué migraciones ya se
///   aplicaron (por nombre de archivo), para no volver a correrlas.
/// - Cada migración pendiente se aplica dentro de su propia transacción:
///   si falla, se hace ROLLBACK y el runner se detiene sin marcarla como
///   aplicada (y sin aplicar las siguientes).
///
/// Para agregar una migración nueva: crea `src/db/migrations/000N_algo.sql`
/// con el siguiente número consecutivo y corre `npm run migrate`. No
/// edites migraciones ya aplicadas/mergeadas — agrega una nueva encima.
const MIGRATIONS_DIR = join(__dirname, 'migrations');

async function asegurarTablaControl(): Promise<void> {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS schema_migrations (
      name TEXT PRIMARY KEY,
      applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `);
}

function listarArchivosMigracion(): string[] {
  return readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith('.sql'))
    .sort();
}

async function migrar(): Promise<void> {
  await asegurarTablaControl();

  const { rows } = await pool.query<{ name: string }>('SELECT name FROM schema_migrations');
  const aplicadas = new Set(rows.map((r) => r.name));

  const archivos = listarArchivosMigracion();
  const pendientes = archivos.filter((f) => !aplicadas.has(f));

  if (pendientes.length === 0) {
    logger.info('No hay migraciones pendientes.');
    return;
  }

  for (const archivo of pendientes) {
    const sql = readFileSync(join(MIGRATIONS_DIR, archivo), 'utf-8');
    const client = await pool.connect();
    try {
      logger.info({ migracion: archivo }, 'Aplicando migración...');
      await client.query('BEGIN');
      await client.query(sql);
      await client.query('INSERT INTO schema_migrations (name) VALUES ($1)', [archivo]);
      await client.query('COMMIT');
      logger.info({ migracion: archivo }, 'Migración aplicada.');
    } catch (err) {
      await client.query('ROLLBACK');
      logger.error({ migracion: archivo, err }, 'Error aplicando migración, se detiene el runner.');
      throw err;
    } finally {
      client.release();
    }
  }

  logger.info('Migraciones al día.');
}

migrar()
  .then(() => pool.end())
  .catch(async (err) => {
    logger.error({ err }, 'Fallo el proceso de migración.');
    await pool.end();
    process.exit(1);
  });
