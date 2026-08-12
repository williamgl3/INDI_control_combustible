import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { ApiError } from '../utils/asyncHandler';
import {
  limpiarArchivosAnteError,
  upload,
  rutaPublicaDeArchivo,
  verificarMagicBytes,
} from '../middleware/upload';
import * as cargasService from '../services/cargasService';
import * as solicitudesService from '../services/solicitudesService';
import * as marimbaPartidasService from '../services/marimbaPartidasService';

export const cargasRouter = Router();

cargasRouter.use(requireAuth as never);

const fechaIsoSchema = z
  .string()
  .refine((v) => !Number.isNaN(new Date(v).getTime()), 'Debe ser una fecha ISO válida.');

/// Todos opcionales — sin ninguno, el comportamiento es idéntico al de
/// antes (todas las cargas, sin límite). Ver
/// `cargasService.listarTodasLasCargas`.
const listarCargasQuerySchema = z.object({
  choferId: z.string().uuid().optional(),
  vehiculoId: z.string().uuid().optional(),
  desde: fechaIsoSchema.optional(),
  hasta: fechaIsoSchema.optional(),
  limit: z.coerce.number().int().positive().max(200).optional(),
  before: fechaIsoSchema.optional(),
});

cargasRouter.get(
  '/',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
    const filtros = listarCargasQuerySchema.parse(req.query);
    res.json(await cargasService.listarTodasLasCargas(filtros));
  }),
);

cargasRouter.get(
  '/mias',
  asyncHandler(async (req: AuthRequest, res) => {
    res.json(await cargasService.listarCargasDeChofer(req.usuarioActual!.sub));
  }),
);

cargasRouter.get(
  '/abierta-hoy',
  asyncHandler(async (req: AuthRequest, res) => {
    const carga = await cargasService.cargaAbiertaDeHoy(req.usuarioActual!.sub);
    res.json(carga);
  }),
);

const registrarCargaSchema = z.object({
  vehiculoId: z.string().uuid(),
  folioAutorizacion: z.string().trim().min(1),
  // Carga a granel de la marimba: N folios de una sola visita a la estación
  // (ver migración 0015). Vacío para el flujo normal de chofer individual.
  foliosAdicionales: z.array(z.string().trim().min(1)).optional(),
  litrosCargados: z.number().positive().optional(),
  partidas: z.array(z.object({
    tipo: z.enum(['consumo_propio', 'carga_granel']),
    litros: z.number().positive(),
    tipoCombustible: z.enum(['Diésel', 'Magna', 'Premium']),
  })).min(1).max(2).optional(),
  comprobantes: z.array(z.object({
    folioEstacion: z.string().trim().min(1).max(100),
    concepto: z.enum(['consumo_propio', 'carga_granel', 'visita_completa']),
    litrosIndicados: z.number().positive().nullish(),
    fotoPath: z.string().trim().nullish(),
    fecha: z.string().datetime().nullish(),
  })).max(20).optional().default([]),
  kmAlCargar: z.number().positive(),
  gasolinera: z.string().trim().min(1),
  litrosDetectadosOcr: z.coerce.number().nullish(),
  recorridoId: z.string().uuid().nullish(),
});

