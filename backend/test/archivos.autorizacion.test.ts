import { Readable } from 'node:stream';
import express from 'express';
import jwt from 'jsonwebtoken';
import request from 'supertest';
import { beforeEach, describe, expect, it, vi } from 'vitest';

vi.mock('../src/db/pool', () => ({ pool: { query: vi.fn() } }));

const { localizarReferenciasMock, abrirMock } = vi.hoisted(() => ({
  localizarReferenciasMock: vi.fn(),
  abrirMock: vi.fn(),
}));
vi.mock('../src/services/archivosService', async (importOriginal) => {
  const original = await importOriginal<typeof import('../src/services/archivosService')>();
  return { ...original, localizarReferencias: localizarReferenciasMock };
});

vi.mock('../src/storage/almacenamientoLocalPrivado', async (importOriginal) => {
  const original = await importOriginal<typeof import('../src/storage/almacenamientoLocalPrivado')>();
  return { ...original, almacenamientoLocalPrivado: { abrir: abrirMock } };
});

import { pool } from '../src/db/pool';
import { archivosRouter } from '../src/routes/archivos.routes';
import { errorHandler } from '../src/middleware/errorHandler';
import { firmarToken } from '../src/utils/jwt';
import type { RolUsuario } from '../src/types';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;
const archivoId = '550e8400-e29b-41d4-a716-446655440000.jpg';
const propietarioId = '11111111-1111-4111-8111-111111111111';
const otroId = '22222222-2222-4222-8222-222222222222';

function crearApp() {
  const app = express();
  app.use('/archivos', archivosRouter);
  app.use(errorHandler);
  return app;
}

function token(id: string, rol: RolUsuario): string {
  return firmarToken({ sub: id, usuario: `usuario-${rol}`, rol, tokenVersion: 1 });
}

function auth(id: string, rol: RolUsuario): { Authorization: string } {
  return { Authorization: `Bearer ${token(id, rol)}` };
}

function prepararArchivo(tipo = 'evidencia', propietario: string | null = propietarioId) {
  localizarReferenciasMock.mockResolvedValue([{ tipo, propietarioId: propietario }]);
  abrirMock.mockResolvedValue({
    stream: Readable.from(Buffer.from([0xff, 0xd8, 0xff, 0xd9])),
    mimeType: 'image/jpeg',
    longitud: 4,
  });
}

