import rateLimit from 'express-rate-limit';

/// Límites de fuerza bruta/enumeración para las rutas de auth más
/// sensibles. Configurable vía `.env` (mismo patrón que el resto del
/// proyecto, ver `.env.example`) para poder ajustarlo sin tocar código
/// entre ambientes.
///
/// - `authStrictLimiter` — login y recuperar-password: los más
///   golpeados por fuerza bruta/enumeración de cuentas. Default: 10
///   intentos / 15 minutos por IP.
/// - `authLimiter` — registro-chofer y cambiar-password: un poco más
///   holgado, pero igual limitado para no dejar esas rutas abiertas.
const RATE_LIMIT_WINDOW_MS = Number(process.env.AUTH_RATE_LIMIT_WINDOW_MS ?? 15 * 60 * 1000);
const RATE_LIMIT_MAX_STRICT = Number(process.env.AUTH_RATE_LIMIT_MAX ?? 10);
const RATE_LIMIT_MAX_NORMAL = Number(process.env.AUTH_RATE_LIMIT_MAX_NORMAL ?? 20);
// `/auth/refresh` se llama automáticamente por el cliente (no es un
// intento manual de un humano), así que necesita un límite mucho más
// generoso que login — solo para contener abuso franco, no fricciona el
// uso normal de un access token de vida corta que se renueva seguido.
const RATE_LIMIT_MAX_REFRESH = Number(process.env.AUTH_RATE_LIMIT_MAX_REFRESH ?? 30);

const mensajeLimite = { error: 'Demasiados intentos. Intenta de nuevo más tarde.' };

export const authStrictLimiter = rateLimit({
  windowMs: RATE_LIMIT_WINDOW_MS,
  limit: RATE_LIMIT_MAX_STRICT,
  standardHeaders: true,
  legacyHeaders: false,
  message: mensajeLimite,
});

export const authLimiter = rateLimit({
  windowMs: RATE_LIMIT_WINDOW_MS,
  limit: RATE_LIMIT_MAX_NORMAL,
  standardHeaders: true,
  legacyHeaders: false,
  message: mensajeLimite,
});

export const authRefreshLimiter = rateLimit({
  windowMs: RATE_LIMIT_WINDOW_MS,
  limit: RATE_LIMIT_MAX_REFRESH,
  standardHeaders: true,
  legacyHeaders: false,
  message: mensajeLimite,
});
