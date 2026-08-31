import { readFileSync } from 'node:fs';
import dotenv from 'dotenv';
import { Pool } from 'pg';
import type { ConnectionOptions } from 'node:tls';
import { logger } from '../utils/logger';

// Se carga aquí (no solo en index.ts) porque los `import` de ES/TS se
// izan (hoisting) antes que cualquier código del módulo que importa este
// archivo — si `dotenv.config()` corriera solo en el entrypoint, este
// Pool ya se habría construido con `DATABASE_URL` undefined para
// cualquier script que haga `import { pool } from './pool'` antes de
// configurar dotenv él mismo (ej. `migrate.ts`, `seed.ts`).
dotenv.config({ quiet: true });

// ── Configuración TLS de PostgreSQL ──────────────────────────────
//
// Extraída como función pura para poder testearse sin contactar PG.
//
// Precedencia de DATABASE_SSL sobre DATABASE_URL:
//   Si DATABASE_SSL está definido explícitamente, se limpia `sslmode`
//   del connection string para que la config explícita no entre en
//   conflicto con parámetros como `sslmode=no-verify` en la URL.
//
// Producción:
//   - DATABASE_SSL=true + CA requerida → rejectUnauthorized: true
//   - DATABASE_SSL=true + sin CA → FATAL (process.exit)
//   - DATABASE_SSL=false → WARN (permitido para Docker interno)
//
// Desarrollo / test:
//   - DATABASE_SSL=true + sin CA → rejectUnauthorized: false (backward compat)
//   - DATABASE_SSL=false o ausente → sin SSL

export function parseDatabaseSSL(raw: string | undefined): boolean {
  if (raw === undefined || raw.trim() === '') return false;
  if (raw === 'true') return true;
  if (raw === 'false') return false;
  throw new Error(
    `DATABASE_SSL inválido: "${raw}". Acepta únicamente "true" o "false".`,
  );
}

function normalizePem(raw: string): string {
  // Si contiene `\n` literales (backslash + n) sin saltos reales,
  // convertir a saltos reales — algunos orquestadores los guardan así.
  if (raw.includes('\\n') && !raw.includes('\n')) {
    return raw.replace(/\\n/g, '\n');
  }
  return raw;
}

function readCaCert(
  inlinePem: string | undefined,
  caCertPath: string | undefined,
): string | undefined {
  // DATABASE_CA_CERT (inline PEM) tiene precedencia sobre DATABASE_CA_CERT_PATH
  if (inlinePem && inlinePem.trim() !== '') {
    const normalized = normalizePem(inlinePem.trim());
    if (
      !normalized.includes('-----BEGIN CERTIFICATE-----') ||
      !normalized.includes('-----END CERTIFICATE-----')
    ) {
      throw new Error(
        'DATABASE_CA_CERT no parece un PEM válido (faltan BEGIN/END CERTIFICATE).',
      );
    }
    return normalized;
  }
  if (caCertPath && caCertPath.trim() !== '') {
    try {
      return readFileSync(caCertPath.trim(), 'utf8');
    } catch {
      throw new Error(
        `No se pudo leer el archivo CA en "${caCertPath.trim()}". Verifica la ruta.`,
      );
    }
  }
  return undefined;
}

export function buildDatabaseSSLConfig(env: {
  DATABASE_SSL?: string | undefined;
  DATABASE_CA_CERT?: string | undefined;
  DATABASE_CA_CERT_PATH?: string | undefined;
  NODE_ENV?: string | undefined;
}): ConnectionOptions | undefined {
  const sslEnabled = parseDatabaseSSL(env.DATABASE_SSL);
  if (!sslEnabled) return undefined;

  const isProduction = env.NODE_ENV === 'production';
  const ca = readCaCert(env.DATABASE_CA_CERT, env.DATABASE_CA_CERT_PATH);

  if (isProduction) {
    if (!ca) {
      throw new Error(
        'DATABASE_SSL=true en producción requiere una CA para validar ' +
          'el certificado del servidor. Configura DATABASE_CA_CERT (PEM) ' +
          'o DATABASE_CA_CERT_PATH (ruta al archivo). Sin esto, la ' +
          'conexión no puede validarse de forma segura.',
      );
    }
    return { rejectUnauthorized: true, ca };
  }

  // Desarrollo / test: si hay CA se valida; si no, se acepta todo
  // (backward compatible con RDS self-signed, Docker local, etc.)
  if (ca) {
    return { rejectUnauthorized: true, ca };
  }
  return { rejectUnauthorized: false };
}

// ── Construcción del Pool ────────────────────────────────────────

let rawUrl = process.env.DATABASE_URL;

// Si DATABASE_SSL está definido explícitamente, eliminar `sslmode` del
// URL para evitar contradicciones (ej. sslmode=no-verify vs
// rejectUnauthorized=true).
if (process.env.DATABASE_SSL !== undefined && rawUrl) {
  try {
    const url = new URL(rawUrl);
    url.searchParams.delete('sslmode');
    rawUrl = url.toString();
  } catch {
    // Si la URL es inválida, pg ya fallará con un error claro.
  }
}

const sslConfig = buildDatabaseSSLConfig({
  DATABASE_SSL: process.env.DATABASE_SSL,
  DATABASE_CA_CERT: process.env.DATABASE_CA_CERT,
  DATABASE_CA_CERT_PATH: process.env.DATABASE_CA_CERT_PATH,
  NODE_ENV: process.env.NODE_ENV,
});

export const pool = new Pool({
  connectionString: rawUrl,
  ssl: sslConfig,
});

pool.on('error', (err) => {
  logger.error({ err }, 'Error inesperado en el pool de Postgres');
});

// Log seguro al inicio — nunca incluir password, CA ni connection string
if (sslConfig) {
  logger.info(
    {
      dbSsl: true,
      dbCaConfigured: !!sslConfig.ca,
      dbRejectUnauthorized: sslConfig.rejectUnauthorized,
    },
    'Pool PostgreSQL inicializado con TLS',
  );
} else {
  logger.debug('Pool PostgreSQL inicializado sin TLS');
}
