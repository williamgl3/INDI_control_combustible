import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn(), connect: vi.fn() },
}));

vi.mock('../src/services/correoService', () => ({
  enviarRecuperacionPassword: vi.fn().mockResolvedValue(undefined),
}));

import { pool } from '../src/db/pool';
import * as authService from '../src/services/authService';
import { crearAppDePrueba } from './testApp';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;
const poolConnectMock = pool.connect as unknown as ReturnType<typeof vi.fn>;

/// TODO-SECURITY resuelto: /recuperar-password ya no debe revelar si la
/// cuenta existe. Este test verifica que la respuesta (status Y shape)
/// sea idéntica para una cuenta existente y una que no existe.
describe('POST /recuperar-password', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
    poolConnectMock.mockReset();
  });

  it('responde igual cuando la cuenta existe y cuando no existe', async () => {
    poolQueryMock.mockResolvedValueOnce({
      rows: [{ id: 'usuario-1', correo: 'u@example.com' }],
    });
    const query = vi.fn().mockResolvedValue({ rows: [] });
    poolConnectMock.mockResolvedValue({ query, release: vi.fn() });
    const app1 = crearAppDePrueba();
    const resExistente = await request(app1)
      .post('/recuperar-password')
      .send({ usuarioOCorreo: 'chofer1' });

    poolQueryMock.mockResolvedValueOnce({ rows: [] });
    const app2 = crearAppDePrueba();
    const resInexistente = await request(app2)
      .post('/recuperar-password')
      .send({ usuarioOCorreo: 'no-existe-nadie' });

    expect(resExistente.status).toBe(resInexistente.status);
    expect(resExistente.body).toEqual(resInexistente.body);
    // Y explícitamente que no sea un 404 (el comportamiento viejo).
    expect(resExistente.status).not.toBe(404);
    expect(query).toHaveBeenCalledWith('BEGIN');
    expect(query).toHaveBeenCalledWith('COMMIT');
  });

  it('revierte la invalidación si no puede insertar el token nuevo', async () => {
    poolQueryMock.mockResolvedValueOnce({
      rows: [{ id: 'usuario-1', correo: 'u@example.com' }],
    });
    const query = vi
      .fn()
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockRejectedValueOnce(new Error('insert fallido'))
      .mockResolvedValueOnce({ rows: [] });
    const release = vi.fn();
    poolConnectMock.mockResolvedValue({ query, release });

    await expect(authService.recuperarPassword('chofer1')).rejects.toThrow(
      'insert fallido',
    );

    expect(query).toHaveBeenCalledWith('ROLLBACK');
    expect(release).toHaveBeenCalledOnce();
  });

  it('consume una recuperación válida y rechaza reutilizarla', async () => {
    const query = vi
      .fn()
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [{ usuario_id: 'usuario-1' }] })
      .mockResolvedValue({ rows: [] });
    poolConnectMock.mockResolvedValue({ query, release: vi.fn() });
    poolQueryMock.mockResolvedValue({ rows: [] });

    const respuesta = await request(crearAppDePrueba())
      .post('/restablecer-password')
      .send({ token: 'a'.repeat(43), passwordNueva: 'password-nueva' });

    expect(respuesta.status).toBe(204);
    expect(query).toHaveBeenCalledWith('COMMIT');

    const queryReuso = vi
      .fn()
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] })
      .mockResolvedValueOnce({ rows: [] });
    poolConnectMock.mockResolvedValue({ query: queryReuso, release: vi.fn() });
    await expect(
      authService.restablecerPassword('a'.repeat(43), 'otra-password'),
    ).rejects.toMatchObject({ status: 400 });
    expect(queryReuso).toHaveBeenCalledWith('ROLLBACK');
  });
});
