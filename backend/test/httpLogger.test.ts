import { Writable } from 'node:stream';
import express from 'express';
import pino from 'pino';
import pinoHttp from 'pino-http';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { httpLoggerOptions } from '../src/utils/httpLogger';

describe('logger HTTP', () => {
  it('redacta credenciales y conserva metadatos de la solicitud', async () => {
    const lineas: string[] = [];
    const stream = new Writable({
      write(chunk, _encoding, callback) {
        lineas.push(chunk.toString());
        callback();
      },
    });
    const app = express();
    const logger = pino({}, stream);
    app.use(pinoHttp({ logger, ...httpLoggerOptions }));
    app.get('/prueba-log', (_req, res) => {
      res.setHeader('set-cookie', 'sesion=valor-sensible; HttpOnly');
      res.status(204).end();
    });

    await request(app)
      .get('/prueba-log')
      .set('authorization', 'Bearer token-de-prueba')
      .set('cookie', 'sesion=cookie-de-prueba')
      .expect(204);

    const salida = lineas.join('');
    expect(salida).not.toContain('token-de-prueba');
    expect(salida).not.toContain('cookie-de-prueba');
    expect(salida).not.toContain('valor-sensible');
    expect(salida).toContain('[REDACTED]');

    const registro = JSON.parse(lineas.at(-1) ?? '{}') as {
      req?: { method?: string; url?: string };
      res?: { statusCode?: number };
    };
    expect(registro.req?.method).toBe('GET');
    expect(registro.req?.url).toBe('/prueba-log');
    expect(registro.res?.statusCode).toBe(204);
  });
});
