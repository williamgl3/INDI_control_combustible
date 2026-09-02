import type { NextFunction, Request, Response } from 'express';
import multer from 'multer';
import { ZodError } from 'zod';
import { ApiError } from '../utils/asyncHandler';
import { logger } from '../utils/logger';

/// Middleware de errores centralizado — SIEMPRE al final de la cadena de
/// middlewares en `index.ts`. Traduce `ApiError`/`ZodError` a una
/// respuesta JSON consistente `{ error: string }`, y cualquier otro error
/// no anticipado a un 500 (sin filtrar detalles internos al cliente).
// eslint-disable-next-line @typescript-eslint/no-unused-vars
export function errorHandler(err: unknown, _req: Request, res: Response, _next: NextFunction) {
  if (err instanceof ApiError) {
    res.status(err.status).json({
      error: err.message,
      ...(err.codigo ? { codigo: err.codigo } : {}),
      ...(err.detalles ?? {}),
    });
    return;
  }
  if (err instanceof ZodError) {
    const mensaje = err.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    res.status(400).json({ error: mensaje });
    return;
  }
  // Multer errors are client/input errors, not server failures. Previously
  // they fell through to the generic 500 response, hiding invalid image
  // MIME types, oversized files and unexpected multipart field names.
  if (err instanceof multer.MulterError) {
    const mensaje = err.code === 'LIMIT_FILE_SIZE'
      ? 'La imagen excede el tamaño máximo permitido (10 MB).'
      : err.code === 'LIMIT_UNEXPECTED_FILE'
        ? 'La evidencia enviada no tiene un campo válido.'
        : 'No fue posible procesar la evidencia enviada.';
    logger.warn({ code: err.code }, 'Solicitud multipart inválida');
    res.status(400).json({ error: mensaje });
    return;
  }
  // The upload fileFilter uses a deliberate, user-safe Error for MIME
  // rejection. Keep it as a 400 instead of exposing it as an unexplained 500.
  if (err instanceof Error && err.message === 'Formato de imagen no soportado.') {
    logger.warn({ err: err.message }, 'Formato de imagen rechazado');
    res.status(400).json({ error: err.message });
    return;
  }
  logger.error({ err }, 'Error no manejado');
  res.status(500).json({ error: 'Ocurrió un error inesperado.' });
}
