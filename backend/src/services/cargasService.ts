import Decimal from 'decimal.js';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import { registrarAuditoria } from './auditoriaService';
import { precioDeDecimal } from './preciosService';
import { buscarVehiculoPorId } from './vehiculosService';
import type { Carga } from '../types';

interface FilaCarga {
  id: string;
  chofer_id: string;
  vehiculo_id: string;
  folio_autorizacion: string;
  folios_adicionales: string[];
  litros_cargados: string;
  km_al_cargar: string;
  gasolinera: string;
  foto_ticket_path: string | null;
  foto_tablero_path: string | null;
  litros_detectados_ocr: string | null;
  pendiente_de_sincronizar: boolean;
  creada_en: Date;
  precio_referencia_por_litro: string | null;
  costo_referencia: string | null;
}

function aCarga(fila: FilaCarga): Carga {
  return {
    id: fila.id,
    choferId: fila.chofer_id,
    vehiculoId: fila.vehiculo_id,
    folioAutorizacion: fila.folio_autorizacion,
    foliosAdicionales: fila.folios_adicionales,
    litrosCargados: Number(fila.litros_cargados),
    kmAlCargar: Number(fila.km_al_cargar),
    gasolinera: fila.gasolinera,
    fotoTicketPath: fila.foto_ticket_path,
    fotoTableroPath: fila.foto_tablero_path,
    litrosDetectadosOcr: fila.litros_detectados_ocr === null ? null : Number(fila.litros_detectados_ocr),
    pendienteDeSincronizar: fila.pendiente_de_sincronizar,
    creadaEn: fila.creada_en.toISOString(),
    precioReferenciaPorLitro:
      fila.precio_referencia_por_litro === null ? null : Number(fila.precio_referencia_por_litro),
    costoReferencia: fila.costo_referencia === null ? null : Number(fila.costo_referencia),
  };
}

export async function registrarCarga(datos: {
  choferId: string;
  vehiculoId: string;
  folioAutorizacion: string;
  /// Folios extra de la misma visita (ej. carga a granel de la marimba) —
  /// vacío para el flujo normal de 1 chofer / 1 folio.
  foliosAdicionales?: string[] | undefined;
  litrosCargados: number;
  kmAlCargar: number;
  gasolinera: string;
  fotoTicketPath?: string | null | undefined;
  fotoTableroPath?: string | null | undefined;
  litrosDetectadosOcr?: number | null | undefined;
}): Promise<Carga> {
  // Snapshot de referencia — mismo patrón que `solicitudesService.
  // enviarSolicitud` (costoEstimado) y `despachosMarimbaService`
  // (precioReferenciaUsado): si el vehículo no tiene `tipoCombustible`
  // confirmado, queda NULL sin error (no bloquea registrar la carga);
  // si SÍ lo tiene pero no hay precio vigente configurado para ese tipo,
  // `precioDeDecimal` lanza 409 y se propaga (ver migración 0029).
  const vehiculo = await buscarVehiculoPorId(datos.vehiculoId);
  let precioReferenciaPorLitro: Decimal | null = null;
  let costoReferencia: Decimal | null = null;
  if (vehiculo?.tipoCombustible) {
    precioReferenciaPorLitro = await precioDeDecimal(vehiculo.tipoCombustible, new Date());
    costoReferencia = new Decimal(datos.litrosCargados)
      .times(precioReferenciaPorLitro)
      .toDecimalPlaces(2);
  }

  const { rows } = await pool.query<FilaCarga>(
    `INSERT INTO cargas
       (chofer_id, vehiculo_id, folio_autorizacion, folios_adicionales, litros_cargados,
        km_al_cargar, gasolinera, foto_ticket_path, foto_tablero_path, litros_detectados_ocr,
        precio_referencia_por_litro, costo_referencia)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
     RETURNING *`,
    [
      datos.choferId,
      datos.vehiculoId,
      datos.folioAutorizacion,
      datos.foliosAdicionales ?? [],
      datos.litrosCargados,
      datos.kmAlCargar,
      datos.gasolinera,
      datos.fotoTicketPath ?? null,
      datos.fotoTableroPath ?? null,
      datos.litrosDetectadosOcr ?? null,
      precioReferenciaPorLitro?.toNumber() ?? null,
      costoReferencia?.toNumber() ?? null,
    ],
  );
  return aCarga(rows[0]!);
}

