import express, { type NextFunction, type Request, type Response } from 'express';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import request from 'supertest';

vi.mock('../src/db/pool', () => ({ pool: { query: vi.fn() } }));

vi.mock('../src/services/idempotenciaService', () => ({
  OPERACIONES_IDEMPOTENTES: {
    abrirRecorridoMarimba: 'recorrido_marimba.abrir', crearDespachoMarimba: 'despacho_marimba.crear',
    cerrarRecorridoMarimba: 'recorrido_marimba.cerrar',
  },
  leerIdempotencyKey: () => null,
  requestIdDe: () => 'request-test',
  ejecutarIdempotente: vi.fn(async ({ ejecutar }) => ({ ...(await ejecutar({})), replayed: false })),
}));

vi.mock('../src/utils/requestFingerprint', () => ({
  fingerprintRequest: () => 'a'.repeat(64), hashesDeArchivos: async () => ({}),
}));

vi.mock('../src/middleware/upload', () => {
  const continuar = (_req: Request, _res: Response, next: NextFunction) => next();
  return {
    upload: {
      fields: () => (req: Request, _res: Response, next: NextFunction) => {
        req.files = {
          fotoHorometro: [{ filename: 'horometro.jpg' } as Express.Multer.File],
          fotoMedidor: [{ filename: 'medidor.jpg' } as Express.Multer.File],
          fotoEvidencia: [{ filename: 'despacho.jpg' } as Express.Multer.File],
          fotoCierre: [{ filename: 'cierre.jpg' } as Express.Multer.File],
          fotoNivel: [{ filename: 'nivel.jpg' } as Express.Multer.File],
        };
        next();
      },
    },
    verificarMagicBytes: continuar,
    limpiarArchivosAnteError: continuar,
    limpiarArchivosDeReplay: vi.fn(),
    eliminarArchivosNuevos: vi.fn(),
    rutaPublicaDeArchivo: (nombre: string) => `/uploads/${nombre}`,
  };
});

vi.mock('../src/services/recorridosMarimbaService', () => ({
  crearRecorrido: vi.fn().mockResolvedValue({ id: 'recorrido-prueba' }),
  buscarRecorridoPorId: vi.fn().mockResolvedValue({
    id: '11111111-1111-4111-8111-111111111111',
    marimbaId: '22222222-2222-4222-8222-222222222222',
    operadorId: '33333333-3333-4333-8333-333333333333',
  }),
  agregarDespacho: vi.fn().mockResolvedValue({ id: 'despacho-prueba' }),
  cerrarRecorrido: vi.fn().mockResolvedValue({ id: 'recorrido-prueba', estado: 'cerrado' }),
}));

vi.mock('../src/services/despachosMarimbaService', () => ({
  listarDespachosDeRecorrido: vi.fn(),
  crearDespacho: vi.fn().mockResolvedValue({ id: 'despacho-prueba' }),
}));

import { pool } from '../src/db/pool';
import { errorHandler } from '../src/middleware/errorHandler';
import { recorridosMarimbaRouter } from '../src/routes/recorridosMarimba.routes';
import type { RolUsuario } from '../src/types';
import { firmarToken } from '../src/utils/jwt';

const poolQueryMock = pool.query as unknown as ReturnType<typeof vi.fn>;
const usuarioId = '33333333-3333-4333-8333-333333333333';
const recorridoId = '11111111-1111-4111-8111-111111111111';
const marimbaId = '22222222-2222-4222-8222-222222222222';
const destinoId = '44444444-4444-4444-8444-444444444444';

function app() {
  const resultado = express();
  resultado.use(express.json());
  resultado.use('/recorridos-marimba', recorridosMarimbaRouter);
  resultado.use(errorHandler);
  return resultado;
}

function token(rol: RolUsuario) {
  return firmarToken({ sub: usuarioId, usuario: `usuario-${rol}`, rol, tokenVersion: 1 });
}

async function escribir(accion: 'abrir' | 'despachar' | 'cerrar', rol: RolUsuario) {
  const peticion = request(app());
  const autorizacion = `Bearer ${token(rol)}`;
  if (accion === 'abrir') {
    return peticion.post('/recorridos-marimba').set('Authorization', autorizacion).send({
      marimbaId,
      tipoCombustible: 'Magna',
      frente: 'Frente de prueba',
    });
  }
  if (accion === 'despachar') {
    return peticion
      .post(`/recorridos-marimba/${recorridoId}/despachos`)
      .set('Authorization', autorizacion)
      .send({
        vehiculoDestinoId: destinoId,
        operadorTexto: 'Operador ficticio',
        tipoCombustible: 'Magna',
        horometro: 120,
        medidorInicial: 100,
        medidorFinal: 120,
      });
  }
  return peticion
    .post(`/recorridos-marimba/${recorridoId}/cerrar`)
    .set('Authorization', autorizacion)
    .send({ existenciaFisica: 80 });
}

describe.each(['abrir', 'despachar', 'cerrar'] as const)('escritura de recorrido: %s', (accion) => {
  beforeEach(() => {
    poolQueryMock.mockReset();
    poolQueryMock.mockResolvedValue({ rows: [{ token_version: 1 }] });
  });

  it('permite al supervisor', async () => {
    expect((await escribir(accion, 'supervisor')).status).toBe(accion === 'cerrar' ? 200 : 201);
  });

  it.each(['chofer', 'administrativo', 'superadmin'] as const)('rechaza a %s', async (rol) => {
    expect((await escribir(accion, rol)).status).toBe(403);
  });
});
