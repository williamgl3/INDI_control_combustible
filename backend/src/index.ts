import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import pinoHttp from 'pino-http';
import dotenv from 'dotenv';
import { authRouter } from './routes/auth.routes';
import { vehiculosRouter } from './routes/vehiculos.routes';
import { solicitudesRouter } from './routes/solicitudes.routes';
import { cargasRouter } from './routes/cargas.routes';
import { cierresDiaRouter } from './routes/cierresDia.routes';
import { preciosRouter } from './routes/precios.routes';
import { incidenciasRouter } from './routes/incidencias.routes';
import { usuariosRouter } from './routes/usuarios.routes';
import { auditoriaRouter } from './routes/auditoria.routes';
import { evidenciasRouter } from './routes/evidencias.routes';
import { suministrosRouter } from './routes/suministros.routes';
import { despachosMarimbaRouter } from './routes/despachosMarimba.routes';
import { recorridosMarimbaRouter } from './routes/recorridosMarimba.routes';
import { errorHandler } from './middleware/errorHandler';
import { UPLOADS_DIR } from './middleware/upload';
import { logger } from './utils/logger';
import { httpLoggerOptions } from './utils/httpLogger';
import { pool } from './db/pool';

dotenv.config({ quiet: true });

/// Origin(es) permitidos para CORS, vía `CORS_ORIGIN` (uno o varios
/// separados por coma, admite `*` como comodín simple, ej.
/// `http://localhost:*`).
///
/// En `NODE_ENV=production` esta variable es OBLIGATORIA — el servidor no
/// arranca sin ella, para no quedar abierto a cualquier origin por un
/// `.env` de producción incompleto. Fuera de producción, si no está
/// definida se permite cualquier origin — pensado para no romper el
/// flujo de desarrollo local (donde el puerto de Flutter web/emuladores
/// varía).
function construirCorsOrigin(): boolean | (string | RegExp)[] {
  const raw = process.env.CORS_ORIGIN;
  if (!raw || raw.trim() === '') {
    if (process.env.NODE_ENV === 'production') {
      throw new Error(
        'Falta CORS_ORIGIN en las variables de entorno — obligatoria en producción (ver .env.example).',
      );
    }
    return true;
  }
  return raw.split(',').map((origen) => {
    const limpio = origen.trim();
    if (!limpio.includes('*')) return limpio;
    const escapado = limpio.replace(/[.+?^${}()|[\]\\]/g, '\\$&').replace(/\*/g, '.*');
    return new RegExp(`^${escapado}$`);
  });
}

const app = express();
app.use(helmet());
app.use(cors({ origin: construirCorsOrigin() }));
app.use(
  pinoHttp({
    logger,
    ...httpLoggerOptions,
    // pino-http ya incluye método/status/tiempo por request; no hace
    // falta loggear nada extra a mano en cada ruta.
    autoLogging: true,
  }),
);
app.use(express.json());
app.use('/uploads', express.static(UPLOADS_DIR));

app.get('/health', async (_req, res) => {
  // Antes solo confirmaba que el proceso Express respondía — no servía
  // para detectar el caso real más común (Postgres caído/inalcanzable),
  // que es justo lo que un orquestador/monitor necesita saber.
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', db: 'ok' });
  } catch {
    res.status(503).json({ status: 'error', db: 'unreachable' });
  }
});

app.use('/', authRouter);
app.use('/vehiculos', vehiculosRouter);
app.use('/solicitudes', solicitudesRouter);
app.use('/cargas', cargasRouter);
app.use('/cierres-dia', cierresDiaRouter);
app.use('/precios', preciosRouter);
app.use('/incidencias', incidenciasRouter);
app.use('/usuarios', usuariosRouter);
app.use('/auditoria', auditoriaRouter);
app.use('/evidencias', evidenciasRouter);
app.use('/suministros', suministrosRouter);
app.use('/despachos-marimba', despachosMarimbaRouter);
app.use('/recorridos-marimba', recorridosMarimbaRouter);

// SIEMPRE al final — traduce errores (ApiError/ZodError/lo que sea) a
// una respuesta JSON consistente en vez de colgar la petición. Solo
// cambia CÓMO se loggea internamente (pino), no qué se le expone al
// cliente.
app.use(errorHandler);

// Red de seguridad a nivel de proceso: `errorHandler` de arriba solo cubre
// errores dentro del ciclo de request de Express (vía `asyncHandler`). Un
// error verdaderamente inesperado fuera de ese ciclo (un listener suelto,
// una promesa sin `catch`) puede tumbar el proceso sin dejar rastro. Aquí
// se loggea y se sale con código de error — no se intenta "seguir
// corriendo" con estado potencialmente corrupto; se delega el reinicio al
// supervisor del proceso (política `restart` del contenedor/hosting, ver
// `docker-compose.yml` y `Dockerfile`).
process.on('uncaughtException', (err) => {
  logger.error({ err }, 'uncaughtException — el proceso va a salir');
  process.exit(1);
});

process.on('unhandledRejection', (reason) => {
  logger.error({ err: reason }, 'unhandledRejection — el proceso va a salir');
  process.exit(1);
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  logger.info(`Servidor corriendo en puerto ${PORT}`);
});
