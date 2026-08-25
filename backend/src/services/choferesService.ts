import type { PoolClient } from 'pg';
import { pool } from '../db/pool';
import type { Perfil } from '../types';
import { ApiError } from '../utils/asyncHandler';
import { registrarAuditoria } from './auditoriaService';

interface FilaChofer {
  id: string;
  usuario: string;
  nombre: string;
  apellido_paterno: string | null;
  apellido_materno: string | null;
  correo: string;
  fecha_nacimiento: Date | null;
  rol: 'chofer';
  activo: boolean;
  creado_en: Date;
  version: string;
  ultima_actividad: Date | null;
}

export interface ChoferAdministrable extends Perfil {
  activo: boolean;
  creadoEn: string;
  version: string;
  ultimaActividad: string | null;
}

export interface PaginaChoferes {
  datos: ChoferAdministrable[];
  pagina: number;
  limite: number;
  total: number;
  totalPaginas: number;
}

export interface ActividadChofer {
  solicitudes: number;
  cargas: number;
  evidencias: number;
  incidencias: number;
  cierres: number;
  recorridos: number;
  despachos: number;
  auditoria: number;
}

export interface CambiosChofer {
  nombre?: string | undefined;
  apellidoPaterno?: string | undefined;
  apellidoMaterno?: string | null | undefined;
  correo?: string | undefined;
  usuario?: string | undefined;
}

function aChofer(fila: FilaChofer): ChoferAdministrable {
  return {
    id: fila.id,
    usuario: fila.usuario,
    nombre: fila.nombre,
    apellidoPaterno: fila.apellido_paterno,
    apellidoMaterno: fila.apellido_materno,
    correo: fila.correo,
    fechaNacimiento: fila.fecha_nacimiento?.toISOString().slice(0, 10) ?? null,
    rol: 'chofer',
    activo: fila.activo,
    creadoEn: fila.creado_en.toISOString(),
    version: fila.version,
    ultimaActividad: fila.ultima_actividad?.toISOString() ?? null,
  };
}

const ULTIMA_ACTIVIDAD_SQL = `NULLIF(GREATEST(
  COALESCE((SELECT MAX(s.creada_en) FROM solicitudes_autorizacion s WHERE s.chofer_id = u.id), '-infinity'),
  COALESCE((SELECT MAX(c.creada_en) FROM cargas c WHERE c.chofer_id = u.id), '-infinity'),
  COALESCE((SELECT MAX(e.creado_en) FROM evidencias e WHERE e.usuario_id = u.id), '-infinity'),
  COALESCE((SELECT MAX(i.creada_en) FROM incidencias_vehiculo i WHERE i.chofer_id = u.id), '-infinity'),
  COALESCE((SELECT MAX(cd.registrada_en) FROM cierres_dia cd WHERE cd.chofer_id = u.id), '-infinity'),
  COALESCE((SELECT MAX(r.iniciado_en) FROM recorridos_marimba r WHERE r.operador_id = u.id), '-infinity'),
  COALESCE((SELECT MAX(d.creado_en) FROM despachos_marimba d WHERE d.registrado_por = u.id OR d.responsable_id = u.id), '-infinity'),
  COALESCE((SELECT MAX(a.creado_en) FROM auditoria_acciones a WHERE a.usuario_id = u.id), '-infinity')
), '-infinity')`;

