import express from 'express';
import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../src/db/pool', () => ({ pool: { query: vi.fn() } }));

import { pool } from '../src/db/pool';
import { errorHandler } from '../src/middleware/errorHandler';
import { suministrosRouter } from '../src/routes/suministros.routes';
import { firmarToken } from '../src/utils/jwt';

const query = pool.query as unknown as ReturnType<typeof vi.fn>;

describe('POST /suministros legado', () => {
  beforeEach(() => {
    query.mockReset();
    query.mockResolvedValue({ rows: [{ token_version: 1 }] });
  });

  it('responde 410 y no intenta crear registros', async () => {
    const app = express();
    app.use(express.json());
    app.use('/suministros', suministrosRouter);
    app.use(errorHandler);
    const token = firmarToken({
      sub: '00000000-0000-4000-8000-000000000001',
      usuario: 'supervisor-test',
      rol: 'supervisor',
      tokenVersion: 1,
    });

    const respuesta = await request(app)
      .post('/suministros')
      .set('Authorization', `Bearer ${token}`)
      .send({ litros: 100 });

    expect(respuesta.status).toBe(410);
    expect(respuesta.body.error).toContain('sustituido');
    expect(query).toHaveBeenCalledTimes(1);
    expect(String(query.mock.calls[0]?.[0])).toContain('token_version');
  });
});
