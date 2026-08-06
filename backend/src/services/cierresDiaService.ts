import { pool } from '../db/pool';
import { buscarCargaPorId } from './cargasService';
import type { CierreDia } from '../types';

interface FilaCierre {
  id: string;
  chofer_id: string;
  carga_id: string;
  km_final: string;
  foto_tablero_path: string;
  registrada_en: Date;
}

function aCierre(fila: FilaCierre): CierreDia {
  return {
    id: fila.id,
    choferId: fila.chofer_id,
    cargaId: fila.carga_id,
    kmFinal: Number(fila.km_final),
    fotoTableroPath: fila.foto_tablero_path,
    registradaEn: fila.registrada_en.toISOString(),
  };
}

export async function cerrarDia(datos: {
  choferId: string;
  cargaId: string;
  kmFinal: number;
  fotoTableroPath: string;
}): Promise<CierreDia> {
  const { rows } = await pool.query<FilaCierre>(
    `INSERT INTO cierres_dia (chofer_id, carga_id, km_final, foto_tablero_path)
     VALUES ($1, $2, $3, $4)
     RETURNING *`,
    [datos.choferId, datos.cargaId, datos.kmFinal, datos.fotoTableroPath],
  );
  return aCierre(rows[0]!);
}

export async function listarCierresDeChofer(choferId: string): Promise<CierreDia[]> {
  const { rows } = await pool.query<FilaCierre>(
    'SELECT * FROM cierres_dia WHERE chofer_id = $1 ORDER BY registrada_en DESC',
    [choferId],
  );
  return rows.map(aCierre);
}

/// Todos los cierres de todos los choferes — panel administrativo
/// (`ConcentradoTab` necesita el cierre de CUALQUIER carga, no solo las
/// propias, para calcular el rendimiento de cada fila).
export async function listarTodosLosCierres(): Promise<CierreDia[]> {
  const { rows } = await pool.query<FilaCierre>('SELECT * FROM cierres_dia ORDER BY registrada_en DESC');
  return rows.map(aCierre);
}

export async function buscarCierrePorCarga(cargaId: string): Promise<CierreDia | null> {
  const { rows } = await pool.query<FilaCierre>('SELECT * FROM cierres_dia WHERE carga_id = $1', [
    cargaId,
  ]);
  return rows[0] ? aCierre(rows[0]) : null;
}

export interface RendimientoDia {
  kmRecorridos: number;
  rendimiento: number | null;
  esAnomalo: boolean;
}

/// Réplica de `RendimientoDia`/`rendimientoDe` en
/// `mock_operaciones_repository.dart`. El umbral de anomalía
/// (&lt;2 o &gt;15 km/L) es TODO-SPEC ahí también — placeholder, no un
/// valor de negocio confirmado.
export async function rendimientoDe(cierre: CierreDia): Promise<RendimientoDia | null> {
  const carga = await buscarCargaPorId(cierre.cargaId);
  if (!carga) return null;

  const kmRecorridos = cierre.kmFinal - carga.kmAlCargar;
  if (kmRecorridos <= 0) {
    return { kmRecorridos: 0, rendimiento: null, esAnomalo: false };
  }
  const rendimiento = kmRecorridos / carga.litrosCargados;
  return {
    kmRecorridos,
    rendimiento,
    esAnomalo: rendimiento < 2 || rendimiento > 15,
  };
}

/// Historial de lecturas del medidor (km u horómetro) de un vehículo,
/// ordenado ascendente por fecha — junta las lecturas de `cargas`
/// (km_al_cargar) y `cierres_dia` (km_final) de ese vehículo. Usado por
/// el módulo de Mantenimiento preventivo.
export async function historialLecturas(
  vehiculoId: string,
): Promise<Array<{ fecha: string; lectura: number }>> {
  const { rows } = await pool.query<{ fecha: Date; lectura: string }>(
    `SELECT c.creada_en AS fecha, c.km_al_cargar AS lectura
     FROM cargas c
     WHERE c.vehiculo_id = $1
     UNION ALL
     SELECT cd.registrada_en AS fecha, cd.km_final AS lectura
     FROM cierres_dia cd
     JOIN cargas c ON c.id = cd.carga_id
     WHERE c.vehiculo_id = $1
     ORDER BY fecha`,
    [vehiculoId],
  );
  return rows.map((r) => ({ fecha: r.fecha.toISOString(), lectura: Number(r.lectura) }));
}
