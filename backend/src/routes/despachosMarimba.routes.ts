import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ApiError } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { limpiarArchivosAnteError, upload, rutaPublicaDeArchivo, verificarMagicBytes } from '../middleware/upload';
import * as despachosService from '../services/despachosMarimbaService';
import * as recorridosService from '../services/recorridosMarimbaService';

export const despachosMarimbaRouter = Router();
despachosMarimbaRouter.use(requireAuth as never);

despachosMarimbaRouter.get('/saldo/:marimbaId', requireRole('supervisor', 'administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
  const combustible = z.enum(['Diésel', 'Magna', 'Premium']).parse(req.query.tipoCombustible);
  const saldo = await despachosService.saldoDeMarimba(req.params.marimbaId as string, combustible);
  res.json({ marimbaId: req.params.marimbaId, tipoCombustible: combustible, saldoActual: saldo.toFixed(2) });
}));
despachosMarimbaRouter.get('/', requireRole('supervisor', 'administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
  const id = z.string().uuid().parse(req.query.marimbaId);
  res.json(await despachosService.listarDespachosDeMarimba(id));
}));

const schema = z.object({
  marimbaId: z.string().uuid(), recorridoId: z.string().uuid(),
  tipoCombustible: z.enum(['Diésel', 'Magna', 'Premium']),
  vehiculoDestinoId: z.string().uuid(), operadorTexto: z.string().trim().min(1).max(150),
  litrosSuministrados: z.coerce.number().positive().nullish(),
  horometro: z.coerce.number().nonnegative(), medidorInicial: z.coerce.number().nonnegative().nullish(),
  medidorFinal: z.coerce.number().nonnegative().nullish(), ubicacion: z.string().trim().max(150).nullish(),
  observaciones: z.string().trim().max(500).nullish(),
});

despachosMarimbaRouter.post('/', requireRole('supervisor', 'administrativo', 'superadmin') as never,
  upload.fields([{ name: 'fotoHorometro', maxCount: 1 }, { name: 'fotoMedidor', maxCount: 1 },
    { name: 'fotoEvidencia', maxCount: 1 }]), verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = schema.parse(req.body);
    const recorrido = await recorridosService.buscarRecorridoPorId(datos.recorridoId);
    if (!recorrido) throw new ApiError(404, 'El recorrido no está disponible.');
    const archivos = req.files as Record<string, Express.Multer.File[]> | undefined;
    const fotoHorometro = archivos?.fotoHorometro?.[0];
    if (!fotoHorometro) throw new ApiError(400, 'La foto del horómetro es obligatoria.');
    const fotoMedidor = archivos?.fotoMedidor?.[0];
    const fotoEvidencia = archivos?.fotoEvidencia?.[0];
    const despacho = await despachosService.crearDespacho({
      ...datos, responsableId: recorrido.operadorId, registradoPor: req.usuarioActual!.sub,
      actorRol: req.usuarioActual!.rol,
      fotoHorometroPath: rutaPublicaDeArchivo(fotoHorometro.filename),
      fotoMedidorPath: fotoMedidor ? rutaPublicaDeArchivo(fotoMedidor.filename) : null,
      fotoEvidenciaPath: fotoEvidencia ? rutaPublicaDeArchivo(fotoEvidencia.filename) : null,
    });
    res.status(201).json(despacho);
  }));

despachosMarimbaRouter.use(limpiarArchivosAnteError);
