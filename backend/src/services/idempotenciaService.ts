import type { Request } from 'express';
import type { PoolClient } from 'pg';
import { z } from 'zod';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import { logger } from '../utils/logger';

export const OPERACIONES_IDEMPOTENTES = {
  crearSolicitud: 'solicitud.crear',
  registrarCarga: 'carga.registrar',
  crearCierreDia: 'cierre_dia.crear',
  reportarIncidencia: 'incidencia.reportar',
  subirEvidencia: 'evidencia.subir',
  abrirRecorridoMarimba: 'recorrido_marimba.abrir',
  crearDespachoMarimba: 'despacho_marimba.crear',
  cerrarRecorridoMarimba: 'recorrido_marimba.cerrar',
} as const;

export type OperacionIdempotente = typeof OPERACIONES_IDEMPOTENTES[keyof typeof OPERACIONES_IDEMPOTENTES];
export const MAX_RESPONSE_BODY_BYTES = 64 * 1024;
const uuidV4 = z.string().uuid().regex(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i);
const CAMPOS_SENSIBLES = /^(password|password_hash|token|access_token|refresh_token|authorization|cookie|set-cookie)$/i;

export function leerIdempotencyKey(req: Request, obligatoria: boolean): string | null {
  const valores: string[] = [];
  for (let i = 0; i < req.rawHeaders.length; i += 2) {
    if (req.rawHeaders[i]?.toLowerCase() === 'idempotency-key') valores.push(req.rawHeaders[i + 1] ?? '');
  }
  if (valores.length === 0) {
    if (obligatoria) throw new ApiError(400, 'Falta Idempotency-Key.', { codigo: 'IDEMPOTENCY_KEY_REQUIRED' });
    return null;
  }
  if (valores.length !== 1 || valores[0]!.length > 64 || valores[0]!.includes(',')) {
    throw new ApiError(400, 'Idempotency-Key invalida.', { codigo: 'IDEMPOTENCY_KEY_INVALID' });
  }
  const parsed = uuidV4.safeParse(valores[0]);
  if (!parsed.success) throw new ApiError(400, 'Idempotency-Key invalida.', { codigo: 'IDEMPOTENCY_KEY_INVALID' });
  return parsed.data.toLowerCase();
}

export function requestIdDe(req: Request): string | undefined {
  const id = (req as Request & { id?: unknown }).id;
  return typeof id === 'string' || typeof id === 'number' ? String(id) : undefined;
}

function asegurarRespuestaSegura(valor: unknown, ruta = '$'): void {
  if (Buffer.isBuffer(valor) || valor instanceof Uint8Array) {
    throw new ApiError(500, 'La respuesta idempotente contiene datos binarios no permitidos.');
  }
  if (Array.isArray(valor)) {
    valor.forEach((item, indice) => asegurarRespuestaSegura(item, `${ruta}[${indice}]`));
    return;
  }
  if (valor && typeof valor === 'object') {
    for (const [clave, item] of Object.entries(valor as Record<string, unknown>)) {
      if (CAMPOS_SENSIBLES.test(clave)) {
        throw new ApiError(500, `La respuesta idempotente contiene un campo no almacenable (${ruta}.${clave}).`);
      }
      asegurarRespuestaSegura(item, `${ruta}.${clave}`);
    }
  }
}

export function serializarRespuestaIdempotente(body: unknown): string | null {
  if (body === undefined) return null;
  asegurarRespuestaSegura(body);
  const serializada = JSON.stringify(body);
  if (Buffer.byteLength(serializada, 'utf8') > MAX_RESPONSE_BODY_BYTES) {
    throw new ApiError(500, 'La respuesta idempotente excede el limite seguro de almacenamiento.');
  }
  return serializada;
}

export interface ResultadoNegocio<T> {
  status: number;
  body: T;
  resourceType?: string | null;
  resourceId?: string | null;
}

export type ResultadoIdempotente<T> = ResultadoNegocio<T> & { replayed: boolean };

interface FilaLedger {
  request_hash: string;
  resource_type: string | null;
  resource_id: string | null;
  http_status: number | null;
  response_body: unknown;
}

