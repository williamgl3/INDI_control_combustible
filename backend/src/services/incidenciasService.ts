import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import { registrarAuditoria } from './auditoriaService';
import type { EstadoIncidencia, IncidenciaVehiculo } from '../types';

interface FilaIncidencia {
  id: string;
  vehiculo_id: string;
  chofer_id: string;
  descripcion: string;
  estado: EstadoIncidencia;
  resuelta_por: string | null;
  comentario_resolucion: string | null;
  creada_en: Date;
  resuelta_en: Date | null;
  foto_path: string | null;
}

function aIncidencia(fila: FilaIncidencia): IncidenciaVehiculo {
  return {
    id: fila.id,
    vehiculoId: fila.vehiculo_id,
    choferId: fila.chofer_id,
    descripcion: fila.descripcion,
    estado: fila.estado,
    resueltaPor: fila.resuelta_por,
    comentarioResolucion: fila.comentario_resolucion,
    creadaEn: fila.creada_en.toISOString(),
    resueltaEn: fila.resuelta_en?.toISOString() ?? null,
    fotoPath: fila.foto_path,
  };
}

export async function listarTodas(): Promise<IncidenciaVehiculo[]> {
  const { rows } = await pool.query<FilaIncidencia>(
    'SELECT * FROM incidencias_vehiculo ORDER BY creada_en DESC',
  );
  return rows.map(aIncidencia);
}

export async function listarDeChofer(choferId: string): Promise<IncidenciaVehiculo[]> {
  const { rows } = await pool.query<FilaIncidencia>(
    'SELECT * FROM incidencias_vehiculo WHERE chofer_id = $1 ORDER BY creada_en DESC',
    [choferId],
  );
  return rows.map(aIncidencia);
}

export async function reportar(datos: {
  vehiculoId: string;
  choferId: string;
  descripcion: string;
  fotoPath?: string | null | undefined;
}): Promise<IncidenciaVehiculo> {
  const { rows } = await pool.query<FilaIncidencia>(
    `INSERT INTO incidencias_vehiculo (vehiculo_id, chofer_id, descripcion, foto_path)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [datos.vehiculoId, datos.choferId, datos.descripcion, datos.fotoPath ?? null],
  );
  return aIncidencia(rows[0]!);
}

export async function resolver(
  id: string,
  datos: {
    resueltaPor: string;
    resueltaPorId?: string | null | undefined;
    comentario?: string | null | undefined;
  },
): Promise<IncidenciaVehiculo> {
  const { rows } = await pool.query<FilaIncidencia>(
    `UPDATE incidencias_vehiculo
     SET estado = 'resuelta', resuelta_por = $1, comentario_resolucion = $2, resuelta_en = now()
     WHERE id = $3
     RETURNING *`,
    [datos.resueltaPor, datos.comentario ?? null, id],
  );
  const fila = rows[0];
  if (!fila) throw new ApiError(404, 'Incidencia no encontrada.');
  const incidencia = aIncidencia(fila);

  void registrarAuditoria({
    usuarioId: datos.resueltaPorId,
    accion: 'resolver_incidencia',
    entidad: 'incidencia_vehiculo',
    entidadId: id,
    detalle: { comentario: datos.comentario ?? null },
  });

  return incidencia;
}
