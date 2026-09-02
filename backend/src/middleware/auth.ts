import type { NextFunction, Request, Response } from 'express';
import { verificarToken } from '../utils/jwt';
import { ApiError } from '../utils/asyncHandler';
import { pool } from '../db/pool';
import type { RolUsuario, TokenPayload } from '../types';

export interface AuthRequest extends Request {
  usuarioActual?: TokenPayload;
}

/// Exige un `Authorization: Bearer <token>` válido — cuelga el payload
/// decodificado en `req.usuarioActual` para que las rutas/servicios sepan
/// quién hace la petición (ej. `choferId` en /solicitudes).
///
/// Además de validar firma/expiración, compara `tokenVersion` del payload
/// contra `usuarios.token_version` en BD — si no coinciden, el token se
/// considera revocado (ej. la contraseña cambió después de emitirlo) y se
/// rechaza con 401 aunque la firma siga siendo válida.
export async function requireAuth(req: AuthRequest, _res: Response, next: NextFunction) {
  const header = req.headers.authorization;
  if (!header?.startsWith('Bearer ')) {
    throw new ApiError(401, 'Falta el token de autenticación.');
  }
  const token = header.slice('Bearer '.length);
  let payload: TokenPayload;
  try {
    payload = verificarToken(token);
  } catch {
    throw new ApiError(401, 'Token inválido o expirado.');
  }

  const { rows } = await pool.query<{ token_version: number; activo: boolean }>(
    'SELECT token_version, activo FROM usuarios WHERE id = $1',
    [payload.sub],
  );
  const usuarioActual = rows[0];
  if (!usuarioActual || usuarioActual.activo === false || usuarioActual.token_version !== payload.tokenVersion) {
    throw new ApiError(401, 'Token inválido o expirado.');
  }

  req.usuarioActual = payload;
  next();
}

/// Exige además que el rol del usuario autenticado esté en la lista
/// permitida (ej. `requireRole('administrativo')` para endpoints de
/// administración).
export function requireRole(...roles: RolUsuario[]) {
  return (req: AuthRequest, _res: Response, next: NextFunction) => {
    if (!req.usuarioActual || !roles.includes(req.usuarioActual.rol)) {
      throw new ApiError(403, 'No tienes permiso para esta acción.');
    }
    next();
  };
}
