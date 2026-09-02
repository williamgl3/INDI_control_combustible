import { describe, it, expect, vi, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

import { pool } from '../src/db/pool';
import { requireAuth, type AuthRequest } from '../src/middleware/auth';
import { errorHandler } from '../src/middleware/errorHandler';
import { firmarToken } from '../src/utils/jwt';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

function appProtegida() {
  const app = express();
  app.get('/protegida', requireAuth as never, (req: AuthRequest, res) => {
    res.json({ sub: req.usuarioActual?.sub });
  });
  app.use(errorHandler);
  return app;
}

describe('requireAuth — revocación por token_version', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('rechaza con 401 un token cuyo tokenVersion ya no coincide con el de la BD (revocado)', async () => {
    const token = firmarToken({
      sub: 'user-1',
      usuario: 'chofer1',
      rol: 'chofer',
      tokenVersion: 1, // el token quedó firmado con la versión vieja...
    });
    // ...pero en BD ya se incrementó (ej. tras un cambio de contraseña).
    poolQueryMock.mockResolvedValueOnce({ rows: [{ token_version: 2 }] });

    const res = await request(appProtegida())
      .get('/protegida')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(401);
  });

  it('acepta un token cuyo tokenVersion coincide con el de la BD', async () => {
    const token = firmarToken({
      sub: 'user-1',
      usuario: 'chofer1',
      rol: 'chofer',
      tokenVersion: 1,
    });
    poolQueryMock.mockResolvedValueOnce({ rows: [{ token_version: 1 }] });

    const res = await request(appProtegida())
      .get('/protegida')
      .set('Authorization', `Bearer ${token}`);

    expect(res.status).toBe(200);
    expect(res.body.sub).toBe('user-1');
  });

  it('rechaza con 401 si falta el header Authorization', async () => {
    const res = await request(appProtegida()).get('/protegida');
    expect(res.status).toBe(401);
  });
});
