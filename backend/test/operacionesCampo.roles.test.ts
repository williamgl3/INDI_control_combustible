import express, { type NextFunction, type Request, type Response } from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({
  pool: { query: vi.fn() },
}));

vi.mock('../src/services/idempotenciaService', () => ({
  OPERACIONES_IDEMPOTENTES: {
    crearCierreDia: 'cierre_dia.crear', reportarIncidencia: 'incidencia.reportar', subirEvidencia: 'evidencia.subir',
  },
  leerIdempotencyKey: () => null,
  requestIdDe: () => 'request-test',
  ejecutarIdempotente: vi.fn(async ({ ejecutar }) => ({ ...(await ejecutar({})), replayed: false })),
}));

vi.mock('../src/utils/requestFingerprint', () => ({
  fingerprintRequest: () => 'a'.repeat(64), hashesDeArchivos: async () => ({}),
}));

vi.mock('../src/middleware/upload', () => {
  const continuar = (req: Request, _res: Response, next: NextFunction) => next();
  return {
    upload: {
      single: () => (req: Request, _res: Response, next: NextFunction) => {
        req.file = { filename: 'tablero-prueba.jpg' } as Express.Multer.File;
        next();
      },
      fields: () => (req: Request, _res: Response, next: NextFunction) => {
        req.files = {
          fotos: [{ filename: 'evidencia-prueba.jpg' } as Express.Multer.File],
        };
        next();
      },
    },
    verificarMagicBytes: continuar,
    rutaPublicaDeArchivo: (nombre: string) => `/uploads/${nombre}`,
    eliminarArchivosNuevos: vi.fn(),
    limpiarArchivosDeReplay: vi.fn(),
    limpiarArchivosAnteError: continuar,
  };
});

vi.mock('../src/services/cargasService', () => ({
  buscarCargaPorId: vi.fn().mockResolvedValue({ kmAlCargar: 100 }),
}));

vi.mock('../src/services/cierresDiaService', () => ({
  cerrarDia: vi.fn().mockResolvedValue({ id: 'cierre-prueba' }),
  listarTodosLosCierres: vi.fn(),
  listarCierresDeChofer: vi.fn(),
  rendimientoDe: vi.fn(),
}));

vi.mock('../src/services/evidenciasService', () => ({
  validarRelacionEvidencia: vi.fn().mockResolvedValue(undefined),
  subir: vi.fn().mockResolvedValue({ id: 'evidencia-prueba' }),
  listarDeUsuario: vi.fn(),
  listarTodas: vi.fn(),
}));

vi.mock('../src/services/incidenciasService', () => ({
  reportar: vi.fn().mockResolvedValue({ id: 'incidencia-prueba' }),
  listarDeChofer: vi.fn(),
  listarTodas: vi.fn(),
  resolver: vi.fn(),
}));

import { pool } from '../src/db/pool';
import { cierresDiaRouter } from '../src/routes/cierresDia.routes';
import { evidenciasRouter } from '../src/routes/evidencias.routes';
import { incidenciasRouter } from '../src/routes/incidencias.routes';
import { errorHandler } from '../src/middleware/errorHandler';
import type { RolUsuario } from '../src/types';
import { firmarToken } from '../src/utils/jwt';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;
const usuarioId = '11111111-1111-4111-8111-111111111111';
const cargaId = '22222222-2222-4222-8222-222222222222';
const vehiculoId = '33333333-3333-4333-8333-333333333333';

function crearApp() {
  const app = express();
  app.use(express.json());
  app.use('/cierres-dia', cierresDiaRouter);
  app.use('/evidencias', evidenciasRouter);
  app.use('/incidencias', incidenciasRouter);
  app.use(errorHandler);
  return app;
}

function tokenPara(rol: RolUsuario) {
  return firmarToken({
    sub: usuarioId,
    usuario: `usuario-${rol}`,
    rol,
    tokenVersion: 1,
  });
}

async function ejecutarAccion(accion: 'cierre' | 'evidencia' | 'incidencia', rol: RolUsuario) {
  const autorizacion = `Bearer ${tokenPara(rol)}`;
  const app = crearApp();
  switch (accion) {
    case 'cierre':
      return request(app)
        .post('/cierres-dia')
        .set('Authorization', autorizacion)
        .send({ cargaId, kmFinal: 150 });
    case 'evidencia':
      return request(app)
        .post('/evidencias')
        .set('Authorization', autorizacion)
        .send({ usuario_id: usuarioId, tipo: 'tablero', km: 150 });
    case 'incidencia':
      return request(app)
        .post('/incidencias')
        .set('Authorization', autorizacion)
        .send({ vehiculoId, descripcion: 'Ruido ficticio en el motor' });
  }
}

describe.each([
  ['cierre', 201],
  ['evidencia', 201],
  ['incidencia', 201],
] as const)('autorización para %s de campo', (accion, estadoExitoso) => {
  beforeEach(() => {
    poolQueryMock.mockReset();
    poolQueryMock.mockResolvedValue({ rows: [{ token_version: 1 }] });
  });

  it.each(['chofer', 'supervisor'] as const)(
    '%s puede realizar la operación',
    async (rol) => {
      const respuesta = await ejecutarAccion(accion, rol);
      expect(respuesta.status).toBe(estadoExitoso);
    },
  );

  it.each(['administrativo', 'superadmin'] as const)(
    '%s recibe 403',
    async (rol) => {
      const respuesta = await ejecutarAccion(accion, rol);
      expect(respuesta.status).toBe(403);
    },
  );
});
