import type { NextFunction, Request, Response } from 'express';
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
    res.status(err.status).json({ error: err.message });
    return;
  }
  if (err instanceof ZodError) {
    const mensaje = err.issues.map((i) => `${i.path.join('.')}: ${i.message}`).join('; ');
    res.status(400).json({ error: mensaje });
    return;
  }
  logger.error({ err }, 'Error no manejado');
  res.status(500).json({ error: 'Ocurrió un error inesperado.' });
}