export async function listar(opciones: {
  buscar?: string | undefined;
  estado: 'todos' | 'activo' | 'inactivo';
  pagina: number;
  limite: number;
}): Promise<PaginaChoferes> {
  const condiciones = ["u.rol = 'chofer'"];
  const parametros: unknown[] = [];
  if (opciones.estado !== 'todos') {
    parametros.push(opciones.estado === 'activo');
    condiciones.push(`u.activo = $${parametros.length}`);
  }
  if (opciones.buscar) {
    parametros.push(`%${opciones.buscar}%`);
    condiciones.push(`concat_ws(' ', u.nombre, u.apellido_paterno, u.apellido_materno, u.usuario, u.correo) ILIKE $${parametros.length}`);
  }
  const where = condiciones.join(' AND ');
  const totalResult = await pool.query<{ total: number }>(
    `SELECT count(*)::int AS total FROM usuarios u WHERE ${where}`,
    parametros,
  );
  const total = totalResult.rows[0]?.total ?? 0;
  parametros.push(opciones.limite, (opciones.pagina - 1) * opciones.limite);
  const { rows } = await pool.query<FilaChofer>(
    `SELECT u.id, u.usuario, u.nombre, u.apellido_paterno, u.apellido_materno,
            u.correo, u.fecha_nacimiento, u.rol, u.activo, u.creado_en,
            u.xmin::text AS version, ${ULTIMA_ACTIVIDAD_SQL} AS ultima_actividad
       FROM usuarios u
      WHERE ${where}
      ORDER BY u.nombre, u.apellido_paterno NULLS LAST, u.id
      LIMIT $${parametros.length - 1} OFFSET $${parametros.length}`,
    parametros,
  );
  return {
    datos: rows.map(aChofer),
    pagina: opciones.pagina,
    limite: opciones.limite,
    total,
    totalPaginas: Math.ceil(total / opciones.limite),
  };
}

const ACTIVIDAD_SQL = `SELECT
  (SELECT count(*)::int FROM solicitudes_autorizacion WHERE chofer_id=$1) solicitudes,
  (SELECT count(*)::int FROM cargas WHERE chofer_id=$1) cargas,
  (SELECT count(*)::int FROM evidencias WHERE usuario_id=$1) evidencias,
  (SELECT count(*)::int FROM incidencias_vehiculo WHERE chofer_id=$1) incidencias,
  (SELECT count(*)::int FROM cierres_dia WHERE chofer_id=$1) cierres,
  (SELECT count(*)::int FROM recorridos_marimba WHERE operador_id=$1 OR registrado_por=$1) recorridos,
  (SELECT count(*)::int FROM despachos_marimba WHERE registrado_por=$1 OR responsable_id=$1) despachos,
  (SELECT count(*)::int FROM auditoria_acciones WHERE usuario_id=$1 OR (entidad='usuario' AND entidad_id=$1::text)) auditoria`;

export async function obtener(id: string): Promise<{ chofer: ChoferAdministrable; actividad: ActividadChofer }> {
  const { rows } = await pool.query<FilaChofer>(
    `SELECT u.id, u.usuario, u.nombre, u.apellido_paterno, u.apellido_materno,
            u.correo, u.fecha_nacimiento, u.rol, u.activo, u.creado_en,
            u.xmin::text AS version, ${ULTIMA_ACTIVIDAD_SQL} AS ultima_actividad
       FROM usuarios u WHERE u.id=$1 AND u.rol='chofer'`,
    [id],
  );
  if (!rows[0]) throw new ApiError(404, 'Chofer no encontrado.');
  const actividad = await pool.query<ActividadChofer>(ACTIVIDAD_SQL, [id]);
  return { chofer: aChofer(rows[0]), actividad: actividad.rows[0]! };
}