export async function listarCargasDeChofer(choferId: string): Promise<Carga[]> {
  const { rows } = await pool.query<FilaCarga>(
    'SELECT * FROM cargas WHERE chofer_id = $1 ORDER BY creada_en DESC',
    [choferId],
  );
  return rows.map(aCarga);
}

/// Filtros opcionales para el panel administrativo (Concentrado) — todos
/// por defecto `undefined`, así que sin argumentos el comportamiento es
/// idéntico al de antes (trae todo, sin límite); el frontend hoy sigue
/// sin usarlos, mismo criterio que `solicitudesService.listarTodasLasSolicitudes`.
export async function listarTodasLasCargas(opciones?: {
  choferId?: string | undefined;
  vehiculoId?: string | undefined;
  desde?: string | undefined;
  hasta?: string | undefined;
  limit?: number | undefined;
  before?: string | undefined;
}): Promise<Carga[]> {
  const condiciones: string[] = [];
  const params: unknown[] = [];

  if (opciones?.choferId) {
    params.push(opciones.choferId);
    condiciones.push(`chofer_id = $${params.length}`);
  }
  if (opciones?.vehiculoId) {
    params.push(opciones.vehiculoId);
    condiciones.push(`vehiculo_id = $${params.length}`);
  }
  if (opciones?.desde) {
    params.push(opciones.desde);
    condiciones.push(`creada_en >= $${params.length}`);
  }
  if (opciones?.hasta) {
    params.push(opciones.hasta);
    condiciones.push(`creada_en <= $${params.length}`);
  }
  if (opciones?.before) {
    params.push(opciones.before);
    condiciones.push(`creada_en < $${params.length}`);
  }

  const where = condiciones.length > 0 ? `WHERE ${condiciones.join(' AND ')}` : '';
  let limitSql = '';
  if (opciones?.limit) {
    params.push(opciones.limit);
    limitSql = `LIMIT $${params.length}`;
  }

  const { rows } = await pool.query<FilaCarga>(
    `SELECT * FROM cargas ${where} ORDER BY creada_en DESC ${limitSql}`,
    params,
  );
  return rows.map(aCarga);
}

/// La carga (registro 1) de hoy que todavía no tiene su cierre (registro
/// 2), si existe. `null` si no ha cargado hoy o si su carga de hoy ya
/// quedó cerrada.
export async function cargaAbiertaDeHoy(choferId: string): Promise<Carga | null> {
  const { rows } = await pool.query<FilaCarga>(
    `SELECT c.* FROM cargas c
     LEFT JOIN cierres_dia cd ON cd.carga_id = c.id
     WHERE c.chofer_id = $1
       AND cd.id IS NULL
       AND c.creada_en::date = now()::date
     ORDER BY c.creada_en
     LIMIT 1`,
    [choferId],
  );
  return rows[0] ? aCarga(rows[0]) : null;
}

export async function buscarCargaPorId(id: string): Promise<Carga | null> {
  const { rows } = await pool.query<FilaCarga>('SELECT * FROM cargas WHERE id = $1', [id]);
  return rows[0] ? aCarga(rows[0]) : null;
}

/// Corrige litros/km de una carga YA registrada (ej. el chofer capturó mal
/// el dato) — a diferencia de `registrarCarga`, esto es una corrección
/// administrativa después del hecho, así que queda en auditoría (quién,
/// cuándo, valor anterior/nuevo) en vez de sobrescribir sin rastro.
export async function editarCarga(
  id: string,
  datos: { litrosCargados?: number | undefined; kmAlCargar?: number | undefined },
  actorId?: string | null | undefined,
): Promise<Carga> {
  const original = await buscarCargaPorId(id);
  if (!original) throw new ApiError(404, 'Carga no encontrada.');

  const litrosCargados = datos.litrosCargados ?? original.litrosCargados;
  const kmAlCargar = datos.kmAlCargar ?? original.kmAlCargar;

  const { rows } = await pool.query<FilaCarga>(
    `UPDATE cargas SET litros_cargados = $1, km_al_cargar = $2 WHERE id = $3 RETURNING *`,
    [litrosCargados, kmAlCargar, id],
  );
  const carga = aCarga(rows[0]!);

  void registrarAuditoria({
    usuarioId: actorId,
    accion: 'editar_carga',
    entidad: 'carga',
    entidadId: id,
    detalle: {
      anterior: { litrosCargados: original.litrosCargados, kmAlCargar: original.kmAlCargar },
      nuevo: { litrosCargados, kmAlCargar },
    },
  });

  return carga;
}
