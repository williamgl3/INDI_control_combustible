import type { NextFunction, Request, Response } from 'express';

/// Envuelve un handler async para que sus rechazos (throws) lleguen al
/// middleware de errores en vez de colgar la petición — Express 5 ya
/// reenvía rechazos de promesas automáticamente, pero este wrapper deja
/// explícito el contrato y facilita tipar `req`/`res` por ruta.
export function asyncHandler<Req extends Request = Request>(
  fn: (req: Req, res: Response, next: NextFunction) => Promise<unknown>,
) {
  return (req: Req, res: Response, next: NextFunction) => {
    fn(req, res, next).catch(next);
  };
}

/// Error con código HTTP explícito — el middleware de errores lo usa para
/// decidir el status en vez de devolver siempre 500.
export class ApiError extends Error {
  status: number;
  codigo: string | undefined;
  detalles: Record<string, unknown> | undefined;

  constructor(
    status: number,
    message: string,
    opciones?: { codigo?: string; detalles?: Record<string, unknown> },
  ) {
    super(message);
    this.status = status;
    this.codigo = opciones?.codigo;
    this.detalles = opciones?.detalles;
    this.name = 'ApiError';
  }
}
