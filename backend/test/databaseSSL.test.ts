import { vi, describe, it, expect, afterEach } from 'vitest';
import { mkdirSync, writeFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';

// Mockear `pg` para que `new Pool(...)` no intente conectarse a Postgres
// al importar pool.ts (el Pool se crea a nivel de módulo).
vi.mock('pg', () => {
  return {
    Pool: class MockPool {
      on = vi.fn();
      query = vi.fn();
    },
  };
});

// Mockear logger para no producir salida en tests
vi.mock('../src/utils/logger', () => ({
  logger: { info: vi.fn(), debug: vi.fn(), error: vi.fn() },
}));

const { buildDatabaseSSLConfig, parseDatabaseSSL, parsePoolInteger } = await import(
  '../src/db/pool'
);

describe('parsePoolInteger', () => {
  it('usa el valor por defecto si no está configurado', () => {
    expect(parsePoolInteger('DATABASE_POOL_MAX', undefined, 10)).toBe(10);
  });

  it('acepta un entero positivo', () => {
    expect(parsePoolInteger('DATABASE_POOL_MAX', '20', 10)).toBe(20);
  });

  it.each(['0', '-1', '1.5', 'abc'])('rechaza el valor inválido %s', (raw) => {
    expect(() => parsePoolInteger('DATABASE_POOL_MAX', raw, 10)).toThrow(
      'DATABASE_POOL_MAX debe ser un entero positivo',
    );
  });
});

// ── parseDatabaseSSL ─────────────────────────────────────────────

describe('parseDatabaseSSL', () => {
  it('devuelve false para undefined', () => {
    expect(parseDatabaseSSL(undefined)).toBe(false);
  });

  it('devuelve false para string vacío', () => {
    expect(parseDatabaseSSL('')).toBe(false);
  });

  it('devuelve false para espacios en blanco', () => {
    expect(parseDatabaseSSL('   ')).toBe(false);
  });

  it('devuelve true para "true"', () => {
    expect(parseDatabaseSSL('true')).toBe(true);
  });

  it('devuelve false para "false"', () => {
    expect(parseDatabaseSSL('false')).toBe(false);
  });

  it('lanza para "yes"', () => {
    expect(() => parseDatabaseSSL('yes')).toThrow('DATABASE_SSL inválido');
  });

  it('lanza para "1"', () => {
    expect(() => parseDatabaseSSL('1')).toThrow('DATABASE_SSL inválido');
  });

  it('lanza para "on"', () => {
    expect(() => parseDatabaseSSL('on')).toThrow('DATABASE_SSL inválido');
  });

  it('lanza para "TRUE" (mayúsculas)', () => {
    expect(() => parseDatabaseSSL('TRUE')).toThrow('DATABASE_SSL inválido');
  });
});

// ── buildDatabaseSSLConfig ───────────────────────────────────────

const PEM_VALID =
  '-----BEGIN CERTIFICATE-----\nMIIDazCCAlOgAwIBAgIUJ3...\n-----END CERTIFICATE-----';
const PEM_VALID_CON_BACKSLASH_N =
  '-----BEGIN CERTIFICATE-----\\nMIIDazCCAlOgAwIBAgIUJ3...\\n-----END CERTIFICATE-----';

describe('buildDatabaseSSLConfig', () => {
  afterEach(() => {
    vi.restoreAllMocks();
  });

  it('devuelve undefined cuando SSL está deshabilitado', () => {
    expect(
      buildDatabaseSSLConfig({ DATABASE_SSL: 'false', NODE_ENV: 'production' }),
    ).toBeUndefined();
  });

  it('devuelve undefined cuando SSL no está definido', () => {
    expect(buildDatabaseSSLConfig({ NODE_ENV: 'development' })).toBeUndefined();
  });

  it('devuelve undefined cuando SSL es string vacío', () => {
    expect(
      buildDatabaseSSLConfig({ DATABASE_SSL: '', NODE_ENV: 'development' }),
    ).toBeUndefined();
  });

  it('rechaza valores inválidos de DATABASE_SSL', () => {
    expect(() =>
      buildDatabaseSSLConfig({ DATABASE_SSL: 'yes' }),
    ).toThrow('DATABASE_SSL inválido');
  });

  // ── Producción ────────────────────────────────────────────────

  describe('producción', () => {
    it('rejectUnauthorized=true con CA válida', () => {
      const result = buildDatabaseSSLConfig({
        DATABASE_SSL: 'true',
        DATABASE_CA_CERT: PEM_VALID,
        NODE_ENV: 'production',
      });
      expect(result).toEqual({
        rejectUnauthorized: true,
        ca: PEM_VALID,
      });
    });

    it('rejectUnauthorized=true con CA por path', () => {
      const tmpDir = join(
        process.cwd(),
        'test-tmp-ca-' + Date.now(),
      );
      mkdirSync(tmpDir, { recursive: true });
      const caPath = join(tmpDir, 'ca.pem');
      writeFileSync(caPath, PEM_VALID);

      try {
        const result = buildDatabaseSSLConfig({
          DATABASE_SSL: 'true',
          DATABASE_CA_CERT_PATH: caPath,
          NODE_ENV: 'production',
        });
        expect(result).toEqual({
          rejectUnauthorized: true,
          ca: PEM_VALID,
        });
      } finally {
        rmSync(tmpDir, { recursive: true, force: true });
      }
    });

    it('falla si falta CA en producción', () => {
      expect(() =>
        buildDatabaseSSLConfig({
          DATABASE_SSL: 'true',
          NODE_ENV: 'production',
        }),
      ).toThrow('requiere una CA');
    });

    it('falla si la CA path no existe en producción', () => {
      expect(() =>
        buildDatabaseSSLConfig({
          DATABASE_SSL: 'true',
          DATABASE_CA_CERT_PATH: '/ruta/inexistente/ca.pem',
          NODE_ENV: 'production',
        }),
      ).toThrow('No se pudo leer el archivo CA');
    });
  });

  // ── Desarrollo / test ─────────────────────────────────────────

  describe('desarrollo / test', () => {
    it('rejectUnauthorized=false sin CA (backward compat)', () => {
      const result = buildDatabaseSSLConfig({
        DATABASE_SSL: 'true',
        NODE_ENV: 'development',
      });
      expect(result).toEqual({ rejectUnauthorized: false });
    });

    it('rejectUnauthorized=false sin CA en test', () => {
      const result = buildDatabaseSSLConfig({
        DATABASE_SSL: 'true',
        NODE_ENV: 'test',
      });
      expect(result).toEqual({ rejectUnauthorized: false });
    });

    it('rejectUnauthorized=true con CA en desarrollo', () => {
      const result = buildDatabaseSSLConfig({
        DATABASE_SSL: 'true',
        DATABASE_CA_CERT: PEM_VALID,
        NODE_ENV: 'development',
      });
      expect(result).toEqual({
        rejectUnauthorized: true,
        ca: PEM_VALID,
      });
    });

    it('sin NODE_ENV trata como desarrollo', () => {
      const result = buildDatabaseSSLConfig({
        DATABASE_SSL: 'true',
      });
      expect(result).toEqual({ rejectUnauthorized: false });
    });
  });

  // ── CA precedence ─────────────────────────────────────────────

  describe('precedencia CA', () => {
    it('DATABASE_CA_CERT tiene precedencia sobre DATABASE_CA_CERT_PATH', () => {
      const tmpDir = join(
        process.cwd(),
        'test-tmp-ca-' + Date.now(),
      );
      mkdirSync(tmpDir, { recursive: true });
      const caPath = join(tmpDir, 'ca.pem');
      writeFileSync(caPath, '-----BEGIN CERTIFICATE-----\nOTRO PEM\n-----END CERTIFICATE-----');

      try {
        const result = buildDatabaseSSLConfig({
          DATABASE_SSL: 'true',
          DATABASE_CA_CERT: PEM_VALID,
          DATABASE_CA_CERT_PATH: caPath,
          NODE_ENV: 'production',
        });
        // Debe usar el inline PEM, no el archivo
        expect(result?.ca).toBe(PEM_VALID);
      } finally {
        rmSync(tmpDir, { recursive: true, force: true });
      }
    });
  });

  // ── PEM normalization ─────────────────────────────────────────

  describe('normalización PEM', () => {
    it('normaliza \\n literales a saltos reales', () => {
      const result = buildDatabaseSSLConfig({
        DATABASE_SSL: 'true',
        DATABASE_CA_CERT: PEM_VALID_CON_BACKSLASH_N,
        NODE_ENV: 'development',
      });
      expect(result?.ca).toBe(PEM_VALID);
    });

    it('mantienen PEM con saltos reales tal cual', () => {
      const result = buildDatabaseSSLConfig({
        DATABASE_SSL: 'true',
        DATABASE_CA_CERT: PEM_VALID,
        NODE_ENV: 'development',
      });
      expect(result?.ca).toBe(PEM_VALID);
    });

    it('lanza si el PEM no tiene BEGIN/END CERTIFICATE', () => {
      expect(() =>
        buildDatabaseSSLConfig({
          DATABASE_SSL: 'true',
          DATABASE_CA_CERT: 'esto no es un PEM',
          NODE_ENV: 'development',
        }),
      ).toThrow('no parece un PEM válido');
    });
  });

  // ── DATABASE_URL interaction ──────────────────────────────────

  describe('DATABASE_URL y sslmode', () => {
    it('DATABASE_SSL ausente no toca la URL', () => {
      // Solo verificamos que buildDatabaseSSLConfig no interviene;
      // la limpieza de URL se hace en pool.ts a nivel de módulo.
      expect(
        buildDatabaseSSLConfig({ NODE_ENV: 'development' }),
      ).toBeUndefined();
    });
  });

  // ── Producción never falls back ───────────────────────────────

  describe('producción nunca cae a rejectUnauthorized=false', () => {
    it('producción + SSL true + sin CA → lanza, no retorna false', () => {
      let threw = false;
      try {
        buildDatabaseSSLConfig({
          DATABASE_SSL: 'true',
          NODE_ENV: 'production',
        });
      } catch {
        threw = true;
      }
      expect(threw).toBe(true);
    });
  });
});
