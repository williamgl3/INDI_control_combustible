import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler, ApiError } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import {
  limpiarArchivosAnteError,
  eliminarArchivosNuevos,
  upload,
  rutaPublicaDeArchivo,
  verificarMagicBytes,
} from '../middleware/upload';
import * as solicitudesService from '../services/solicitudesService';
import * as preciosService from '../services/preciosService';
import * as marimbaPartidasService from '../services/marimbaPartidasService';
import { fingerprintSolicitud, sha256Archivo } from '../utils/idempotenciaSolicitud';
import { ejecutarIdempotente, leerIdempotencyKey, OPERACIONES_IDEMPOTENTES, requestIdDe } from '../services/idempotenciaService';

export const solicitudesRouter = Router();
solicitudesRouter.use(requireAuth as never);

const fechaIsoSchema = z.string().refine(
  (valor) => !Number.isNaN(new Date(valor).getTime()),
  'Debe ser una fecha ISO válida.',
);

const listarSolicitudesQuerySchema = z.object({
  estado: z.enum(['pendiente', 'aprobada', 'rechazada']).optional(),
  desde: fechaIsoSchema.optional(),
  hasta: fechaIsoSchema.optional(),
  limit: z.coerce.number().int().positive().max(200).optional(),
  before: fechaIsoSchema.optional(),
});

solicitudesRouter.get('/', requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
    res.json(await solicitudesService.listarTodasLasSolicitudes(listarSolicitudesQuerySchema.parse(req.query)));
  }));

solicitudesRouter.get('/mias', asyncHandler(async (req: AuthRequest, res) => {
  res.json(await solicitudesService.listarSolicitudesDeChofer(req.usuarioActual!.sub));
}));

solicitudesRouter.get('/resumen-presupuesto', requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (_req, res) => {
    const [total, ejercido, restante] = await Promise.all([
      preciosService.presupuestoSemanalTotal(),
      solicitudesService.presupuestoEjercido(),
      solicitudesService.presupuestoRestante(),
    ]);
    res.json({ presupuestoSemanalTotal: total, presupuestoEjercido: ejercido, presupuestoRestante: restante });
  }));

solicitudesRouter.get('/vehiculo/:vehiculoId/acumulado-semana', asyncHandler(async (req, res) => {
  res.json({ litros: await solicitudesService.litrosAutorizadosAcumulados(req.params.vehiculoId as string) });
}));

solicitudesRouter.get('/folio/:folio', asyncHandler(async (req, res) => {
  const solicitud = await solicitudesService.buscarSolicitudPorFolio(req.params.folio as string);
  if (!solicitud) throw new ApiError(404, 'Solicitud no encontrada.');
  solicitud.partidas = await marimbaPartidasService.listarPartidas(solicitud.id).catch(() => []);
  res.json(solicitud);
}));

const partidaSolicitudSchema = z.object({
  tipo: z.enum(['consumo_propio', 'carga_granel']),
  litros: z.number().positive(),
  tipoCombustible: z.enum(['Diésel', 'Magna', 'Premium']),
  observaciones: z.string().trim().max(500).nullish(),
});

const enviarSolicitudSchema = z.object({
  vehiculoId: z.string().uuid(),
  litrosSolicitados: z.coerce.number().positive().optional(),
  partidas: z.array(partidaSolicitudSchema).min(1).max(2).optional(),
  esUrgente: z.union([z.boolean(), z.enum(['true', 'false'])]).optional().default(false)
    .transform((valor) => valor === true || valor === 'true'),
  motivoChofer: z.string().trim().nullish(),
  actividad: z.string().trim().min(1),
  fechaProgramada: fechaIsoSchema,
  payloadFingerprint: z.string().regex(/^[0-9a-f]{64}$/),
}).refine((datos) => datos.partidas !== undefined || datos.litrosSolicitados !== undefined, {
  message: 'Indica los litros o las partidas de la solicitud.',
});