describe('GET /archivos/:id — acceso privado', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
    localizarReferenciasMock.mockReset();
    abrirMock.mockReset();
    poolQueryMock.mockResolvedValue({ rows: [{ token_version: 1, activo: true }] });
  });

  it('responde 401 sin Authorization', async () => {
    expect((await request(crearApp()).get(`/archivos/${archivoId}`)).status).toBe(401);
    expect(localizarReferenciasMock).not.toHaveBeenCalled();
  });

  it('responde 401 con JWT inválido', async () => {
    const respuesta = await request(crearApp())
      .get(`/archivos/${archivoId}`)
      .set('Authorization', 'Bearer no-es-un-jwt');
    expect(respuesta.status).toBe(401);
    expect(localizarReferenciasMock).not.toHaveBeenCalled();
  });

  it('responde 401 con JWT expirado', async () => {
    const expirado = jwt.sign(
      { sub: propietarioId, usuario: 'chofer', rol: 'chofer', tokenVersion: 1 },
      process.env.JWT_SECRET!,
      { expiresIn: -1 },
    );
    const respuesta = await request(crearApp())
      .get(`/archivos/${archivoId}`)
      .set('Authorization', `Bearer ${expirado}`);
    expect(respuesta.status).toBe(401);
    expect(localizarReferenciasMock).not.toHaveBeenCalled();
  });

  it('responde 404 cuando no existe metadata', async () => {
    localizarReferenciasMock.mockResolvedValue([]);
    const respuesta = await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, 'chofer'));
    expect(respuesta.status).toBe(404);
    expect(abrirMock).not.toHaveBeenCalled();
  });

  it('responde 404 sin revelar la ruta física cuando falta el archivo', async () => {
    localizarReferenciasMock.mockResolvedValue([{ tipo: 'evidencia', propietarioId }]);
    abrirMock.mockResolvedValue(null);
    const respuesta = await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, 'chofer'));
    expect(respuesta.status).toBe(404);
    expect(respuesta.text).not.toContain('uploads');
    expect(respuesta.text).not.toMatch(/[A-Z]:\\/i);
  });

  it.each(['evidencia', 'solicitud', 'carga_ticket', 'cierre', 'incidencia'])(
    'permite al propietario leer %s',
    async (tipo) => {
      prepararArchivo(tipo);
      const respuesta = await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, 'chofer'));
      expect(respuesta.status).toBe(200);
    },
  );

  it('responde 403 a otro chofer', async () => {
    prepararArchivo();
    const respuesta = await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(otroId, 'chofer'));
    expect(respuesta.status).toBe(403);
    expect(abrirMock).not.toHaveBeenCalled();
  });

  it('un chofer no hereda permisos de recorridos aunque coincida el usuario histórico', async () => {
    prepararArchivo('recorrido_cierre');
    expect((await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, 'chofer'))).status).toBe(403);
  });

  it('permite al supervisor propietario del recorrido', async () => {
    prepararArchivo('recorrido_cierre');
    expect((await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, 'supervisor'))).status).toBe(200);
  });

  it('autoriza un despacho mediante el operador del recorrido', async () => {
    prepararArchivo('despacho_horometro');
    expect((await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, 'supervisor'))).status).toBe(200);
  });

  it('responde 403 a un supervisor diferente', async () => {
    prepararArchivo('despacho_evidencia');
    expect((await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(otroId, 'supervisor'))).status).toBe(403);
  });

  it('responde 403 al supervisor ante evidencia de un chofer no relacionado', async () => {
    prepararArchivo('evidencia');
    expect((await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(otroId, 'supervisor'))).status).toBe(403);
  });

  it.each(['administrativo', 'superadmin'] as const)('permite acceso global a %s', async (rol) => {
    prepararArchivo('recorrido_nivel', otroId);
    expect((await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, rol))).status).toBe(200);
  });

  it.each(['evidencia_foto_url', 'evidencia_foto_urls'])(
    'sirve archivo resuelto desde %s',
    async () => {
      prepararArchivo('evidencia');
      expect((await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, 'chofer'))).status).toBe(200);
    },
  );

  it('envía MIME y headers privados sin revelar rutas', async () => {
    prepararArchivo();
    const respuesta = await request(crearApp()).get(`/archivos/${archivoId}`).set(auth(propietarioId, 'chofer'));
    expect(respuesta.status).toBe(200);
    expect(respuesta.headers['content-type']).toMatch(/^image\/jpeg/);
    expect(respuesta.headers['cache-control']).toBe('private, no-store');
    expect(respuesta.headers['x-content-type-options']).toBe('nosniff');
    expect(respuesta.headers['content-disposition']).toContain('inline');
    expect(respuesta.text ?? '').not.toMatch(/[A-Z]:\\/i);
  });

  it('no expone el endpoint histórico /uploads', async () => {
    prepararArchivo();
    const respuesta = await request(crearApp()).get(`/uploads/${archivoId}`);
    expect(respuesta.status).toBe(404);
    expect(abrirMock).not.toHaveBeenCalled();
  });
});

describe('GET /archivos/:id — rechazo temprano de traversal y nombres arbitrarios', () => {
  beforeEach(() => {
    poolQueryMock.mockReset();
    localizarReferenciasMock.mockReset();
    abrirMock.mockReset();
    poolQueryMock.mockResolvedValue({ rows: [{ token_version: 1, activo: true }] });
  });

  const entradas = [
    '../archivo',
    '%2e%2e%2farchivo',
    '..%5carchivo',
    '%5c',
    'C:%5cWindows%5csystem.ini',
    'archivo.jpg',
    '550e8400-e29b-41d4-a716-446655440000.exe',
    '550e8400-e29b-41d4-a716-446655440000.jpg.extra',
    '550e8400-e29b-41d4-a716-446655440000.jpg.png',
  ];

  it.each(entradas)('rechaza %s antes del almacenamiento', async (entrada) => {
    const respuesta = await request(crearApp())
      .get(`/archivos/${entrada}`)
      .set(auth(propietarioId, 'chofer'));
    expect([400, 404]).toContain(respuesta.status);
    expect(localizarReferenciasMock).not.toHaveBeenCalled();
    expect(abrirMock).not.toHaveBeenCalled();
  });
});
