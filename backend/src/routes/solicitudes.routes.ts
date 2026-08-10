import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { ApiError } from '../utils/asyncHandler';
import { upload, rutaPublicaDeArchivo, verificarMagicBytes } from '../middleware/upload';
import * as solicitudesService from '../services/solicitudesService';
import * as preciosService from '../services/preciosService';

export const solicitudesRouter = Router();

solicitudesRouter.use(requireAuth as never);

const fechaIsoSchema = z
  .string()
  .refine((v) => !Number.isNaN(new Date(v).getTime()), 'Debe ser una fecha ISO válida.');

/// `estado`/`desde`/`hasta`/`limit`/`before` son todos opcionales — sin
/// ninguno, el comportamiento es idéntico al de antes (todas las
/// solicitudes, sin límite). Ver `solicitudesService.listarTodasLasSolicitudes`.
const listarSolicitudesQuerySchema = z.object({
  estado: z.enum(['pendiente', 'aprobada', 'rechazada']).optional(),
  desde: fechaIsoSchema.optional(),
  hasta: fechaIsoSchema.optional(),
  limit: z.coerce.number().int().positive().max(200).optional(),
  before: fechaIsoSchema.optional(),
});

solicitudesRouter.get(
  '/',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
    const filtros = listarSolicitudesQuerySchema.parse(req.query);
    res.json(await solicitudesService.listarTodasLasSolicitudes(filtros));
  }),
);

solicitudesRouter.get(
  '/mias',
  asyncHandler(async (req: AuthRequest, res) => {
    res.json(await solicitudesService.listarSolicitudesDeChofer(req.usuarioActual!.sub));
  }),
);

/// Resumen de presupuesto semanal — usado por Autorizaciones/Finanzas en
/// el panel admin (`BarraPresupuesto`).
solicitudesRouter.get(
  '/resumen-presupuesto',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (_req, res) => {
    const [total, ejercido, restante] = await Promise.all([
      preciosService.presupuestoSemanalTotal(),
      solicitudesService.presupuestoEjercido(),
      solicitudesService.presupuestoRestante(),
    ]);
    res.json({ presupuestoSemanalTotal: total, presupuestoEjercido: ejercido, presupuestoRestante: restante });
  }),
);

/// Litros ya autorizados (aprobados) de ESE vehículo en la semana actual
/// — usado por `ChoferHomeScreen` para la barra de tope semanal. No se
/// puede calcular en el cliente porque un chofer solo ve sus propias
/// solicitudes (`/mias`), y el tope es del vehículo, no del chofer.
solicitudesRouter.get(
  '/vehiculo/:vehiculoId/acumulado-semana',
  asyncHandler(async (req, res) => {
    const litros = await solicitudesService.litrosAutorizadosAcumulados(req.params.vehiculoId as string);
    res.json({ litros });
  }),
);

solicitudesRouter.get(
  '/folio/:folio',
  asyncHandler(async (req, res) => {
    const solicitud = await solicitudesService.buscarSolicitudPorFolio(req.params.folio as string);
    if (!solicitud) throw new ApiError(404, 'Solicitud no encontrada.');
    res.json(solicitud);
  }),
);

// Llega como `multipart/form-data` (por la foto del tablero), así que
// todos los campos —incluidos número y booleano— llegan como string; se
// coaccionan aquí en vez de asumir JSON.
const enviarSolicitudSchema = z.object({
  vehiculoId: z.string().uuid(),
  litrosSolicitados: z.coerce.number().positive(),
  // z.coerce.boolean() NO sirve aquí: `Boolean("false")` es `true` en JS.
  // El campo llega como string literal `"true"`/`"false"` (multipart).
  esUrgente: z
    .union([z.boolean(), z.enum(['true', 'false'])])
    .optional()
    .default(false)
    .transform((v) => v === true || v === 'true'),
  motivoChofer: z.string().trim().nullish(),
  actividad: z.string().trim().min(1, 'Describe la actividad para la que se necesita el combustible.'),
  fechaProgramada: z
    .string()
    .refine((v) => !Number.isNaN(new Date(v).getTime()), 'Ingresa una fecha y hora válidas.'),
});

/// Recibe la foto del tablero (km/horómetro actual) como
/// `multipart/form-data`, campo `fotoTablero` — mismo respaldo visual que
/// ya se manda por WhatsApp en el proceso real, ahora también al PEDIR
/// combustible (antes solo se pedía al comprobar la carga).
solicitudesRouter.post(
  '/',
  requireRole('chofer', 'supervisor') as never,
  upload.fields([{ name: 'fotoTablero', maxCount: 1 }]),
  verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = enviarSolicitudSchema.parse(req.body);
    const archivos = req.files as { fotoTablero?: Express.Multer.File[] } | undefined;
    const solicitud = await solicitudesService.enviarSolicitud({
      choferId: req.usuarioActual!.sub,
      rol: req.usuarioActual!.rol,
      ...datos,
      fotoTableroPath: archivos?.fotoTablero?.[0]
        ? rutaPublicaDeArchivo(archivos.fotoTablero[0].filename)
        : null,
    });
    res.status(201).json(solicitud);
  }),
);

const resolverSolicitudSchema = z.object({
  aprobar: z.boolean(),
  litrosAutorizados: z.number().positive().nullish(),
  motivo: z.string().trim().nullish(),
});

solicitudesRouter.patch(
  '/:id/resolver',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = resolverSolicitudSchema.parse(req.body);
    const solicitud = await solicitudesService.resolverSolicitud(req.params.id as string, {
      ...datos,
      resueltaPor: req.usuarioActual!.usuario,
      resueltaPorId: req.usuarioActual!.sub,
    });
    res.json(solicitud);
  }),
);

/// El chofer cancela su PROPIA solicitud mientras siga pendiente — ver
/// `solicitudesService.cancelarSolicitud` (por qué no es un endpoint de
/// administrativo ni un estado nuevo).
solicitudesRouter.patch(
  '/:id/cancelar',
  requireRole('chofer', 'supervisor') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const solicitud = await solicitudesService.cancelarSolicitud(
      req.params.id as string,
      req.usuarioActual!.sub,
    );
    res.json(solicitud);
  }),
);
