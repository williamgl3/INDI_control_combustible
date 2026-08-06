import Decimal from 'decimal.js';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import { registrarAuditoria } from './auditoriaService';
import type { PrecioCombustible } from '../types';

interface FilaPrecio {
  id: string;
  tipo_combustible: string;
  precio_por_litro: string;
  vigente_desde: Date;
  registrado_por: string | null;
  creado_en: Date;
}

/// El contrato JSON hacia el frontend no cambia (`tipoCombustible`,
/// `precioPorLitro`, `actualizadoEn`) aunque el modelo interno sí — así
/// ningún cliente existente (Finanzas, la comparación de discrepancia del
/// chofer) necesita cambios por esta migración. `actualizadoEn` ahora
/// refleja `vigente_desde` (cuándo empezó a aplicar este precio), que es
/// semánticamente más correcto que el viejo `actualizado_en` de una fila
/// que se sobreescribía.
function aPrecio(fila: FilaPrecio): PrecioCombustible {
  return {
    tipoCombustible: fila.tipo_combustible,
    precioPorLitro: Number(fila.precio_por_litro),
    actualizadoEn: fila.vigente_desde.toISOString(),
  };
}

export interface RegistroHistoricoPrecio {
  id: string;
  tipoCombustible: string;
  precioPorLitro: number;
  vigenteDesde: string;
  registradoPor: string | null;
  creadoEn: string;
}

function aRegistroHistorico(fila: FilaPrecio): RegistroHistoricoPrecio {
  return {
    id: fila.id,
    tipoCombustible: fila.tipo_combustible,
    precioPorLitro: Number(fila.precio_por_litro),
    vigenteDesde: fila.vigente_desde.toISOString(),
    registradoPor: fila.registrado_por,
    creadoEn: fila.creado_en.toISOString(),
  };
}

/// Solo el precio VIGENTE de cada tipo (el de mayor `vigente_desde`) —
/// para la vista simple del admin en Finanzas. Ver [historialDe] para el
/// histórico completo de un tipo.
export async function listarPrecios(): Promise<PrecioCombustible[]> {
  const { rows } = await pool.query<FilaPrecio>(
    `SELECT DISTINCT ON (tipo_combustible) *
     FROM precios_combustible
     ORDER BY tipo_combustible, vigente_desde DESC`,
  );
  return rows.map(aPrecio);
}

/// Histórico completo de un tipo de combustible, más reciente primero —
/// para el detalle desplegable de Finanzas (quién cambió qué y cuándo).
export async function historialDe(tipoCombustible: string): Promise<RegistroHistoricoPrecio[]> {
  const { rows } = await pool.query<FilaPrecio>(
    'SELECT * FROM precios_combustible WHERE tipo_combustible = $1 ORDER BY vigente_desde DESC',
    [tipoCombustible],
  );
  return rows.map(aRegistroHistorico);
}

export async function precioDe(tipoCombustible: string, fecha: Date): Promise<number> {
  return (await precioDeDecimal(tipoCombustible, fecha)).toNumber();
}

/// Precio VIGENTE de [tipoCombustible] en [fecha] — nunca "el precio de
/// hoy" implícito, para que un cálculo sobre una carga vieja siga usando
/// el precio que aplicaba entonces aunque hoy ya haya cambiado.
///
/// Antes, si no había fila para el tipo pedido, caía silenciosamente al
/// primer precio de la lista (de OTRO tipo de combustible) — ese
/// fallback ya causó un bug real (ver migración 0029) y no vuelve: si no
/// hay precio vigente configurado para ESE tipo en esa fecha, se lanza
/// un error explícito. Los llamadores con un tipo potencialmente `null`
/// (unidad sin combustible confirmado) deben verificarlo ANTES de llamar
/// esta función — nunca se le pasa `null` (ver `solicitudesService.
/// enviarSolicitud`, `cargasService.registrarCarga`,
/// `despachosMarimbaService.registrarDespacho`).
///
/// `Decimal` de punta a punta — ver comentario histórico de esta función:
/// convertir a `number` de JS antes de multiplicar/sumar reintroduce el
/// error de precisión de punto flotante que se busca evitar.
export async function precioDeDecimal(tipoCombustible: string, fecha: Date): Promise<Decimal> {
  const { rows } = await pool.query<FilaPrecio>(
    `SELECT * FROM precios_combustible
     WHERE tipo_combustible = $1 AND vigente_desde <= $2
     ORDER BY vigente_desde DESC
     LIMIT 1`,
    [tipoCombustible, fecha],
  );
  if (!rows[0]) {
    throw new ApiError(
      409,
      `No hay precio vigente configurado para ${tipoCombustible} — pide a un administrativo que lo capture antes de continuar.`,
    );
  }
  return new Decimal(rows[0].precio_por_litro);
}

