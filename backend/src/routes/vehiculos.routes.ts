import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import * as vehiculosService from '../services/vehiculosService';
import * as cierresDiaService from '../services/cierresDiaService';

export const vehiculosRouter = Router();

vehiculosRouter.use(requireAuth as never);

vehiculosRouter.get(
  '/',
  asyncHandler(async (_req, res) => {
    res.json(await vehiculosService.listarVehiculos());
  }),
);

const crearVehiculoSchema = z.object({
  tipoUnidad: z.string().trim().min(1),
  placas: z.string().trim().nullish(),
  numeroEconomico: z.string().trim().nullish(),
  // Nullable — maquinaria pesada puede importarse sin combustible
  // confirmado con el cliente todavía (ver migración 0022).
  tipoCombustible: z.string().trim().nullish(),
  modelo: z.string().trim().nullish(),
  intervaloServicio: z.number().positive().nullish(),
  unidadPadreId: z.string().uuid().nullish(),
  ubicacion: z.string().trim().nullish(),
});

vehiculosRouter.post(
  '/',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
    const datos = crearVehiculoSchema.parse(req.body);
    res.status(201).json(await vehiculosService.crearVehiculo(datos));
  }),
);

const reportarNuevoSchema = z.object({
  tipoUnidad: z.string().trim().min(1),
  placas: z.string().trim().nullish(),
  numeroEconomico: z.string().trim().nullish(),
  tipoCombustible: z.string().trim().min(1),
  modelo: z.string().trim().min(1),
});

vehiculosRouter.post(
  '/reportar-nuevo',
  asyncHandler(async (req, res) => {
    const datos = reportarNuevoSchema.parse(req.body);
    res.status(201).json(await vehiculosService.reportarVehiculoNuevo(datos));
  }),
);

const actualizarVehiculoSchema = z.object({
  tipoUnidad: z.string().trim().min(1).optional(),
  placas: z.string().trim().nullish(),
  numeroEconomico: z.string().trim().nullish(),
  tipoCombustible: z.string().trim().nullish(),
  modelo: z.string().trim().nullish(),
  intervaloServicio: z.number().positive().optional(),
  unidadPadreId: z.string().uuid().nullish(),
  ubicacion: z.string().trim().nullish(),
});

vehiculosRouter.patch(
  '/:id',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const cambios = actualizarVehiculoSchema.parse(req.body);
    res.json(
      await vehiculosService.actualizarVehiculo(
        req.params.id as string,
        cambios,
        req.usuarioActual!.sub,
      ),
    );
  }),
);

const estadoVehiculoSchema = z.object({
  activo: z.boolean(),
});

vehiculosRouter.patch(
  '/:id/estado',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const { activo } = estadoVehiculoSchema.parse(req.body);
    res.json(
      await vehiculosService.actualizarEstadoVehiculo(
        req.params.id as string,
        activo,
        req.usuarioActual!.sub,
      ),
    );
  }),
);

const registrarServicioSchema = z.object({
  lectura: z.number().positive(),
});

vehiculosRouter.post(
  '/:id/registrar-servicio',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const { lectura } = registrarServicioSchema.parse(req.body);
    res.json(
      await vehiculosService.registrarServicio(
        req.params.id as string,
        lectura,
        new Date(),
        req.usuarioActual!.sub,
      ),
    );
  }),
);

/// Historial de lecturas del medidor (km u horómetro) — usado por el
/// módulo de Mantenimiento preventivo del panel admin.
vehiculosRouter.get(
  '/:id/historial-lecturas',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
    res.json(await cierresDiaService.historialLecturas(req.params.id as string));
  }),
);