export async function editar(
  id: string,
  cambios: CambiosChofer,
  version: string,
  actorId: string,
): Promise<ChoferAdministrable> {
  if (cambios.correo !== undefined) {
    const correoUsado = await pool.query(
      'SELECT 1 FROM usuarios WHERE id<>$1 AND lower(trim(correo))=lower(trim($2)) LIMIT 1',
      [id, cambios.correo],
    );
    if (correoUsado.rows[0]) throw new ApiError(409, 'Ese correo ya está registrado.');
  }
  const campos: string[] = [];
  const valores: unknown[] = [];
  const mapa: Record<string, string> = {
    nombre: 'nombre', apellidoPaterno: 'apellido_paterno', apellidoMaterno: 'apellido_materno',
    correo: 'correo', usuario: 'usuario',
  };
  for (const [campo, columna] of Object.entries(mapa)) {
    if (Object.prototype.hasOwnProperty.call(cambios, campo)) {
      valores.push(cambios[campo as keyof typeof cambios]);
      campos.push(`${columna}=$${valores.length}`);
    }
  }
  if (campos.length === 0) throw new ApiError(400, 'No hay cambios para guardar.');
  valores.push(id, version);
  try {
    const { rows } = await pool.query<FilaChofer>(
      `UPDATE usuarios SET ${campos.join(', ')}
        WHERE id=$${valores.length - 1} AND rol='chofer' AND xmin::text=$${valores.length}
        RETURNING id, usuario, nombre, apellido_paterno, apellido_materno, correo,
                  fecha_nacimiento, rol, activo, creado_en, xmin::text AS version, NULL::timestamptz AS ultima_actividad`,
      valores,
    );
    if (!rows[0]) {
      const existe = await pool.query("SELECT 1 FROM usuarios WHERE id=$1 AND rol='chofer'", [id]);
      if (!existe.rows[0]) throw new ApiError(404, 'Chofer no encontrado.');
      throw new ApiError(409, 'El perfil cambió en otra sesión. Actualiza e inténtalo nuevamente.');
    }
    await registrarAuditoria({ usuarioId: actorId, accion: 'chofer_actualizado', entidad: 'usuario', entidadId: id, detalle: { campos: Object.keys(cambios) } });
    return aChofer(rows[0]);
  } catch (error: unknown) {
    if (typeof error === 'object' && error !== null && 'code' in error && (error as { code?: string }).code === '23505') {
      throw new ApiError(409, 'El usuario o correo ya está registrado.');
    }
    throw error;
  }
}

async function enTransaccion<T>(operacion: (cliente: PoolClient) => Promise<T>): Promise<T> {
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    const resultado = await operacion(cliente);
    await cliente.query('COMMIT');
    return resultado;
  } catch (error) {
    await cliente.query('ROLLBACK');
    throw error;
  } finally {
    cliente.release();
  }
}

export async function cambiarEstado(id: string, activo: boolean, motivo: string, actorId: string): Promise<ChoferAdministrable> {
  const resultado = await enTransaccion(async (cliente) => {
    const actual = await cliente.query<FilaChofer>("SELECT *, xmin::text AS version, NULL::timestamptz AS ultima_actividad FROM usuarios WHERE id=$1 AND rol='chofer' FOR UPDATE", [id]);
    const objetivo = actual.rows[0];
    if (!objetivo) throw new ApiError(404, 'Chofer no encontrado.');
    if (objetivo.activo === activo) throw new ApiError(409, activo ? 'La cuenta ya está activa.' : 'La cuenta ya está inactiva.');
    const actualizado = await cliente.query<FilaChofer>(
      `UPDATE usuarios SET activo=$1, token_version=token_version+1 WHERE id=$2
       RETURNING id, usuario, nombre, apellido_paterno, apellido_materno, correo,
                 fecha_nacimiento, rol, activo, creado_en, xmin::text AS version, NULL::timestamptz AS ultima_actividad`,
      [activo, id],
    );
    await cliente.query('UPDATE refresh_tokens SET revocado=true WHERE usuario_id=$1 AND revocado=false', [id]);
    await cliente.query(
      `INSERT INTO auditoria_acciones(usuario_id,accion,entidad,entidad_id,detalle)
       VALUES($1,$2,'usuario',$3,$4::jsonb)`,
      [actorId, activo ? 'chofer_reactivado' : 'chofer_desactivado', id, JSON.stringify({ motivo, estadoAnterior: objetivo.activo, estadoNuevo: activo })],
    );
    return aChofer(actualizado.rows[0]!);
  });
  return resultado;
}

export async function solicitarReset(id: string, motivo: string, actorId: string): Promise<void> {
  const objetivo = await pool.query("SELECT 1 FROM usuarios WHERE id=$1 AND rol='chofer'", [id]);
  if (!objetivo.rows[0]) throw new ApiError(404, 'Chofer no encontrado.');
  await registrarAuditoria({ usuarioId: actorId, accion: 'chofer_reset_password', entidad: 'usuario', entidadId: id, detalle: { motivo, estado: 'pendiente_configuracion' } });
}

