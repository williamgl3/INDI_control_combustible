import { mkdtemp, rm, writeFile, readFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { describe, expect, test } from 'vitest';

import { fingerprintSolicitud, sha256Archivo } from '../src/utils/idempotenciaSolicitud';

describe('idempotencia de solicitudes', () => {
  test('fingerprint canonico normaliza texto y conserva cambios reales', () => {
    const base = {
      choferId: '11111111-1111-4111-8111-111111111111',
      vehiculoId: '22222222-2222-4222-8222-222222222222',
      litrosSolicitados: 40,
      esUrgente: false,
      motivoChofer: null,
      fechaProgramada: '2026-08-22T06:00:00.000Z',
      fotoSha256: 'a'.repeat(64),
    };
    const primero = fingerprintSolicitud({ ...base, actividad: '  Trabajo   normal ' });
    const replay = fingerprintSolicitud({ ...base, actividad: 'Trabajo normal' });
    const diferente = fingerprintSolicitud({ ...base, actividad: 'Otro trabajo' });
    expect(primero).toBe(replay);
    expect(primero).toMatch(/^[0-9a-f]{64}$/);
    expect(diferente).not.toBe(primero);
  });

  test('hash de fotografia depende del contenido, no de la ruta', async () => {
    const directorio = await mkdtemp(join(tmpdir(), 'indi-idempotencia-'));
    try {
      const primera = join(directorio, 'a.jpg');
      const segunda = join(directorio, 'b.jpg');
      await Promise.all([
        writeFile(primera, Buffer.from([0xff, 0xd8, 0xff, 1, 2, 3])),
        writeFile(segunda, Buffer.from([0xff, 0xd8, 0xff, 1, 2, 3])),
      ]);
      expect(await sha256Archivo(primera)).toBe(await sha256Archivo(segunda));
    } finally {
      await rm(directorio, { recursive: true, force: true });
    }
  });

  test('migracion deja historicos null y aporta ambas defensas unicas', async () => {
    const sql = await readFile(
      join(process.cwd(), 'src/db/migrations/0032_solicitudes_idempotencia.sql'),
      'utf8',
    );
    expect(sql).toContain('ADD COLUMN idempotency_key UUID');
    expect(sql).toContain('uq_solicitudes_chofer_idempotency');
    expect(sql).toContain('uq_solicitudes_pendiente_negocio');
    expect(sql).toContain("WHERE estado = 'pendiente'");
    expect(sql).not.toMatch(/ON DELETE CASCADE/i);
    expect(sql).not.toMatch(/UPDATE\s+solicitudes_autorizacion/i);
  });
});