export async function ejecutarIdempotente<T>(datos: {
  usuarioId: string;
  operacion: OperacionIdempotente;
  idempotencyKey: string | null;
  requestHash: string;
  requestId?: string | undefined;
  ejecutar: (cliente: PoolClient) => Promise<ResultadoNegocio<T>>;
}): Promise<ResultadoIdempotente<T>> {
  const cliente = await pool.connect();
  const inicio = Date.now();
  try {
    await cliente.query('BEGIN');
    if (datos.idempotencyKey === null) {
      logger.info({ requestId: datos.requestId, usuarioId: datos.usuarioId, operacion: datos.operacion, estado: 'legacy' }, 'Operacion sin Idempotency-Key');
      const resultado = await datos.ejecutar(cliente);
      await cliente.query('COMMIT');
      return { ...resultado, replayed: false };
    }

    const adquirida = await cliente.query<{ id: string }>(
      `INSERT INTO operaciones_idempotentes
         (usuario_id, operacion, idempotency_key, request_hash)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (usuario_id, operacion, idempotency_key) DO NOTHING
       RETURNING id`,
      [datos.usuarioId, datos.operacion, datos.idempotencyKey, datos.requestHash],
    );
    if (adquirida.rowCount === 0) {
      const existente = await cliente.query<FilaLedger>(
        `SELECT request_hash, resource_type, resource_id, http_status, response_body
           FROM operaciones_idempotentes
          WHERE usuario_id=$1 AND operacion=$2 AND idempotency_key=$3`,
        [datos.usuarioId, datos.operacion, datos.idempotencyKey],
      );
      const fila = existente.rows[0];
      if (!fila?.http_status) throw new Error('La operacion idempotente conflictiva no quedo visible.');
      if (fila.request_hash !== datos.requestHash) {
        await cliente.query('ROLLBACK');
        logger.warn({ requestId: datos.requestId, usuarioId: datos.usuarioId, operacion: datos.operacion, estado: 'payload_conflict' }, 'Conflicto de idempotencia');
        throw new ApiError(409, 'La Idempotency-Key ya fue utilizada con otro payload.', {
          codigo: 'IDEMPOTENCY_KEY_PAYLOAD_MISMATCH',
        });
      }
      await cliente.query('COMMIT');
      logger.info({ requestId: datos.requestId, usuarioId: datos.usuarioId, operacion: datos.operacion, estado: 'replayed', resourceId: fila.resource_id, status: fila.http_status, duracionMs: Date.now() - inicio }, 'Replay idempotente');
      return { status: fila.http_status, body: fila.response_body as T, resourceType: fila.resource_type, resourceId: fila.resource_id, replayed: true };
    }

    const resultado = await datos.ejecutar(cliente);
    const responseBody = serializarRespuestaIdempotente(resultado.body);
    await cliente.query(
      `UPDATE operaciones_idempotentes
          SET resource_type=$1, resource_id=$2, http_status=$3,
              response_body=$4::jsonb, completed_at=now()
        WHERE id=$5`,
      [resultado.resourceType ?? null, resultado.resourceId ?? null, resultado.status, responseBody, adquirida.rows[0]!.id],
    );
    await cliente.query('COMMIT');
    logger.info({ requestId: datos.requestId, usuarioId: datos.usuarioId, operacion: datos.operacion, estado: 'new', resourceId: resultado.resourceId, status: resultado.status, duracionMs: Date.now() - inicio }, 'Operacion idempotente completada');
    return { ...resultado, replayed: false };
  } catch (error) {
    await cliente.query('ROLLBACK').catch(() => undefined);
    if (!(error instanceof ApiError && error.codigo === 'IDEMPOTENCY_KEY_PAYLOAD_MISMATCH')) {
      logger.warn({ requestId: datos.requestId, usuarioId: datos.usuarioId, operacion: datos.operacion, estado: 'rolled_back', duracionMs: Date.now() - inicio }, 'Operacion idempotente revertida');
    }
    throw error;
  } finally {
    cliente.release();
  }
}