async function relacionesHistoricas(cliente: PoolClient, id: string): Promise<Record<string, number>> {
  const fks = await cliente.query<{ table_name: string; column_name: string }>(`
    SELECT tc.table_name, kcu.column_name
      FROM information_schema.table_constraints tc
      JOIN information_schema.key_column_usage kcu USING (constraint_catalog,constraint_schema,constraint_name)
      JOIN information_schema.constraint_column_usage ccu USING (constraint_catalog,constraint_schema,constraint_name)
     WHERE tc.constraint_type='FOREIGN KEY' AND tc.table_schema='public'
       AND ccu.table_name='usuarios' AND tc.table_name <> 'refresh_tokens'`);
  const conteos: Record<string, number> = {};
  for (const fk of fks.rows) {
    const tabla = `"${fk.table_name.replaceAll('"', '""')}"`;
    const columna = `"${fk.column_name.replaceAll('"', '""')}"`;
    const resultado = await cliente.query<{ total: number }>(`SELECT count(*)::int total FROM ${tabla} WHERE ${columna}=$1`, [id]);
    conteos[`${fk.table_name}.${fk.column_name}`] = resultado.rows[0]?.total ?? 0;
  }
  const objetivoAuditado = await cliente.query<{ total: number }>("SELECT count(*)::int total FROM auditoria_acciones WHERE entidad='usuario' AND entidad_id=$1", [id]);
  conteos['auditoria_acciones.entidad_id'] = objetivoAuditado.rows[0]?.total ?? 0;
  return conteos;
}

export async function elegibilidadEliminacion(id: string): Promise<{ elegible: boolean; tieneRelaciones: boolean }> {
  return enTransaccion(async (cliente) => {
    const usuario = await cliente.query("SELECT activo FROM usuarios WHERE id=$1 AND rol='chofer' FOR KEY SHARE", [id]);
    if (!usuario.rows[0]) throw new ApiError(404, 'Chofer no encontrado.');
    const conteos = await relacionesHistoricas(cliente, id);
    const tieneRelaciones = Object.values(conteos).some((total) => total > 0);
    return { elegible: !usuario.rows[0].activo && !tieneRelaciones, tieneRelaciones };
  });
}

export async function eliminarDefinitivamente(id: string, usuarioConfirmado: string, motivo: string, actorId: string): Promise<void> {
  await enTransaccion(async (cliente) => {
    const usuario = await cliente.query<{ usuario: string; activo: boolean }>("SELECT usuario, activo FROM usuarios WHERE id=$1 AND rol='chofer' FOR UPDATE", [id]);
    const objetivo = usuario.rows[0];
    if (!objetivo) throw new ApiError(404, 'Chofer no encontrado.');
    if (objetivo.activo) throw new ApiError(409, 'Primero debes desactivar la cuenta.');
    if (`@${objetivo.usuario}` !== usuarioConfirmado) throw new ApiError(400, 'La confirmación no coincide con el nombre de usuario.');
    const conteos = await relacionesHistoricas(cliente, id);
    if (Object.values(conteos).some((total) => total > 0)) {
      throw new ApiError(409, 'La cuenta tiene historial relacionado y solo puede desactivarse.');
    }
    await cliente.query('DELETE FROM refresh_tokens WHERE usuario_id=$1', [id]);
    await cliente.query(
      `INSERT INTO auditoria_acciones(usuario_id,accion,entidad,entidad_id,detalle)
       VALUES($1,'chofer_eliminado','usuario',$2,$3::jsonb)`,
      [actorId, id, JSON.stringify({ usuario: objetivo.usuario, motivo })],
    );
    await cliente.query("DELETE FROM usuarios WHERE id=$1 AND rol='chofer'", [id]);
  });
}
