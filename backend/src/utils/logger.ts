import pino from 'pino';

/// Logger estructurado compartido — reemplaza los `console.log`/
/// `console.error` sueltos en toda la app. Emite JSON de una línea por
/// entrada (formato estándar de pino), listo para cualquier colector de
/// logs; el nivel se ajusta con `LOG_LEVEL` o cae a `debug` en
/// desarrollo / `info` en producción.
///
/// Nota: NO cambia qué se le expone al cliente en las respuestas HTTP —
/// `errorHandler` sigue devolviendo solo `{ error: string }` genérico;
/// esto solo cambia cómo se registra internamente.
export const logger = pino({
  level: process.env.LOG_LEVEL ?? (process.env.NODE_ENV === 'production' ? 'info' : 'debug'),
});