/// Recibe las 2 fotos (ticket + tablero) como `multipart/form-data`, campos
/// `fotoTicket` y `fotoTablero` — igual que `CapturaFotoField` x2 en
/// `ComprobarCargaScreen`. `supervisor` la usa igual que `chofer` para
/// registrar la carga a granel de su marimba (mismo flujo, sin pantalla
/// nueva — ver `despachosMarimbaService` para lo que sí es nuevo).
cargasRouter.post(
  '/',
  requireRole('chofer', 'supervisor') as never,
  upload.fields([
    { name: 'fotoTicket', maxCount: 1 },
    { name: 'fotoTablero', maxCount: 1 },
  ]),
  verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    // `foliosAdicionales` viaja como multipart/form-data — si el cliente
    // lo manda, llega como string JSON (ej. '["215521","215522"]'), no
    // como array real (multer no parsea JSON anidado en campos de texto).
    const foliosAdicionalesRaw = req.body.foliosAdicionales;
    const partidasRaw = req.body.partidas;
    const comprobantesRaw = req.body.comprobantes;
    const datos = registrarCargaSchema.parse({
      ...req.body,
      litrosCargados: req.body.litrosCargados == null ? undefined : Number(req.body.litrosCargados),
      kmAlCargar: Number(req.body.kmAlCargar),
      foliosAdicionales:
        typeof foliosAdicionalesRaw === 'string'
          ? (JSON.parse(foliosAdicionalesRaw) as unknown)
          : foliosAdicionalesRaw,
      partidas: typeof partidasRaw === 'string' ? JSON.parse(partidasRaw) : partidasRaw,
      comprobantes: typeof comprobantesRaw === 'string' ? JSON.parse(comprobantesRaw) : comprobantesRaw,
    });

    if (!datos.partidas && datos.litrosCargados === undefined) {
      throw new ApiError(400, 'Indica los litros cargados o el desglose por partidas.');
    }

    const solicitud = await solicitudesService.buscarSolicitudPorFolio(datos.folioAutorizacion);
    if (!solicitud || solicitud.estado !== 'aprobada') {
      throw new ApiError(400, 'El folio de autorización no es válido.');
    }

    const archivos = req.files as
      | { fotoTicket?: Express.Multer.File[]; fotoTablero?: Express.Multer.File[] }
      | undefined;

    const fotoTicketPath = archivos?.fotoTicket?.[0]
      ? rutaPublicaDeArchivo(archivos.fotoTicket[0].filename) : null;
    const fotoTableroPath = archivos?.fotoTablero?.[0]
      ? rutaPublicaDeArchivo(archivos.fotoTablero[0].filename) : null;
    if (datos.partidas) {
      if (datos.foliosAdicionales?.length) {
        throw new ApiError(400, 'Usa comprobantes de estaciÃ³n para una carga por partidas.');
      }
      const resultado = await marimbaPartidasService.registrarCargaConPartidas({
        usuarioId: req.usuarioActual!.sub,
        vehiculoId: datos.vehiculoId,
        folioAutorizacion: datos.folioAutorizacion,
        partidas: datos.partidas,
        comprobantes: datos.comprobantes,
        kmAlCargar: datos.kmAlCargar,
        gasolinera: datos.gasolinera,
        recorridoId: datos.recorridoId,
        fotoTicketPath,
        fotoTableroPath,
        litrosDetectadosOcr: datos.litrosDetectadosOcr,
      });
      res.status(201).json(resultado);
      return;
    }
    const carga = await cargasService.registrarCarga({
      choferId: req.usuarioActual!.sub,
      vehiculoId: datos.vehiculoId,
      folioAutorizacion: datos.folioAutorizacion,
      foliosAdicionales: datos.foliosAdicionales,
      litrosCargados: datos.litrosCargados!,
      kmAlCargar: datos.kmAlCargar,
      gasolinera: datos.gasolinera,
      litrosDetectadosOcr: datos.litrosDetectadosOcr,
      fotoTicketPath,
      fotoTableroPath,
    });
    res.status(201).json(carga);
  }),
);

const editarCargaSchema = z.object({
  litrosCargados: z.number().positive().optional(),
  kmAlCargar: z.number().positive().optional(),
});

/// Corrección administrativa de una carga ya registrada (ej. edición
/// inline en el Concentrado) — ver `cargasService.editarCarga`.
cargasRouter.patch(
  '/:id',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = editarCargaSchema.parse(req.body);
    const carga = await cargasService.editarCarga(
      req.params.id as string,
      datos,
      req.usuarioActual!.sub,
    );
    res.json(carga);
  }),
);

cargasRouter.use(limpiarArchivosAnteError);
