import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ApiError } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { upload, rutaPublicaDeArchivo, verificarMagicBytes } from '../middleware/upload';
import * as despachosMarimbaService from '../services/despachosMarimbaService';

export const despachosMarimbaRouter = Router();

despachosMarimbaRouter.use(requireAuth as never);

/// Saldo actual del libro mayor de una marimba — ver
/// `despachosMarimbaService` para por qué es un saldo continuo, no por
/// carga.
despachosMarimbaRouter.get(
  '/saldo/:marimbaId',
  asyncHandler(async (req, res) => {
    const saldo = await despachosMarimbaService.saldoDeMarimba(req.params.marimbaId as string);
    res.json({ marimbaId: req.params.marimbaId, saldoActual: saldo.toNumber() });
  }),
);

despachosMarimbaRouter.get(
  '/',
  asyncHandler(async (req, res) => {
    const marimbaId = z.string().uuid().parse(req.query.marimbaId);
    res.json(await despachosMarimbaService.listarDespachosDeMarimba(marimbaId));
  }),
);

const crearDespachoSchema = z.object({
  marimbaId: z.string().uuid(),
  vehiculoDestinoId: z.string().uuid().nullish(),
  destinoTexto: z.string().trim().nullish(),
  operadorTexto: z.string().trim().min(1, 'Indica quién recibe el combustible.'),
  residenteTexto: z.string().trim().nullish(),
  // Opcional cuando viene `recorridoId` — se hereda del frente del
  // recorrido (ver `despachosMarimbaService.crearDespacho`).
  sitio: z.string().trim().min(1).nullish(),
  litrosSolicitados: z.coerce.number().nonnegative().nullish(),
  litrosSuministrados: z.coerce.number().nonnegative(),
  lecturaMedidor: z.coerce.number().nonnegative().nullish(),
  estado: z.enum(['activo', 'inactivo']).optional(),
  recorridoId: z.string().uuid().nullish(),
});

/// `supervisor` (o admin, por si hace falta corregir desde oficina)
/// registra un despacho de la marimba hacia una unidad de maquinaria.
/// Foto obligatoria SOLO para un despacho suelto (sin `recorridoId`) —
/// mismo mecanismo antifraude que ya usa el resto de la app
/// (ticket/tablero). Dentro de un recorrido, la evidencia obligatoria es
/// la foto de cierre del recorrido completo (pedir foto por cada uno de
/// los N despachos de una jornada es inviable en campo).
despachosMarimbaRouter.post(
  '/',
  requireRole('supervisor', 'administrativo', 'superadmin') as never,
  upload.fields([{ name: 'fotoEvidencia', maxCount: 1 }]),
  verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = crearDespachoSchema.parse(req.body);
    const archivos = req.files as { fotoEvidencia?: Express.Multer.File[] } | undefined;
    const foto = archivos?.fotoEvidencia?.[0];
    if (!foto && datos.litrosSuministrados > 0 && !datos.recorridoId) {
      throw new ApiError(400, 'La foto de evidencia es obligatoria para registrar un despacho.');
    }

    const despacho = await despachosMarimbaService.crearDespacho({
      ...datos,
      registradoPor: req.usuarioActual!.sub,
      fotoEvidenciaPath: foto ? rutaPublicaDeArchivo(foto.filename) : null,
    });
    res.status(201).json(despacho);
  }),
);
