import { mkdtemp, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import type { Request } from 'express';
import { describe, expect, test, vi } from 'vitest';

const query = vi.fn();
const release = vi.fn();
vi.mock('../src/db/pool', () => ({ pool: { connect: vi.fn(async () => ({ query, release })) } }));

import { canonicalizar, fingerprintRequest, sha256DeArchivo } from '../src/utils/requestFingerprint';
import { ejecutarIdempotente, leerIdempotencyKey, MAX_RESPONSE_BODY_BYTES,
  OPERACIONES_IDEMPOTENTES, serializarRespuestaIdempotente } from '../src/services/idempotenciaService';

function requestConHeaders(rawHeaders: string[]): Request {
  return { rawHeaders } as Request;
}

describe('contrato Idempotency-Key', () => {
  test('acepta exclusivamente UUID v4', () => {
    expect(leerIdempotencyKey(requestConHeaders(['Idempotency-Key', '550e8400-e29b-41d4-a716-446655440000']), true))
      .toBe('550e8400-e29b-41d4-a716-446655440000');
  });

  test.each([
    ['demasiado larga', 'a'.repeat(65)],
    ['lista', '550e8400-e29b-41d4-a716-446655440000,550e8400-e29b-41d4-a716-446655440001'],
    ['arbitraria', 'operacion-1'],
    ['uuid no v4', '550e8400-e29b-11d4-a716-446655440000'],
  ])('rechaza %s', (_nombre, valor) => {
    expect(() => leerIdempotencyKey(requestConHeaders(['Idempotency-Key', valor]), true)).toThrow();
  });

  test('rechaza headers repetidos', () => {
    expect(() => leerIdempotencyKey(requestConHeaders([
      'Idempotency-Key', '550e8400-e29b-41d4-a716-446655440000',
      'idempotency-key', '550e8400-e29b-41d4-a716-446655440000',
    ]), true)).toThrow();
  });
});

describe('fingerprint canonico', () => {
  test('ordena objetos, conserva arrays y normaliza fechas/numeros', () => {
    const a = { b: 2.5, a: new Date('2026-08-24T10:00:00-06:00'), lista: [2, 1] };
    const b = { lista: [2, 1], a: '2026-08-24T16:00:00.000Z', b: 2.5 };
    expect(canonicalizar(a)).toEqual(canonicalizar(b));
    expect(fingerprintRequest(a)).toBe(fingerprintRequest(b));
    expect(fingerprintRequest({ ...b, b: 2.6 })).not.toBe(fingerprintRequest(a));
  });

  test('el hash multipart depende de bytes y no de path', async () => {
    const dir = await mkdtemp(join(tmpdir(), 'indi-fingerprint-'));
    try {
      const uno = join(dir, 'temporal-a.jpg'); const dos = join(dir, 'otro-nombre.jpg');
      await Promise.all([writeFile(uno, Buffer.from('mismos bytes')), writeFile(dos, Buffer.from('mismos bytes'))]);
      expect(await sha256DeArchivo(uno)).toBe(await sha256DeArchivo(dos));
    } finally { await rm(dir, { recursive: true, force: true }); }
  });

  test('no incorpora Authorization ni tokens si no forman parte del objeto semantico', () => {
    const semantica = { vehiculoId: 'v', litros: 10 };
    expect(fingerprintRequest(semantica)).toBe(fingerprintRequest({ litros: 10, vehiculoId: 'v' }));
  });
});

describe('respuesta y coordinador', () => {
  test('rechaza secretos, binarios y respuestas mayores al limite', () => {
    expect(() => serializarRespuestaIdempotente({ access_token: 'secreto' })).toThrow();
    expect(() => serializarRespuestaIdempotente({ foto: Buffer.from([1, 2]) })).toThrow();
    expect(() => serializarRespuestaIdempotente({ texto: 'x'.repeat(MAX_RESPONSE_BODY_BYTES) })).toThrow();
  });

  test('replay no ejecuta callback de negocio', async () => {
    query.mockReset(); release.mockReset();
    query
      .mockResolvedValueOnce({}) // BEGIN
      .mockResolvedValueOnce({ rowCount: 0, rows: [] })
      .mockResolvedValueOnce({ rows: [{ request_hash: 'a'.repeat(64), resource_type: 'incidencia_vehiculo',
        resource_id: '11111111-1111-4111-8111-111111111111', http_status: 201, response_body: { id: 'original' } }] })
      .mockResolvedValueOnce({}); // COMMIT
    const ejecutar = vi.fn();
    const resultado = await ejecutarIdempotente({ usuarioId: '22222222-2222-4222-8222-222222222222',
      operacion: OPERACIONES_IDEMPOTENTES.reportarIncidencia,
      idempotencyKey: '550e8400-e29b-41d4-a716-446655440000', requestHash: 'a'.repeat(64), ejecutar });
    expect(ejecutar).not.toHaveBeenCalled();
    expect(resultado).toMatchObject({ status: 201, body: { id: 'original' }, replayed: true });
  });

  test('payload diferente produce codigo estable sin ejecutar negocio', async () => {
    query.mockReset();
    query.mockResolvedValueOnce({}).mockResolvedValueOnce({ rowCount: 0, rows: [] })
      .mockResolvedValueOnce({ rows: [{ request_hash: 'b'.repeat(64), http_status: 201 }] })
      .mockResolvedValue({});
    const ejecutar = vi.fn();
    await expect(ejecutarIdempotente({ usuarioId: '22222222-2222-4222-8222-222222222222',
      operacion: OPERACIONES_IDEMPOTENTES.reportarIncidencia,
      idempotencyKey: '550e8400-e29b-41d4-a716-446655440000', requestHash: 'a'.repeat(64), ejecutar }))
      .rejects.toMatchObject({ status: 409, codigo: 'IDEMPOTENCY_KEY_PAYLOAD_MISMATCH' });
    expect(ejecutar).not.toHaveBeenCalled();
  });
});
