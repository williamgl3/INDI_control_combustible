import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, type AuthRequest } from '../middleware/auth';
import * as suministrosService from '../services/suministrosService';

export const suministrosRouter = Router();

suministrosRouter.use(requireAuth as never);

const crearSuministroSchema = z.object({
  gasolinera: z.string().trim().min(1, 'Indica la gasolinera o punto de despacho.'),
  litros: z.number().positive('Los litros deben ser mayores a 0.'),
  fotoTicketPath: z.string().nullish(),
  pipaId: z.string().uuid().nullish(),
  pipaNombre: z.string().trim().nullish(),
  pipaModelo: z.string().trim().nullish(),
  pipaNumeroEconomico: z.string().trim().nullish(),
});

suministrosRouter.post(
  '/',
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = crearSuministroSchema.parse(req.body);
    const suministro = await suministrosService.crearSuministro({
      choferId: req.usuarioActual!.sub,
      ...datos,
    });
    res.status(201).json(suministro);
  }),
);
