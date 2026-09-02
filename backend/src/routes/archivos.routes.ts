import { Router } from 'express';
import { pipeline } from 'node:stream/promises';
import { requireAuth, type AuthRequest } from '../middleware/auth';
import { asyncHandler, ApiError } from '../utils/asyncHandler';
import { localizarReferencias, puedeLeerArchivo } from '../services/archivosService';
import { almacenamientoLocalPrivado, STORAGE_KEY_PATTERN } from '../storage/almacenamientoLocalPrivado';

export const archivosRouter = Router();

archivosRouter.use(requireAuth as never);

archivosRouter.get(
  '/:id',
  asyncHandler(async (req: AuthRequest, res) => {
    const storageKey = req.params.id;
    // Se responde 404 también para IDs mal formados: no son recursos del
    // sistema y no deben llegar al almacenamiento ni revelar su estructura.
    if (typeof storageKey !== 'string' || !STORAGE_KEY_PATTERN.test(storageKey)) {
      throw new ApiError(404, 'Archivo no encontrado.');
    }

    const referencias = await localizarReferencias(storageKey);
    if (referencias.length === 0) throw new ApiError(404, 'Archivo no encontrado.');

    const actor = req.usuarioActual!;
    if (!puedeLeerArchivo({ id: actor.sub, rol: actor.rol }, referencias)) {
      throw new ApiError(403, 'No tienes permiso para consultar este archivo.');
    }

    // Solo después de resolver metadata y autorización se toca el disco.
    const archivo = await almacenamientoLocalPrivado.abrir(storageKey);
    if (!archivo) throw new ApiError(404, 'Archivo no encontrado.');

    res.status(200);
    res.setHeader('Content-Type', archivo.mimeType);
    res.setHeader('Content-Length', archivo.longitud.toString());
    res.setHeader('Cache-Control', 'private, no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Content-Disposition', `inline; filename="${storageKey}"`);
    await pipeline(archivo.stream, res);
  }),
);

