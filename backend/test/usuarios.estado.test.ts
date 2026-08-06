import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

import { pool } from '../src/db/pool';
import { crearAppDePrueba } from './testApp';
import { firmarToken } from '../src/utils/jwt';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

describe('PATCH /usuarios/:id/estado', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('responde 403 cuando lo intenta un chofer (requireRole bloquea)', async () => {
    const tokenDeChofer = firmarToken({
      sub: 'chofer-1',
      usuario: 'chofer1',
      rol: 'chofer',
      tokenVersion: 1,
    });
    // requireAuth compara token_version contra BD antes de llegar a
    // requireRole — debe coincidir para que la petición avance hasta ahí.
    poolQueryMock.mockResolvedValueOnce({ rows: [{ token_version: 1 }] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .patch('/usuarios/22222222-2222-2222-2222-222222222222/estado')
      .set('Authorization', `Bearer ${tokenDeChofer}`)
      .send({ activo: false });

    expect(res.status).toBe(403);
  });

  it('responde 400 si un administrativo intenta desactivarse a sí mismo', async () => {
    const propioId = '11111111-1111-1111-1111-111111111111';
    const tokenAdmin = firmarToken({
      sub: propioId,
      usuario: 'admin1',
      rol: 'administrativo',
      tokenVersion: 1,
    });
    poolQueryMock.mockResolvedValueOnce({ rows: [{ token_version: 1 }] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .patch(`/usuarios/${propioId}/estado`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ activo: false });

    expect(res.status).toBe(400);
  });

  it('responde 204 cuando un administrativo desactiva la cuenta de un chofer', async () => {
    const adminId = '11111111-1111-1111-1111-111111111111';
    const otroId = '22222222-2222-2222-2222-222222222222';
    const tokenAdmin = firmarToken({
      sub: adminId,
      usuario: 'admin1',
      rol: 'administrativo',
      tokenVersion: 1,
    });
    // 1) requireAuth: token_version.
    poolQueryMock.mockResolvedValueOnce({ rows: [{ token_version: 1 }] });
    // 2) actualizarEstadoUsuario: SELECT del objetivo (para saber su rol).
    poolQueryMock.mockResolvedValueOnce({ rows: [{ id: otroId, rol: 'chofer', activo: true }] });
    // 3) actualizarEstadoUsuario: UPDATE ... RETURNING *.
    poolQueryMock.mockResolvedValueOnce({ rows: [{ id: otroId, activo: false }] });
    // 4) revocarTodosLosRefreshTokensDe (se desactivó la cuenta).
    poolQueryMock.mockResolvedValueOnce({ rows: [] });
    // 5) registrarAuditoria (best-effort, no debe tirar la petición si falla).
    poolQueryMock.mockResolvedValueOnce({ rows: [] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .patch(`/usuarios/${otroId}/estado`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ activo: false });

    expect(res.status).toBe(204);
  });

  it('responde 403 cuando un administrativo intenta cambiar el estado de otro administrativo', async () => {
    const adminId = '11111111-1111-1111-1111-111111111111';
    const otroAdminId = '33333333-3333-3333-3333-333333333333';
    const tokenAdmin = firmarToken({
      sub: adminId,
      usuario: 'admin1',
      rol: 'administrativo',
      tokenVersion: 1,
    });
    poolQueryMock.mockResolvedValueOnce({ rows: [{ token_version: 1 }] });
    poolQueryMock.mockResolvedValueOnce({
      rows: [{ id: otroAdminId, rol: 'administrativo', activo: true }],
    });

    const app = crearAppDePrueba();
    const res = await request(app)
      .patch(`/usuarios/${otroAdminId}/estado`)
      .set('Authorization', `Bearer ${tokenAdmin}`)
      .send({ activo: false });

    expect(res.status).toBe(403);
  });

  it('responde 204 cuando un superadmin desactiva la cuenta de un administrativo', async () => {
    const superadminId = '44444444-4444-4444-4444-444444444444';
    const adminId = '11111111-1111-1111-1111-111111111111';
    const tokenSuperadmin = firmarToken({
      sub: superadminId,
      usuario: 'superadmin1',
      rol: 'superadmin',
      tokenVersion: 1,
    });
    poolQueryMock.mockResolvedValueOnce({ rows: [{ token_version: 1 }] });
    poolQueryMock.mockResolvedValueOnce({
      rows: [{ id: adminId, rol: 'administrativo', activo: true }],
    });
    poolQueryMock.mockResolvedValueOnce({ rows: [{ id: adminId, activo: false }] });
    poolQueryMock.mockResolvedValueOnce({ rows: [] });
    poolQueryMock.mockResolvedValueOnce({ rows: [] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .patch(`/usuarios/${adminId}/estado`)
      .set('Authorization', `Bearer ${tokenSuperadmin}`)
      .send({ activo: false });

    expect(res.status).toBe(204);
  });
});