/// Reemplaza `actualizarPrecio`: ya no es un UPDATE (perdería el precio
/// anterior), es un INSERT de un registro nuevo con `vigente_desde =
/// now()` — el histórico nunca se sobrescribe. Deliberadamente no acepta
/// una vigencia distinta a "ahora": permitir vigencia retroactiva/futura
/// desde este servicio abriría la puerta a que el admin cree
/// solapamientos confusos sin que la UI (que hoy no tiene selector de
/// fecha) lo prevenga — se deja fuera de alcance hasta que haya un caso
/// de uso real que lo pida.
export async function registrarPrecio(
  tipoCombustible: string,
  nuevoPrecio: number,
  actorId?: string | null | undefined,
): Promise<PrecioCombustible> {
  const valorAnterior = await pool
    .query<FilaPrecio>(
      `SELECT * FROM precios_combustible
       WHERE tipo_combustible = $1 AND vigente_desde <= now()
       ORDER BY vigente_desde DESC
       LIMIT 1`,
      [tipoCombustible],
    )
    .then((r) => (r.rows[0] ? Number(r.rows[0].precio_por_litro) : null));

  const { rows } = await pool.query<FilaPrecio>(
    `INSERT INTO precios_combustible (tipo_combustible, precio_por_litro, registrado_por)
     VALUES ($1, $2, $3)
     RETURNING *`,
    [tipoCombustible, nuevoPrecio, actorId ?? null],
  );
  const precio = aPrecio(rows[0]!);

  void registrarAuditoria({
    usuarioId: actorId,
    accion: 'registrar_precio',
    entidad: 'precio_combustible',
    entidadId: tipoCombustible,
    detalle: { valorAnterior, valorNuevo: nuevoPrecio, vigenteDesde: rows[0]!.vigente_desde },
  });

  return precio;
}

export async function presupuestoSemanalTotal(): Promise<number> {
  return (await presupuestoSemanalTotalDecimal()).toNumber();
}

/// Igual que [presupuestoSemanalTotal], sin pasar por `Number(...)` — ver
/// comentario de [precioDeDecimal].
export async function presupuestoSemanalTotalDecimal(): Promise<Decimal> {
  const { rows } = await pool.query<{ valor: string }>(
    "SELECT valor FROM configuracion WHERE clave = 'presupuesto_semanal_total'",
  );
  return rows[0] ? new Decimal(rows[0].valor) : new Decimal(0);
}

export async function actualizarPresupuestoSemanalTotal(
  nuevoValor: number,
  actorId?: string | null | undefined,
): Promise<number> {
  const { rows } = await pool.query<{ valor: string }>(
    `INSERT INTO configuracion (clave, valor)
     VALUES ('presupuesto_semanal_total', $1)
     ON CONFLICT (clave) DO UPDATE SET valor = $1
     RETURNING valor`,
    [nuevoValor],
  );

  void registrarAuditoria({
    usuarioId: actorId,
    accion: 'editar_presupuesto_semanal',
    entidad: 'configuracion',
    entidadId: 'presupuesto_semanal_total',
    detalle: { nuevoValor },
  });

  return Number(rows[0]!.valor);
}
