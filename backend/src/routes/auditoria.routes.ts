import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole } from '../middleware/auth';
import * as auditoriaService from '../services/auditoriaService';

export const auditoriaRouter = Router();

auditoriaRouter.use(requireAuth as never);
auditoriaRouter.use(requireRole('administrativo', 'superadmin') as never);

const LIMIT_DEFAULT = 50;
const LIMIT_MAX = 200;

const listarQuerySchema = z.object({
  limit: z.coerce.number().int().positive().max(LIMIT_MAX).optional().default(LIMIT_DEFAULT),
  before: z
    .string()
    .refine((v) => !Number.isNaN(new Date(v).getTime()), 'El cursor "before" debe ser una fecha ISO válida.')
    .optional(),
});

/// Historial de acciones administrativas sensibles — paginado hacia
/// atrás por cursor (`before`, timestamp ISO de la última fila recibida)
/// en vez de offset, para no correrse cuando se insertan filas nuevas
/// mientras se pagina (ver `auditoriaService.listarAuditoria`).
auditoriaRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const { limit, before } = listarQuerySchema.parse(req.query);
    const registros = await auditoriaService.listarAuditoria({ limit, before });
    res.json({ registros });
  }),
);
