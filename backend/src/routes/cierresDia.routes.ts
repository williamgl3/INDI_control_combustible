import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { ApiError } from '../utils/asyncHandler';
import { upload, rutaPublicaDeArchivo, verificarMagicBytes } from '../middleware/upload';
import * as cierresDiaService from '../services/cierresDiaService';
import * as cargasService from '../services/cargasService';
import { ejecutarIdempotente, leerIdempotencyKey, OPERACIONES_IDEMPOTENTES, requestIdDe } from '../services/idempotenciaService';
import { fingerprintRequest, hashesDeArchivos } from '../utils/requestFingerprint';
import { eliminarArchivosNuevos, limpiarArchivosAnteError, limpiarArchivosDeReplay } from '../middleware/upload';

export const cierresDiaRouter = Router();

cierresDiaRouter.use(requireAuth as never);

cierresDiaRouter.get(
  '/',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (_req, res) => {
    res.json(await cierresDiaService.listarTodosLosCierres());
  }),
);

cierresDiaRouter.get(
  '/mias',
  asyncHandler(async (req: AuthRequest, res) => {
    res.json(await cierresDiaService.listarCierresDeChofer(req.usuarioActual!.sub));
  }),
);

cierresDiaRouter.get(
  '/:cierreId/rendimiento',
  asyncHandler(async (req, res) => {
    const cierres = await cierresDiaService.listarCierresDeChofer(
      (req as AuthRequest).usuarioActual!.sub,
    );
    const cierre = cierres.find((c) => c.id === req.params.cierreId);
    if (!cierre) throw new ApiError(404, 'Cierre no encontrado.');
    res.json(await cierresDiaService.rendimientoDe(cierre));
  }),
);

const cerrarDiaSchema = z.object({
  cargaId: z.string().uuid(),
  kmFinal: z.number().positive(),
});

/// Recibe la foto del tablero como `multipart/form-data`, campo
/// `fotoTablero` — igual que `CapturaFotoField` en `CerrarDiaScreen`.
cierresDiaRouter.post(
  '/',
  requireRole('chofer', 'supervisor') as never,
  upload.single('fotoTablero'),
  verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = cerrarDiaSchema.parse({
      ...req.body,
      kmFinal: Number(req.body.kmFinal),
    });

    const carga = await cargasService.buscarCargaPorId(datos.cargaId);
    if (!carga) throw new ApiError(404, 'Carga no encontrada.');
    if (datos.kmFinal <= carga.kmAlCargar) {
      throw new ApiError(
        400,
        `La lectura final debe ser mayor a la de cuando cargaste (${carga.kmAlCargar}).`,
      );
    }
    if (!req.file) {
      throw new ApiError(400, 'Falta la foto del tablero con la lectura final.');
    }
    const key = leerIdempotencyKey(req, false);
    const requestHash = fingerprintRequest({ ...datos, actorId: req.usuarioActual!.sub,
      archivos: await hashesDeArchivos({ fotoTablero: [req.file] }) });
    const resultado = await ejecutarIdempotente({
      usuarioId: req.usuarioActual!.sub, operacion: OPERACIONES_IDEMPOTENTES.crearCierreDia,
      idempotencyKey: key, requestHash,
      requestId: requestIdDe(req),
      ejecutar: async (cliente) => {
        const cierre = await cierresDiaService.cerrarDia({ choferId: req.usuarioActual!.sub,
          cargaId: datos.cargaId, kmFinal: datos.kmFinal,
          fotoTableroPath: rutaPublicaDeArchivo(req.file!.filename) }, cliente);
        return { status: 201, body: cierre, resourceType: 'cierre_dia', resourceId: cierre.id };
      },
    });
    await limpiarArchivosDeReplay(req, resultado.replayed);
    if (resultado.replayed) res.set('Idempotency-Replayed', 'true');
    res.status(resultado.status).json(resultado.body);
  }),
);
cierresDiaRouter.use(limpiarArchivosAnteError);
