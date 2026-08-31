import bcrypt from 'bcrypt';
import { createHash, randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it, vi } from 'vitest';

const correoMock = vi.hoisted(() => ({ enviar: vi.fn() }));
vi.mock('../../src/services/correoService', () => ({
  enviarRecuperacionPassword: correoMock.enviar,
}));

import { pool } from '../../src/db/pool';
import * as authService from '../../src/services/authService';

const suite = process.env.RUN_PASSWORD_RESET_INTEGRATION === '1'
  ? describe.sequential
  : describe.skip;

function protegerBaseAislada(): void {
  const url = new URL(process.env.DATABASE_URL ?? '');
  if (
    !['127.0.0.1', 'localhost'].includes(url.hostname) ||
    !url.pathname.toLowerCase().endsWith('_test') ||
    url.port === '5432'
  ) {
    throw new Error(
      'La integración de recuperación exige una base local *_test fuera del puerto 5432.',
    );
  }
}

const usuarioId = randomUUID();
const usuario = `reset-${usuarioId}`;

suite('recuperación de contraseña con PostgreSQL real', () => {
  beforeAll(async () => {
    protegerBaseAislada();
    const migraciones = await pool.query<{ total: string }>(
      'SELECT count(*) total FROM schema_migrations',
    );
    expect(Number(migraciones.rows[0]!.total)).toBe(34);
    await pool.query(
      `INSERT INTO usuarios
         (id, usuario, password_hash, nombre, correo, rol, activo, token_version)
       VALUES ($1, $2, $3, 'Usuario reset', $4, 'chofer', true, 0)`,
      [usuarioId, usuario, await bcrypt.hash('password-anterior', 4), `${usuario}@test.invalid`],
    );
  });

  afterAll(async () => {
    await pool.query('DROP TRIGGER IF EXISTS fallo_reset_test ON password_reset_tokens');
    await pool.query('DROP FUNCTION IF EXISTS fallo_reset_test()');
    await pool.query('DELETE FROM auditoria_acciones WHERE usuario_id = $1', [usuarioId]);
    await pool.query('DELETE FROM usuarios WHERE id = $1', [usuarioId]);
    await pool.end();
  });

  it('crea un token válido sin ejecutar múltiples comandos parametrizados', async () => {
    correoMock.enviar.mockResolvedValueOnce(undefined);

    await authService.recuperarPassword(usuario);

    expect(correoMock.enviar).toHaveBeenCalledOnce();
    const token = correoMock.enviar.mock.calls[0]![1] as string;
    const tokenHash = createHash('sha256').update(token).digest('hex');
    const tokens = await pool.query<{
      token_hash: string;
      usado_en: Date | null;
      vigente: boolean;
    }>(
      `SELECT token_hash, usado_en, expira_en > NOW() AS vigente
         FROM password_reset_tokens WHERE usuario_id = $1`,
      [usuarioId],
    );
    expect(tokens.rows).toEqual([
      { token_hash: tokenHash, usado_en: null, vigente: true },
    ]);

    await authService.restablecerPassword(token, 'password-nueva');
    const estado = await pool.query<{
      password_hash: string;
      token_version: number;
      usado: boolean;
    }>(
      `SELECT u.password_hash, u.token_version, prt.usado_en IS NOT NULL AS usado
         FROM usuarios u
         JOIN password_reset_tokens prt ON prt.usuario_id = u.id
        WHERE u.id = $1`,
      [usuarioId],
    );
    expect(await bcrypt.compare('password-nueva', estado.rows[0]!.password_hash)).toBe(true);
    expect(estado.rows[0]!.token_version).toBe(1);
    expect(estado.rows[0]!.usado).toBe(true);
  });

  it('revierte la invalidación anterior cuando falla el INSERT nuevo', async () => {
    const tokenAnterior = randomUUID();
    const hashAnterior = createHash('sha256').update(tokenAnterior).digest('hex');
    await pool.query(
      `INSERT INTO password_reset_tokens (usuario_id, token_hash, expira_en)
       VALUES ($1, $2, NOW() + INTERVAL '30 minutes')`,
      [usuarioId, hashAnterior],
    );
    await pool.query(`CREATE FUNCTION fallo_reset_test() RETURNS trigger LANGUAGE plpgsql AS $$
      BEGIN
        IF NEW.usuario_id = '${usuarioId}'::uuid THEN
          RAISE EXCEPTION 'fallo de inserción simulado';
        END IF;
        RETURN NEW;
      END $$`);
    await pool.query(
      `CREATE TRIGGER fallo_reset_test BEFORE INSERT ON password_reset_tokens
       FOR EACH ROW EXECUTE FUNCTION fallo_reset_test()`,
    );

    try {
      await expect(authService.recuperarPassword(usuario)).rejects.toThrow(
        'fallo de inserción simulado',
      );
    } finally {
      await pool.query('DROP TRIGGER fallo_reset_test ON password_reset_tokens');
      await pool.query('DROP FUNCTION fallo_reset_test()');
    }

    const anterior = await pool.query<{ usado_en: Date | null }>(
      'SELECT usado_en FROM password_reset_tokens WHERE token_hash = $1',
      [hashAnterior],
    );
    expect(anterior.rows).toEqual([{ usado_en: null }]);
  });
});
