import { describe, it, expect, vi, beforeEach } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

import { pool } from '../src/db/pool';
import { crearAppDePrueba } from './testApp';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

// `test/setup.ts` fija AUTH_RATE_LIMIT_MAX=3 para que este test no tenga
// que mandar cientos de requests.
describe('rate limiting en /login', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
    // Cada intento falla por credenciales inválidas (usuario inexistente)
    // — lo que importa es que el límite se dispare independientemente del
    // resultado de la autenticación.
    poolQueryMock.mockResolvedValue({ rows: [] });
  });

  it('responde 429 después de superar el máximo de intentos configurado', async () => {
    const app = crearAppDePrueba();
    const maximo = Number(process.env.AUTH_RATE_LIMIT_MAX);

    let ultimaRespuesta;
    for (let i = 0; i < maximo; i++) {
      ultimaRespuesta = await request(app)
        .post('/login')
        .send({ usuario: 'no-existe', password: 'lo-que-sea' });
      expect(ultimaRespuesta.status).toBe(401);
    }

    // El siguiente intento, ya sobre el límite, debe ser rechazado por el
    // rate limiter antes de llegar siquiera a la lógica de auth.
    const bloqueado = await request(app)
      .post('/login')
      .send({ usuario: 'no-existe', password: 'lo-que-sea' });

    expect(bloqueado.status).toBe(429);
  });
});
