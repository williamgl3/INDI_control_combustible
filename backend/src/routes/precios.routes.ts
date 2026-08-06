import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import * as preciosService from '../services/preciosService';

export const preciosRouter = Router();

preciosRouter.use(requireAuth as never);

preciosRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json(await preciosService.listarPrecios());
  }),
);

// Registrada ANTES de `/:tipoCombustible` — si no, esa ruta con parámetro
// capturaría `/presupuesto-semanal` como si fuera un tipo de combustible.
const actualizarPresupuestoSchema = z.object({
  nuevoValor: z.number().nonnegative(),
});

preciosRouter.patch(
  '/presupuesto-semanal',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const { nuevoValor } = actualizarPresupuestoSchema.parse(req.body);
    const valor = await preciosService.actualizarPresupuestoSemanalTotal(
      nuevoValor,
      req.usuarioActual!.sub,
    );
    res.json({ presupuestoSemanalTotal: valor });
  }),
);

const actualizarPrecioSchema = z.object({
  nuevoPrecio: z.number().positive(),
});

// Antes actualizaba la fila (perdía el precio anterior); ahora inserta
// un registro nuevo en el histórico — ver `preciosService.registrarPrecio`.
// Sigue siendo 200 (no 201): desde la perspectiva del cliente esto sigue
// siendo "el precio de X ahora es Y", el detalle de que internamente es
// un INSERT no le importa a quien consume el endpoint.
preciosRouter.patch(
  '/:tipoCombustible',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const { nuevoPrecio } = actualizarPrecioSchema.parse(req.body);
    res.json(
      await preciosService.registrarPrecio(
        req.params.tipoCombustible as string,
        nuevoPrecio,
        req.usuarioActual!.sub,
      ),
    );
  }),
);

preciosRouter.get(
  '/:tipoCombustible/historial',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    res.json(await preciosService.historialDe(req.params.tipoCombustible as string));
  }),
);
