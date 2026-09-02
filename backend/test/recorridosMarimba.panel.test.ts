import express from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({ pool: { query: vi.fn() } }));
vi.mock('../src/services/recorridosMarimbaService', () => ({
  resumenUnidadesAdministrativo: vi.fn().mockResolvedValue([
    { id: 'unidad', saldoMagna: '0', saldoDiesel: null, recorridoAbiertoId: null },
  ]),
  listarRecorridosAdministrativo: vi.fn().mockResolvedValue({
    items: [], page: 1, limit: 25, total: 0, totalPages: 0,
  }),
}));
vi.mock('../src/services/despachosMarimbaService', () => ({
  listarDespachosDeRecorrido: vi.fn(),
}));
vi.mock('../src/middleware/upload', () => ({
  upload: { fields: () => (_req: unknown, _res: unknown, next: () => void) => next() },
  verificarMagicBytes: (_req: unknown, _res: unknown, next: () => void) => next(),
  limpiarArchivosAnteError: (_req: unknown, _res: unknown, next: () => void) => next(),
  rutaPublicaDeArchivo: (nombre: string) => nombre,
}));

import { pool } from '../src/db/pool';
import { errorHandler } from '../src/middleware/errorHandler';
import { recorridosMarimbaRouter } from '../src/routes/recorridosMarimba.routes';
import * as servicio from '../src/services/recorridosMarimbaService';
import type { RolUsuario } from '../src/types';
import { firmarToken } from '../src/utils/jwt';

const query = pool.query as unknown as ReturnType<typeof vi.fn>;
const listar = servicio.listarRecorridosAdministrativo as unknown as ReturnType<typeof vi.fn>;
const usuarioId = '33333333-3333-4333-8333-333333333333';

function aplicacion() {
  const app = express();
  app.use(express.json());
  app.use('/recorridos-marimba', recorridosMarimbaRouter);
  app.use(errorHandler);
  return app;
}

function autorizacion(rol: RolUsuario) {
  const jwt = firmarToken({ sub: usuarioId, usuario: rol, rol, tokenVersion: 1 });
  return `Bearer ${jwt}`;
}

describe('lecturas administrativas de Marimba/Pipa', () => {
  beforeEach(() => {
    query.mockReset();
    query.mockResolvedValue({ rows: [{ token_version: 1 }] });
    listar.mockClear();
  });

  it.each(['administrativo', 'superadmin'] as const)('permite el resumen y el historial a %s', async (rol) => {
    const app = aplicacion();
    expect((await request(app).get('/recorridos-marimba/panel/unidades').set('Authorization', autorizacion(rol))).status).toBe(200);
    expect((await request(app).get('/recorridos-marimba/panel/recorridos').set('Authorization', autorizacion(rol))).status).toBe(200);
  });

  it.each(['chofer', 'supervisor'] as const)('rechaza las lecturas a %s', async (rol) => {
    const app = aplicacion();
    expect((await request(app).get('/recorridos-marimba/panel/unidades').set('Authorization', autorizacion(rol))).status).toBe(403);
    expect((await request(app).get('/recorridos-marimba/panel/recorridos').set('Authorization', autorizacion(rol))).status).toBe(403);
  });

  it('valida filtros y aplica paginación', async () => {
    const respuesta = await request(aplicacion()).get('/recorridos-marimba/panel/recorridos?categoria=Pipa&estado=cerrado&page=2&limit=20').set('Authorization', autorizacion('administrativo'));
    expect(respuesta.status).toBe(200);
    expect(listar).toHaveBeenCalledWith(expect.objectContaining({ categoria: 'Pipa', estado: 'cerrado', page: 2, limit: 20 }));
  });

  it.each(['?limit=101', '?page=0', '?requiereRevision=quizá', '?fechaDesde=2026-02-02&fechaHasta=2026-01-01'])('rechaza parámetros inválidos %s', async (consulta) => {
    const respuesta = await request(aplicacion()).get(`/recorridos-marimba/panel/recorridos${consulta}`).set('Authorization', autorizacion('administrativo'));
    expect(respuesta.status).toBe(400);
  });

  it('conserva cero real separado de la ausencia de saldo', async () => {
    const respuesta = await request(aplicacion()).get('/recorridos-marimba/panel/unidades').set('Authorization', autorizacion('administrativo'));
    expect(respuesta.body[0]).toMatchObject({ saldoMagna: '0', saldoDiesel: null });
  });
});
