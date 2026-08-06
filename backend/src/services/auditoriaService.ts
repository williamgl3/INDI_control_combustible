import { pool } from '../db/pool';
import { logger } from '../utils/logger';

/// Auditoría de acciones administrativas sensibles (aprobar/rechazar
/// solicitudes, editar vehículos/topes, mantenimiento, incidencias,
/// precios, gestión de usuarios). Ver migración `0003_auditoria_acciones`.
///
/// Deliberadamente "best effort": si el insert falla (ej. la BD está
/// caída un instante), NO debe tirar la operación principal que se está
/// auditando — solo se loggea el error y se sigue. Perder una entrada de
/// auditoría es mucho menos grave que romper una aprobación/rechazo real
/// por un problema ajeno a esa operación.
export async function registrarAuditoria(datos: {
  usuarioId: string | null | undefined;
  accion: string;
  entidad: string;
  entidadId?: string | null | undefined;
  detalle?: Record<string, unknown> | null | undefined;
}): Promise<void> {
  try {
    await pool.query(
      `INSERT INTO auditoria_acciones (usuario_id, accion, entidad, entidad_id, detalle)
       VALUES ($1, $2, $3, $4, $5)`,
      [
        datos.usuarioId ?? null,
        datos.accion,
        datos.entidad,
        datos.entidadId ?? null,
        datos.detalle ? JSON.stringify(datos.detalle) : null,
      ],
    );
  } catch (err) {
    logger.error({ err, datos }, 'No se pudo registrar la auditoría (se ignora, no bloquea la operación).');
  }
}

interface FilaAuditoria {
  id: string;
  usuario_id: string | null;
  usuario_nombre: string | null;
  accion: string;
  entidad: string;
  entidad_id: string | null;
  detalle: unknown;
  creado_en: Date;
}

export interface RegistroAuditoria {
  id: string;
  usuarioId: string | null;
  usuarioNombre: string | null;
  accion: string;
  entidad: string;
  entidadId: string | null;
  detalle: unknown;
  creadoEn: string;
}

function aRegistro(fila: FilaAuditoria): RegistroAuditoria {
  return {
    id: fila.id,
    usuarioId: fila.usuario_id,
    usuarioNombre: fila.usuario_nombre,
    accion: fila.accion,
    entidad: fila.entidad,
    entidadId: fila.entidad_id,
    detalle: fila.detalle,
    creadoEn: fila.creado_en.toISOString(),
  };
}

/// Paginación hacia atrás por cursor (`before`, timestamp ISO): siempre
/// ordenado por `creado_en DESC`, así que "antes de X" es simplemente
/// "más viejo que X" — evita el problema de offsets que se corren cuando
/// se insertan filas nuevas mientras se pagina.
export async function listarAuditoria(opciones: {
  limit: number;
  before?: string | null | undefined;
}): Promise<RegistroAuditoria[]> {
  const params: unknown[] = [opciones.limit];
  let filtroBefore = '';
  if (opciones.before) {
    params.push(opciones.before);
    filtroBefore = `WHERE a.creado_en < $${params.length}`;
  }

  const { rows } = await pool.query<FilaAuditoria>(
    `SELECT a.id, a.usuario_id, u.nombre AS usuario_nombre, a.accion, a.entidad,
            a.entidad_id, a.detalle, a.creado_en
     FROM auditoria_acciones a
     LEFT JOIN usuarios u ON u.id = a.usuario_id
     ${filtroBefore}
     ORDER BY a.creado_en DESC
     LIMIT $1`,
    params,
  );
  return rows.map(aRegistro);
}
