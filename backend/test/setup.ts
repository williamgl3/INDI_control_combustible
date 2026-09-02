// Variables de entorno para la suite de tests — se cargan ANTES de que
// cualquier archivo de test importe módulos de `src/` (jwt.ts,
// rateLimit.ts, etc. leen `process.env` al importarse), así que deben
// fijarse aquí y no dentro de cada test.
process.env.NODE_ENV = 'test';
process.env.JWT_SECRET = 'secreto-de-pruebas';
process.env.JWT_EXPIRES_IN = '1h';

// Ventanas de rate limit chicas para poder disparar el límite en tests
// sin mandar cientos de requests.
process.env.AUTH_RATE_LIMIT_WINDOW_MS = '60000';
process.env.AUTH_RATE_LIMIT_MAX = '3';
process.env.AUTH_RATE_LIMIT_MAX_NORMAL = '3';
