import Decimal from 'decimal.js';
import { pool } from '../db/pool';
import { registrarAuditoria } from './auditoriaService';
import type { PoolClient } from 'pg';
import { precioDeDecimal } from './preciosService';
import { ApiError } from '../utils/asyncHandler';

// 'ticket' ya no es un tipo aparte — se unificó con 'comprobante' (ambos
// representan el mismo documento: folio, litros, precio, IVA y total de
// la gasolinera). Ver migración 0013_evidencias_comprobante_unificado.sql.
export type TipoEvidencia = 'tablero' | 'comprobante';

// Umbral de desviación contra el precio de referencia vigente que marca
// una evidencia para revisión (punto 4b) — no bloquea, solo advierte y
// deja rastro. Constante nombrada en vez de un número suelto: el precio
// SÍ varía legítimamente por estación y por día, así que este valor es
// una hipótesis inicial que se espera ajustar con datos reales de campo,
// no una regla de negocio fija.
export const UMBRAL_DESVIACION_PRECIO_REFERENCIA = 0.25;

export async function validarRelacionEvidencia(datos: {
  usuarioId: string;
  folioId?: string | null | undefined;
  cargaId?: string | null | undefined;
}): Promise<void> {
  if (!datos.folioId && !datos.cargaId) {
    throw new ApiError(400, 'La evidencia debe vincularse con una solicitud o carga propia.');
  }
  const { rows } = await pool.query<{
    solicitud_propia: boolean; carga_propia: boolean; relacion_valida: boolean;
  }>(
    `SELECT
       $2::uuid IS NULL OR EXISTS(SELECT 1 FROM solicitudes_autorizacion s WHERE s.id=$2 AND s.chofer_id=$1)
         AS solicitud_propia,
       $3::uuid IS NULL OR EXISTS(SELECT 1 FROM cargas c WHERE c.id=$3 AND c.chofer_id=$1)
         AS carga_propia,
       $2::uuid IS NULL OR $3::uuid IS NULL OR EXISTS(
         SELECT 1 FROM cargas c JOIN solicitudes_autorizacion s
           ON s.folio_autorizacion=c.folio_autorizacion
         WHERE c.id=$3 AND s.id=$2 AND c.chofer_id=$1)
         AS relacion_valida`,
    [datos.usuarioId, datos.folioId ?? null, datos.cargaId ?? null],
  );
  const validacion = rows[0];
  if (!validacion?.solicitud_propia || !validacion.carga_propia || !validacion.relacion_valida) {
    throw new ApiError(404, 'La operación relacionada no está disponible.');
  }
}

export interface Evidencia {
  id: string;
  usuarioId: string;
  tipo: TipoEvidencia;
  fotoUrl: string;
  fotoUrls: string[];
  km: number | null;
  folioId: string | null;
  /// FK opcional directa a la carga puntual que este comprobante
  /// respalda — distinto de `folioId` (que apunta a la SOLICITUD, que
  /// puede tener varias cargas). NULL hasta que exista el flujo de UI
  /// para capturarlo (ver análisis de vinculación offline pendiente) —
  /// el esquema ya lo soporta, pero nada lo llena todavía.
  cargaId: string | null;
  pendienteVincular: boolean;
  notas: string | null;
  creadoEn: string;
  // Solo pobladas cuando `tipo === 'comprobante'`.
  tipoCombustibleCargado: string | null;
  litros: number | null;
  precioPorLitro: number | null;
  montoPagado: number | null;
  /// `true` si `precioPorLitro` se desvió más de
  /// [UMBRAL_DESVIACION_PRECIO_REFERENCIA] del precio de referencia
  /// vigente al momento de subir la evidencia. No bloqueante — solo
  /// marca la evidencia para que un admin la revise después.
  requiereRevision: boolean;
  /// Se guarda el número (no solo el booleano) para poder ajustar
  /// [UMBRAL_DESVIACION_PRECIO_REFERENCIA] después sin tener que
  /// recalcular contra precios que ya cambiaron.
  desviacionPrecioPorcentaje: number | null;
  /// El precio de referencia contra el que se comparó — para poder
  /// mostrar "capturaste $X, la referencia era $Y" sin volver a
  /// consultar el histórico.
  precioReferenciaComparado: number | null;
}

interface FilaEvidencia {
  id: string;
  usuario_id: string;
  tipo: TipoEvidencia;
  foto_url: string;
  foto_urls: string[];
  km: string | null;
  folio_id: string | null;
  carga_id: string | null;
  pendiente_vincular: boolean;
  notas: string | null;
  creado_en: Date;
  tipo_combustible_cargado: string | null;
  litros: string | null;
  precio_por_litro: string | null;
  monto_pagado: string | null;
  requiere_revision: boolean;
  desviacion_precio_porcentaje: string | null;
  precio_referencia_comparado: string | null;
}

function aEvidencia(fila: FilaEvidencia): Evidencia {
  return {
    id: fila.id,
    usuarioId: fila.usuario_id,
    tipo: fila.tipo,
    fotoUrl: fila.foto_url,
    fotoUrls: fila.foto_urls,
    km: fila.km === null ? null : Number(fila.km),
    folioId: fila.folio_id,
    cargaId: fila.carga_id,
    pendienteVincular: fila.pendiente_vincular,
    notas: fila.notas,
    creadoEn: fila.creado_en.toISOString(),
    tipoCombustibleCargado: fila.tipo_combustible_cargado,
    litros: fila.litros === null ? null : Number(fila.litros),
    precioPorLitro: fila.precio_por_litro === null ? null : Number(fila.precio_por_litro),
    montoPagado: fila.monto_pagado === null ? null : Number(fila.monto_pagado),
    requiereRevision: fila.requiere_revision,
    desviacionPrecioPorcentaje:
      fila.desviacion_precio_porcentaje === null ? null : Number(fila.desviacion_precio_porcentaje),
    precioReferenciaComparado:
      fila.precio_referencia_comparado === null ? null : Number(fila.precio_referencia_comparado),
  };
}

