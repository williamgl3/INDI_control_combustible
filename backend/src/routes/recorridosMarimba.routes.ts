import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ApiError } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { upload, rutaPublicaDeArchivo, verificarMagicBytes } from '../middleware/upload';
import * as recorridosMarimbaService from '../services/recorridosMarimbaService';
import * as despachosMarimbaService from '../services/despachosMarimbaService';

export const recorridosMarimbaRouter = Router();

recorridosMarimbaRouter.use(requireAuth as never);

/// Panel admin: recorridos del día/rango, con filtro de "requiere
/// revisión" para el tablero de conciliación (ver PASO 4c del diseño).
recorridosMarimbaRouter.get(
  '/',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
    const query = z
      .object({
        marimbaId: z.string().uuid().optional(),
        requiereRevision: z.coerce.boolean().optional(),
      })
      .parse(req.query);
    res.json(await recorridosMarimbaService.listarRecorridos(query));
  }),
);

recorridosMarimbaRouter.get(
  '/:id',
  asyncHandler(async (req, res) => {
    const recorrido = await recorridosMarimbaService.buscarRecorridoPorId(req.params.id as string);
    if (!recorrido) throw new ApiError(404, 'Recorrido no encontrado.');
    res.json(recorrido);
  }),
);

recorridosMarimbaRouter.get(
  '/:id/despachos',
  asyncHandler(async (req, res) => {
    res.json(await despachosMarimbaService.listarDespachosDeRecorrido(req.params.id as string));
  }),
);

const crearRecorridoSchema = z.object({
  marimbaId: z.string().uuid(),
  frente: z.string().trim().min(1, 'Indica el frente o ubicación del recorrido.'),
  cargaId: z.string().uuid().nullish(),
  litrosIniciales: z.coerce.number().nonnegative(),
  kmInicio: z.coerce.number().nonnegative().nullish(),
  horasEquipoMenorInicio: z.coerce.number().nonnegative().nullish(),
});

/// Abre un recorrido (jornada de despacho) — el operador de la marimba,
/// no necesariamente el mismo rol que carga el tanque (ver
/// `cargas.routes.ts`).
recorridosMarimbaRouter.post(
  '/',
  requireRole('supervisor', 'administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = crearRecorridoSchema.parse(req.body);
    const recorrido = await recorridosMarimbaService.crearRecorrido({
      ...datos,
      operadorId: req.usuarioActual!.sub,
    });
    res.status(201).json(recorrido);
  }),
);

const agregarDespachoSchema = z.object({
  vehiculoDestinoId: z.string().uuid().nullish(),
  destinoTexto: z.string().trim().nullish(),
  operadorTexto: z.string().trim().min(1, 'Indica quién recibe el combustible.'),
  residenteTexto: z.string().trim().nullish(),
  litrosSolicitados: z.coerce.number().nonnegative().nullish(),
  litrosSuministrados: z.coerce.number().nonnegative(),
  lecturaMedidor: z.coerce.number().nonnegative().nullish(),
  estado: z.enum(['activo', 'inactivo']).optional(),
});

/// Agrega un despacho al recorrido — foto OPCIONAL (ver comentario en
/// `despachosMarimba.routes.ts`: la evidencia obligatoria de un recorrido
/// es la foto de cierre, no una por cada uno de los N despachos).
recorridosMarimbaRouter.post(
  '/:id/despachos',
  requireRole('supervisor', 'administrativo', 'superadmin') as never,
  upload.fields([{ name: 'fotoEvidencia', maxCount: 1 }]),
  verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    const recorrido = await recorridosMarimbaService.buscarRecorridoPorId(req.params.id as string);
    if (!recorrido) throw new ApiError(404, 'Recorrido no encontrado.');

    const datos = agregarDespachoSchema.parse(req.body);
    const archivos = req.files as { fotoEvidencia?: Express.Multer.File[] } | undefined;
    const foto = archivos?.fotoEvidencia?.[0];

    const despacho = await recorridosMarimbaService.agregarDespacho(recorrido.id, {
      ...datos,
      marimbaId: recorrido.marimbaId,
      registradoPor: req.usuarioActual!.sub,
      fotoEvidenciaPath: foto ? rutaPublicaDeArchivo(foto.filename) : null,
    });
    res.status(201).json(despacho);
  }),
);

const cerrarRecorridoSchema = z.object({
  kmCierre: z.coerce.number().nonnegative().nullish(),
  horasEquipoMenorCierre: z.coerce.number().nonnegative().nullish(),
});

/// Cierra el recorrido — foto de cierre OBLIGATORIA (bitácora/evidencia
/// del cierre completo de la jornada, ver PASO 3e del diseño).
recorridosMarimbaRouter.post(
  '/:id/cerrar',
  requireRole('supervisor', 'administrativo', 'superadmin') as never,
  upload.fields([{ name: 'fotoCierre', maxCount: 1 }]),
  verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = cerrarRecorridoSchema.parse(req.body);
    const archivos = req.files as { fotoCierre?: Express.Multer.File[] } | undefined;
    const foto = archivos?.fotoCierre?.[0];
    if (!foto) {
      throw new ApiError(400, 'La foto de cierre es obligatoria para cerrar el recorrido.');
    }

    const recorrido = await recorridosMarimbaService.cerrarRecorrido(
      req.params.id as string,
      { ...datos, fotoCierrePath: rutaPublicaDeArchivo(foto.filename) },
      req.usuarioActual!.sub,
    );
    res.json(recorrido);
  }),
);