solicitudesRouter.post('/', requireRole('chofer', 'supervisor') as never,
  upload.fields([{ name: 'fotoTablero', maxCount: 1 }]), verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    const idempotencyKey = leerIdempotencyKey(req, true)!;
    const raw = req.body.partidas;
    const datos = enviarSolicitudSchema.parse({
      ...req.body,
      partidas: typeof raw === 'string' ? JSON.parse(raw) : raw,
    });
    const archivos = req.files as { fotoTablero?: Express.Multer.File[] } | undefined;
    const fotoTableroPath = archivos?.fotoTablero?.[0]
      ? rutaPublicaDeArchivo(archivos.fotoTablero[0].filename) : null;
    const fotoSha256 = await sha256Archivo(archivos?.fotoTablero?.[0]?.path);
    const fingerprintCalculado = fingerprintSolicitud({
      choferId: req.usuarioActual!.sub,
      vehiculoId: datos.vehiculoId,
      litrosSolicitados: datos.litrosSolicitados,
      partidas: datos.partidas,
      esUrgente: datos.esUrgente,
      motivoChofer: datos.motivoChofer,
      actividad: datos.actividad,
      fechaProgramada: datos.fechaProgramada,
      fotoSha256,
    });
    if (fingerprintCalculado !== datos.payloadFingerprint) {
      throw new ApiError(409, 'La solicitud no coincide con su identidad local.', {
        codigo: 'PAYLOAD_FINGERPRINT_INVALIDO',
      });
    }
    const resultado = await ejecutarIdempotente({
      usuarioId: req.usuarioActual!.sub,
      operacion: OPERACIONES_IDEMPOTENTES.crearSolicitud,
      idempotencyKey,
      requestHash: fingerprintCalculado,
      requestId: requestIdDe(req),
      ejecutar: async (cliente) => {
    const solicitud = datos.partidas
      ? await marimbaPartidasService.crearSolicitudConPartidas({
          solicitanteId: req.usuarioActual!.sub,
          rol: req.usuarioActual!.rol,
          vehiculoId: datos.vehiculoId,
          partidas: datos.partidas,
          actividad: datos.actividad,
          fechaProgramada: datos.fechaProgramada,
          esUrgente: datos.esUrgente,
          motivoChofer: datos.motivoChofer,
          fotoTableroPath,
          idempotencyKey,
          payloadFingerprint: fingerprintCalculado,
        }, cliente)
      : await solicitudesService.enviarSolicitud({
          choferId: req.usuarioActual!.sub,
          rol: req.usuarioActual!.rol,
          vehiculoId: datos.vehiculoId,
          litrosSolicitados: datos.litrosSolicitados!,
          esUrgente: datos.esUrgente,
          motivoChofer: datos.motivoChofer,
          actividad: datos.actividad,
          fechaProgramada: datos.fechaProgramada,
          fotoTableroPath,
          idempotencyKey,
          payloadFingerprint: fingerprintCalculado,
        }, cliente);
    return { status: 201, body: solicitud, resourceType: 'solicitud_autorizacion', resourceId: solicitud.id };
      },
    });
    if (resultado.replayed || resultado.body.replayed) await eliminarArchivosNuevos(req);
    if (resultado.replayed) res.set('Idempotency-Replayed', 'true');
    res.status(resultado.status).json(resultado.body);
  }));

const resolverSolicitudSchema = z.object({
  aprobar: z.boolean().optional(),
  litrosAutorizados: z.number().positive().nullish(),
  motivo: z.string().trim().nullish(),
  partidas: z.array(z.object({
    tipo: z.enum(['consumo_propio', 'carga_granel']),
    aprobar: z.boolean(),
    litrosAutorizados: z.number().positive().nullish(),
    observaciones: z.string().trim().max(500).nullish(),
  })).min(1).max(2).optional(),
}).refine((datos) => datos.partidas !== undefined || datos.aprobar !== undefined, {
  message: 'Indica la resolución de la solicitud.',
});

solicitudesRouter.patch('/:id/resolver', requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = resolverSolicitudSchema.parse(req.body);
    if (datos.partidas) {
      await marimbaPartidasService.autorizarPartidas({
        solicitudId: req.params.id as string,
        decisiones: datos.partidas,
        aprobadaPor: req.usuarioActual!.usuario,
        aprobadaPorId: req.usuarioActual!.sub,
      });
      const solicitud = await solicitudesService.buscarSolicitudPorId(req.params.id as string);
      if (!solicitud) throw new ApiError(404, 'Solicitud no encontrada.');
      solicitud.partidas = await marimbaPartidasService.listarPartidas(solicitud.id);
      res.json(solicitud);
      return;
    }
    res.json(await solicitudesService.resolverSolicitud(req.params.id as string, {
      aprobar: datos.aprobar!, litrosAutorizados: datos.litrosAutorizados, motivo: datos.motivo,
      resueltaPor: req.usuarioActual!.usuario, resueltaPorId: req.usuarioActual!.sub,
    }));
  }));

solicitudesRouter.patch('/:id/cancelar', requireRole('chofer', 'supervisor') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    res.json(await solicitudesService.cancelarSolicitud(req.params.id as string, req.usuarioActual!.sub));
  }));

// Si la validación de negocio o la inserción falla después de que Multer
// escribió la foto, elimina únicamente los archivos creados por esta
// petición. Así no queda una evidencia huérfana asociada a ninguna fila.
solicitudesRouter.use(limpiarArchivosAnteError);
