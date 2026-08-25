import { pool } from '../db/pool';
import type { RolUsuario } from '../types';

export interface ActorArchivo {
  id: string;
  rol: RolUsuario;
}

export interface ReferenciaArchivo {
  tipo:
    | 'solicitud'
    | 'carga_ticket'
    | 'carga_tablero'
    | 'cierre'
    | 'incidencia'
    | 'evidencia'
    | 'recorrido_cierre'
    | 'recorrido_nivel'
    | 'despacho_evidencia'
    | 'despacho_horometro'
    | 'despacho_medidor';
  propietarioId: string | null;
}

/** Acepta únicamente las dos formas internas históricas/controladas. */
export function referenciasPersistidasPara(storageKey: string): readonly string[] {
  return [`/uploads/${storageKey}`, `/archivos/${storageKey}`, storageKey];
}

/**
 * Busca metadata ya persistida por los flujos de upload del sistema.
 * `comprobantes_carga.foto_path` queda deliberadamente fuera: hoy puede
 * provenir de texto incluido por el cliente y todavía no es metadata fiable.
 */
export async function localizarReferencias(storageKey: string): Promise<ReferenciaArchivo[]> {
  const referencias = referenciasPersistidasPara(storageKey);
  const { rows } = await pool.query<{ tipo: ReferenciaArchivo['tipo']; propietario_id: string | null }>(
    `SELECT 'solicitud'::text AS tipo, s.chofer_id AS propietario_id
       FROM solicitudes_autorizacion s WHERE s.foto_tablero_path = ANY($1::text[])
     UNION ALL
     SELECT 'carga_ticket', c.chofer_id FROM cargas c WHERE c.foto_ticket_path = ANY($1::text[])
     UNION ALL
     SELECT 'carga_tablero', c.chofer_id FROM cargas c WHERE c.foto_tablero_path = ANY($1::text[])
     UNION ALL
     SELECT 'cierre', cd.chofer_id FROM cierres_dia cd WHERE cd.foto_tablero_path = ANY($1::text[])
     UNION ALL
     SELECT 'incidencia', i.chofer_id FROM incidencias_vehiculo i WHERE i.foto_path = ANY($1::text[])
     UNION ALL
     SELECT 'evidencia', e.usuario_id FROM evidencias e
      WHERE e.foto_url = ANY($1::text[]) OR e.foto_urls && $1::text[]
     UNION ALL
     SELECT 'recorrido_cierre', r.operador_id FROM recorridos_marimba r
      WHERE r.foto_cierre_path = ANY($1::text[])
     UNION ALL
     SELECT 'recorrido_nivel', r.operador_id FROM recorridos_marimba r
      WHERE r.foto_nivel_path = ANY($1::text[])
     UNION ALL
     SELECT 'despacho_evidencia', r.operador_id
       FROM despachos_marimba d
       LEFT JOIN recorridos_marimba r ON r.id = d.recorrido_id
      WHERE d.foto_evidencia_path = ANY($1::text[])
     UNION ALL
     SELECT 'despacho_horometro', r.operador_id
       FROM despachos_marimba d
       LEFT JOIN recorridos_marimba r ON r.id = d.recorrido_id
      WHERE d.foto_horometro_path = ANY($1::text[])
     UNION ALL
     SELECT 'despacho_medidor', r.operador_id
       FROM despachos_marimba d
       LEFT JOIN recorridos_marimba r ON r.id = d.recorrido_id
      WHERE d.foto_medidor_path = ANY($1::text[])`,
    [referencias],
  );
  return rows.map((fila) => ({ tipo: fila.tipo, propietarioId: fila.propietario_id }));
}

export function puedeLeerArchivo(actor: ActorArchivo, referencias: readonly ReferenciaArchivo[]): boolean {
  if (actor.rol === 'administrativo' || actor.rol === 'superadmin') return true;
  if (actor.rol === 'supervisor') {
    return referencias.some((referencia) => referencia.propietarioId === actor.id);
  }
  if (actor.rol === 'chofer') {
    return referencias.some((referencia) =>
      referencia.propietarioId === actor.id &&
      !referencia.tipo.startsWith('recorrido_') &&
      !referencia.tipo.startsWith('despacho_'));
  }
  return false;
}