/// Compara [precioPorLitro] contra el precio de referencia vigente de
/// [tipoCombustible] — best-effort: si no hay precio configurado para
/// ese tipo (ej. Premium sin sembrar), NO bloquea la subida de la
/// evidencia (es una acción de captura de datos, no un cálculo
/// financiero que dependa de tenerlo) — simplemente no hay nada contra
/// qué comparar todavía.
async function calcularDesviacionPrecio(
  tipoCombustible: string,
  precioPorLitro: number,
): Promise<{ requiereRevision: boolean; desviacionPorcentaje: number | null; referencia: number | null }> {
  const referenciaDecimal = await precioDeDecimal(tipoCombustible, new Date()).catch(() => null);
  if (referenciaDecimal === null) {
    return { requiereRevision: false, desviacionPorcentaje: null, referencia: null };
  }
  const referencia = referenciaDecimal.toNumber();
  const desviacion = new Decimal(precioPorLitro)
    .minus(referenciaDecimal)
    .abs()
    .dividedBy(referenciaDecimal);
  return {
    requiereRevision: desviacion.greaterThan(UMBRAL_DESVIACION_PRECIO_REFERENCIA),
    desviacionPorcentaje: desviacion.toDecimalPlaces(4).toNumber(),
    referencia,
  };
}

export async function subir(datos: {
  usuarioId: string;
  tipo: TipoEvidencia;
  fotoUrls: string[];
  km?: number | null | undefined;
  folioId?: string | null | undefined;
  cargaId?: string | null | undefined;
  pendienteVincular?: boolean | undefined;
  notas?: string | null | undefined;
  tipoCombustibleCargado?: string | null | undefined;
  litros?: number | null | undefined;
  precioPorLitro?: number | null | undefined;
  montoPagado?: number | null | undefined;
}, cliente?: PoolClient): Promise<Evidencia> {
  let requiereRevision = false;
  let desviacionPorcentaje: number | null = null;
  let precioReferenciaComparado: number | null = null;
  if (datos.tipo === 'comprobante' && datos.tipoCombustibleCargado && datos.precioPorLitro) {
    const resultado = await calcularDesviacionPrecio(
      datos.tipoCombustibleCargado,
      datos.precioPorLitro,
    );
    requiereRevision = resultado.requiereRevision;
    desviacionPorcentaje = resultado.desviacionPorcentaje;
    precioReferenciaComparado = resultado.referencia;
  }

  const { rows } = await (cliente ?? pool).query<FilaEvidencia>(
    `INSERT INTO evidencias
       (usuario_id, tipo, foto_url, foto_urls, km, folio_id, carga_id, pendiente_vincular, notas,
        tipo_combustible_cargado, litros, precio_por_litro, monto_pagado,
        requiere_revision, desviacion_precio_porcentaje, precio_referencia_comparado)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
     RETURNING *`,
    [
      datos.usuarioId,
      datos.tipo,
      datos.fotoUrls[0],
      datos.fotoUrls,
      datos.km ?? null,
      datos.folioId ?? null,
      datos.cargaId ?? null,
      datos.pendienteVincular ?? false,
      datos.notas ?? null,
      datos.tipoCombustibleCargado ?? null,
      datos.litros ?? null,
      datos.precioPorLitro ?? null,
      datos.montoPagado ?? null,
      requiereRevision,
      desviacionPorcentaje,
      precioReferenciaComparado,
    ],
  );

  const evidencia = aEvidencia(rows[0]!);

  const auditoria = registrarAuditoria({
    usuarioId: datos.usuarioId,
    accion: 'subir_evidencia',
    entidad: 'evidencias',
    entidadId: evidencia.id,
    detalle: {
      tipo: datos.tipo,
      folioId: datos.folioId ?? null,
      cargaId: datos.cargaId ?? null,
      tipoCombustibleCargado: datos.tipoCombustibleCargado ?? null,
      litros: datos.litros ?? null,
      precioPorLitro: datos.precioPorLitro ?? null,
      montoPagado: datos.montoPagado ?? null,
      // Complemento del historial (punto 4b) — la fuente de la lista de
      // pendientes es la propia fila de `evidencias`, no este log.
      requiereRevision,
      desviacionPorcentaje,
    },
  }, cliente);
  if (cliente) await auditoria;

  return evidencia;
}

export async function listarDeUsuario(usuarioId: string): Promise<Evidencia[]> {
  const { rows } = await pool.query<FilaEvidencia>(
    'SELECT * FROM evidencias WHERE usuario_id = $1 ORDER BY creado_en DESC',
    [usuarioId],
  );
  return rows.map(aEvidencia);
}

/// Todas las evidencias, para el panel administrativo — hoy usado por el
/// reporte de Concentrado para resolver el gasto real de una carga (ver
/// `concentrado_tab.dart`). Sin filtros por ahora, mismo criterio que
/// `cargasService.listarTodasLasCargas`/`solicitudesService.
/// listarTodasLasSolicitudes` sin opciones: trae todo, sin límite.
export async function listarTodas(): Promise<Evidencia[]> {
  const { rows } = await pool.query<FilaEvidencia>(
    'SELECT * FROM evidencias ORDER BY creado_en DESC',
  );
  return rows.map(aEvidencia);
}
