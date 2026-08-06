import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

import { pool } from '../src/db/pool';
import { crearAppDePrueba } from './testApp';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

/// TODO-SECURITY resuelto: /recuperar-password ya no debe revelar si la
/// cuenta existe. Este test verifica que la respuesta (status Y shape)
/// sea idéntica para una cuenta existente y una que no existe.
describe('POST /recuperar-password', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('responde igual cuando la cuenta existe y cuando no existe', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [{ '?column?': 1 }] });
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
  });
});
