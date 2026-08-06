import { describe, it, expect, vi, beforeEach } from 'vitest';
import bcrypt from 'bcrypt';
import request from 'supertest';

// El pool se mockea ANTES de importar la app — `requireAuth`/los
// servicios importan `pool` desde aquí, así que interceptar este módulo
// basta para no necesitar Postgres real en los tests.
vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

import { pool } from '../src/db/pool';
import { crearAppDePrueba } from './testApp';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;

const FILA_USUARIO = {
  id: '11111111-1111-1111-1111-111111111111',
  usuario: 'chofer1',
  // Costo bajo (4) solo para que los tests corran rápido — bcrypt.compare
  // funciona igual sin importar el costo con el que se generó el hash.
  password_hash: bcrypt.hashSync('password123', 4),
  nombre: 'Juan',
  apellido_paterno: 'Pérez',
  apellido_materno: null,
  correo: 'chofer1@example.com',
  fecha_nacimiento: new Date('1996-03-10'),
  rol: 'chofer',
  token_version: 1,
  activo: true,
};

describe('POST /login', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
  });

  it('responde 200 con perfil y token cuando las credenciales son correctas', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [FILA_USUARIO] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .post('/login')
      .send({ usuario: 'chofer1', password: 'password123' });

    expect(res.status).toBe(200);
    expect(res.body.token).toEqual(expect.any(String));
    expect(res.body.perfil.usuario).toBe('chofer1');
  });

  it('responde 401 cuando el usuario no existe', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .post('/login')
      .send({ usuario: 'no-existe', password: 'lo-que-sea' });

    expect(res.status).toBe(401);
    expect(res.body.token).toBeUndefined();
  });

  it('responde 401 cuando la contraseña es incorrecta', async () => {
    poolQueryMock.mockResolvedValueOnce({ rows: [FILA_USUARIO] });

    const app = crearAppDePrueba();
    const res = await request(app)
      .post('/login')
      .send({ usuario: 'chofer1', password: 'password-equivocado' });

    expect(res.status).toBe(401);
  });
});
