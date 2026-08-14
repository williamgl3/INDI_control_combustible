import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import {
  eliminarArchivosNuevos,
  upload,
  rutaPublicaDeArchivo,
  verificarMagicBytes,
} from '../middleware/upload';
import * as evidenciasService from '../services/evidenciasService';

export const evidenciasRouter = Router();

evidenciasRouter.use(requireAuth as never);

const MAX_FOTOS = 5;

// 'ticket' se unificó con 'comprobante' (ver evidenciasService.ts). Los 4
// campos nuevos son obligatorios SOLO cuando `tipo === 'comprobante'`
// (`.refine` de abajo) — para 'tablero' ni siquiera deben mandarse.
const subirSchema = z
  .object({
    usuario_id: z.string().uuid(),
    tipo: z.enum(['tablero', 'comprobante']),
    folio_id: z.string().uuid().optional(),
    // Sin flujo de UI todavía que lo llene (ver análisis de vinculación
    // offline pendiente) — se acepta desde ya para no requerir otra
    // migración de esquema cuando ese flujo se construya.
    carga_id: z.string().uuid().optional(),
    km: z.coerce.number().positive().optional(),
    pendiente_vincular: z.coerce.boolean().optional(),
    notas: z.string().trim().optional(),
    tipo_combustible_cargado: z.string().trim().min(1).optional(),
    litros: z.coerce.number().positive().optional(),
    precio_por_litro: z.coerce.number().positive().optional(),
    monto_pagado: z.coerce.number().positive().optional(),
  })
  .refine(
    (datos) =>
      datos.tipo !== 'comprobante' ||
      (datos.tipo_combustible_cargado !== undefined &&
        datos.litros !== undefined &&
        datos.precio_por_litro !== undefined &&
        datos.monto_pagado !== undefined),
    {
      message:
        'Para un comprobante, indica tipo de combustible, litros, precio por litro y total pagado.',
      path: ['tipo_combustible_cargado'],
    },
  );

evidenciasRouter.post(
  '/',
  requireRole('chofer', 'supervisor') as never,
  upload.fields([
    { name: 'foto', maxCount: 1 }, // compatibilidad con clientes viejos
    { name: 'fotos', maxCount: MAX_FOTOS },
  ]),
  verificarMagicBytes,
  asyncHandler(async (req: AuthRequest, res) => {
    try {
      const datos = subirSchema.parse(req.body);
    const archivos = req.files as
      | { foto?: Express.Multer.File[]; fotos?: Express.Multer.File[] }
      | undefined;
    const fotoFiles = archivos?.fotos?.length
      ? archivos.fotos
      : archivos?.foto ?? [];

    if (fotoFiles.length === 0) {
      res.status(400).json({ error: 'Al menos una foto es obligatoria.' });
      return;
    }

      await evidenciasService.validarRelacionEvidencia({
        usuarioId: req.usuarioActual!.sub,
        folioId: datos.folio_id,
        cargaId: datos.carga_id,
      });
      const evidencia = await evidenciasService.subir({
      usuarioId: req.usuarioActual!.sub,
      tipo: datos.tipo,
      fotoUrls: fotoFiles.map((f) => rutaPublicaDeArchivo(f.filename)),
      km: datos.km ?? null,
      folioId: datos.folio_id ?? null,
      cargaId: datos.carga_id ?? null,
      pendienteVincular: datos.pendiente_vincular ?? false,
      notas: datos.notas ?? null,
      tipoCombustibleCargado: datos.tipo_combustible_cargado ?? null,
      litros: datos.litros ?? null,
      precioPorLitro: datos.precio_por_litro ?? null,
      montoPagado: datos.monto_pagado ?? null,
    });

      res.status(201).json(evidencia);
    } catch (error) {
      await eliminarArchivosNuevos(req);
      throw error;
    }
  }),
);

evidenciasRouter.get(
  '/mias',
  asyncHandler(async (req: AuthRequest, res) => {
    res.json(await evidenciasService.listarDeUsuario(req.usuarioActual!.sub));
  }),
);

/// Para el panel administrativo — hoy usado por el reporte de
/// Concentrado para resolver el gasto real de una carga.
evidenciasRouter.get(
  '/',
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (_req, res) => {
    res.json(await evidenciasService.listarTodas());
  }),
);
