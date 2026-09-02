import dotenv from 'dotenv';
import jwt from 'jsonwebtoken';
import type { TokenPayload } from '../types';

// Ver el comentario en `db/pool.ts` sobre por qué cada módulo que lee
// `process.env` al cargar necesita su propio `dotenv.config()` — no basta
// con que el entrypoint lo llame, por el orden de evaluación de imports.
dotenv.config({ quiet: true });

const JWT_SECRET = process.env.JWT_SECRET;
// `ACCESS_TOKEN_EXPIRES_IN` es el nombre nuevo (default corto — el access
// token ahora vive poco porque `refreshTokenService` cubre la renovación
// de sesión sin volver a pedir credenciales). Se mantiene `JWT_EXPIRES_IN`
// como fallback de compatibilidad por si algún ambiente ya lo tiene
// configurado — no se usa en ningún otro módulo del proyecto.
const ACCESS_TOKEN_EXPIRES_IN =
  process.env.ACCESS_TOKEN_EXPIRES_IN ?? process.env.JWT_EXPIRES_IN ?? '15m';

if (!JWT_SECRET) {
  throw new Error('Falta JWT_SECRET en las variables de entorno (ver .env.example).');
}

export function firmarToken(payload: TokenPayload): string {
  return jwt.sign(payload, JWT_SECRET as string, {
    expiresIn: ACCESS_TOKEN_EXPIRES_IN,
  } as jwt.SignOptions);
}

export function verificarToken(token: string): TokenPayload {
  return jwt.verify(token, JWT_SECRET as string) as TokenPayload;
}
