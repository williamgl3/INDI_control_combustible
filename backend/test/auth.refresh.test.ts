import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

import { pool } from '../src/db/pool';
import { crearAppDePrueba } from './testApp';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

const FILA_USUARIO = {
  id: '11111111-1111-1111-1111-111111111111',
  usuario: 'chofer1',
  password_hash: 'hash-no-relevante-para-refresh',
  nombre: 'Juan',
  apellido_paterno: 'Pérez',
  apellido_materno: null,
  correo: 'chofer1@example.com',
  fecha_nacimiento: new Date('1996-03-10'),
  rol: 'chofer',
  token_version: 1,
  activo: true,
};

describe('POST /refresh', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('rota el refresh token: revoca el usado, emite uno nuevo y devuelve un access token nuevo', async () => {
    const expiraEn = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    // 1) buscarRefreshTokenValido — encuentra el token, vigente y no revocado.
    poolQueryMock.mockResolvedValueOnce({
      rows: [{ id: 'rt-1', usuario_id: FILA_USUARIO.id, expira_en: expiraEn, revocado: false }],
    });
    // 2) revocarPorId — UPDATE, no importa el valor de retorno.
    poolQueryMock.mockResolvedValueOnce({ rows: [] });
    // 3) emitirRefreshToken — INSERT del nuevo refresh token.
    poolQueryMock.mockResolvedValueOnce({ rows: [] });
    // 4) authService.refrescarToken vuelve a leer el usuario para firmar el access token nuevo.
    poolQueryMock.mockResolvedValueOnce({ rows: [FILA_USUARIO] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .post('/refresh')
      .send({ refreshToken: 'un-refresh-token-cualquiera-de-prueba' });

    expect(res.status).toBe(200);
    expect(res.body.token).toEqual(expect.any(String));
    expect(res.body.refreshToken).toEqual(expect.any(String));
    // El UPDATE que revoca el token viejo (llamada 2) debe haberse
    // ejecutado antes de responder.
    expect(poolQueryMock).toHaveBeenCalledTimes(4);
  });

  it('responde 401 cuando el refresh token ya fue revocado', async () => {
    const expiraEn = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    poolQueryMock.mockResolvedValueOnce({
      rows: [{ id: 'rt-1', usuario_id: FILA_USUARIO.id, expira_en: expiraEn, revocado: true }],
    });

    const app = crearAppDePrueba();
    const res = await request(app)
      .post('/refresh')
      .send({ refreshToken: 'token-ya-revocado' });

    expect(res.status).toBe(401);
    expect(res.body.token).toBeUndefined();
  });

  it('responde 401 cuando el refresh token ya expiró', async () => {
    const expiraEn = new Date(Date.now() - 1000);
    poolQueryMock.mockResolvedValueOnce({
      rows: [{ id: 'rt-1', usuario_id: FILA_USUARIO.id, expira_en: expiraEn, revocado: false }],
    });

    const app = crearAppDePrueba();
    const res = await request(app)
      .post('/refresh')
      .send({ refreshToken: 'token-expirado' });

    expect(res.status).toBe(401);
    expect(res.body.token).toBeUndefined();
  });

  it('responde 401 cuando el refresh token no existe', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .post('/refresh')
      .send({ refreshToken: 'token-que-no-existe' });

    expect(res.status).toBe(401);
  });
});
