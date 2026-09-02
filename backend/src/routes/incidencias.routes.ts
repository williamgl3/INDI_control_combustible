import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { eliminarArchivosNuevos, limpiarArchivosAnteError, limpiarArchivosDeReplay, upload, rutaPublicaDeArchivo, verificarMagicBytes } from '../middleware/upload';
import * as incidenciasService from '../services/incidenciasService';
import { ejecutarIdempotente, leerIdempotencyKey, OPERACIONES_IDEMPOTENTES, requestIdDe } from '../services/idempotenciaService';
import { fingerprintRequest, hashesDeArchivos } from '../utils/requestFingerprint';

export const incidenciasRouter = Router();

incidenciasRouter.use(requireAuth as never);

incidenciasRouter.get(
  '/',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (_req, res) => {
    res.json(await incidenciasService.listarTodas());
  }),
);

incidenciasRouter.get(
  '/mias',
  asyncHandler(async (req: AuthRequest, res) => {
    res.json(await incidenciasService.listarDeChofer(req.usuarioActual!.sub));
  }),
);

const reportarSchema = z.object({
  vehiculoId: z.string().uuid(),
  descripcion: z.string().trim().min(1, 'Describe la falla o incidencia.'),
});

/// La foto es opcional (a diferencia de las cargas/cierres, donde sí es
/// obligatoria) — no todas las incidencias tienen algo fotografiable
/// (ej. "ruido raro en el motor"), así que no se bloquea el envío por
/// falta de foto.
incidenciasRouter.post(
  '/',
  requireRole('chofer', 'supervisor') as never,
  upload.fields([{ name: 'foto', maxCount: 1 }]),
  verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = reportarSchema.parse(req.body);
    const archivos = req.files as { foto?: Express.Multer.File[] } | undefined;
    const key = leerIdempotencyKey(req, false);
    const requestHash = fingerprintRequest({ ...datos, actorId: req.usuarioActual!.sub,
      archivos: await hashesDeArchivos({ foto: archivos?.foto }) });
    const resultado = await ejecutarIdempotente({
      usuarioId: req.usuarioActual!.sub, operacion: OPERACIONES_IDEMPOTENTES.reportarIncidencia,
      idempotencyKey: key, requestHash,
      requestId: requestIdDe(req),
      ejecutar: async (cliente) => {
        const incidencia = await incidenciasService.reportar({ choferId: req.usuarioActual!.sub,
          ...datos, fotoPath: archivos?.foto?.[0] ? rutaPublicaDeArchivo(archivos.foto[0].filename) : null }, cliente);
        return { status: 201, body: incidencia, resourceType: 'incidencia_vehiculo', resourceId: incidencia.id };
      },
    });
    await limpiarArchivosDeReplay(req, resultado.replayed);
    if (resultado.replayed) res.set('Idempotency-Replayed', 'true');
    res.status(resultado.status).json(resultado.body);
  }),
);
incidenciasRouter.use(limpiarArchivosAnteError);

const resolverSchema = z.object({
  comentario: z.string().trim().nullish(),
});

incidenciasRouter.patch(
  '/:id/resolver',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const { comentario } = resolverSchema.parse(req.body);
    const incidencia = await incidenciasService.resolver(req.params.id as string, {
      resueltaPor: req.usuarioActual!.usuario,
      resueltaPorId: req.usuarioActual!.sub,
      comentario,
    });
    res.json(incidencia);
  }),
);
