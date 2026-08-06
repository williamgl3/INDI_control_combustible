import { describe, it, expect, vi, beforeEach } from 'vitest';
import bcrypt from 'bcrypt';
import request from 'supertest';

// El pool se mockea ANTES de importar la app.
vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

import { pool } from '../src/db/pool';
import { crearAppDePrueba } from './testApp';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

// Este test vive en su propio archivo (en vez de sumarse a
// `auth.login.test.ts`) porque `authStrictLimiter` es un singleton a
// nivel de módulo compartido por todos los tests que golpean /login
// dentro del mismo archivo — con AUTH_RATE_LIMIT_MAX=3 (ver
// `test/setup.ts`), un 4to caso en el mismo archivo dispara 429 en vez
// de probar lo que queremos. Vitest aísla módulos por archivo, así que
// aquí el contador arranca en 0.
describe('POST /login — cuenta desactivada', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('responde 401 "Esta cuenta está desactivada." si activo=false, incluso con la contraseña correcta', async () => {
    const filaDesactivada = {
      id: '11111111-1111-1111-1111-111111111111',
      usuario: 'chofer1',
      password_hash: bcrypt.hashSync('password123', 4),
      nombre: 'Juan',
      apellido_paterno: 'Pérez',
      apellido_materno: null,
      correo: 'chofer1@example.com',
      fecha_nacimiento: new Date('1996-03-10'),
      rol: 'chofer',
      token_version: 1,
      activo: false,
    };
    poolQueryMock.mockResolvedValueOnce({ rows: [filaDesactivada] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .post('/login')
      .send({ usuario: 'chofer1', password: 'password123' });

    expect(res.status).toBe(401);
    expect(res.body.error).toBe('Esta cuenta está desactivada.');
    expect(res.body.token).toBeUndefined();
  });
});
