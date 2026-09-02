import express from 'express';
import { authRouter } from '../src/routes/auth.routes';
import { usuariosRouter } from '../src/routes/usuarios.routes';
import { errorHandler } from '../src/middleware/errorHandler';

/// App mínima para probar `auth.routes.ts`/`usuarios.routes.ts` con
/// supertest, sin levantar un server real ni depender de Postgres (el
/// pool se mockea por archivo de test, ver `test/auth.*.test.ts`).
export function crearAppDePrueba() {
  const app = express();
  app.use(express.json());
  app.use('/', authRouter);
  app.use('/usuarios', usuariosRouter);
  app.use(errorHandler);
  return app;
}
