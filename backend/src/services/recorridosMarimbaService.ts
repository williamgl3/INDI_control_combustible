import Decimal from 'decimal.js';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import type { RecorridoMarimba, EstadoRecorridoMarimba } from '../types';
import * as despachosMarimbaService from './despachosMarimbaService';
import { registrarAuditoria } from './auditoriaService';

interface FilaRecorrido {
  id: string;
  marimba_id: string;
  operador_id: string;
  frente: string;
  carga_id: string | null;
  litros_iniciales: string;
  km_inicio: string | null;
  km_cierre: string | null;
  horas_equipo_menor_inicio: string | null;
  horas_equipo_menor_cierre: string | null;
  estado: EstadoRecorridoMarimba;
  litros_despachados_total: string | null;
  existencia_calculada: string | null;
  diferencia_conciliacion: string | null;
  tolerancia_usada: string | null;
  requiere_revision: boolean;
  foto_cierre_path: string | null;
  iniciado_en: Date;
  cerrado_en: Date | null;
}

function aNumeroONull(valor: string | null): number | null {
  return valor === null ? null : Number(valor);
}

function aRecorrido(fila: FilaRecorrido): RecorridoMarimba {
  return {
    id: fila.id,
    marimbaId: fila.marimba_id,
    operadorId: fila.operador_id,
    frente: fila.frente,
    cargaId: fila.carga_id,
    litrosIniciales: Number(fila.litros_iniciales),
    kmInicio: aNumeroONull(fila.km_inicio),
    kmCierre: aNumeroONull(fila.km_cierre),
    horasEquipoMenorInicio: aNumeroONull(fila.horas_equipo_menor_inicio),
    horasEquipoMenorCierre: aNumeroONull(fila.horas_equipo_menor_cierre),
    estado: fila.estado,
    litrosDespachadosTotal: aNumeroONull(fila.litros_despachados_total),
    existenciaCalculada: aNumeroONull(fila.existencia_calculada),
    diferenciaConciliacion: aNumeroONull(fila.diferencia_conciliacion),
    toleranciaUsada: aNumeroONull(fila.tolerancia_usada),
    requiereRevision: fila.requiere_revision,
    fotoCierrePath: fila.foto_cierre_path,
    iniciadoEn: fila.iniciado_en.toISOString(),
    cerradoEn: fila.cerrado_en?.toISOString() ?? null,
  };
}

async function toleranciaVigente(): Promise<Decimal> {
  const { rows } = await pool.query<{ valor: string }>(
    "SELECT valor FROM configuracion WHERE clave = 'tolerancia_merma_marimba_litros'",
  );
  return rows[0] ? new Decimal(rows[0].valor) : new Decimal(0);
}

export async function buscarRecorridoPorId(id: string): Promise<RecorridoMarimba | null> {
  const { rows } = await pool.query<FilaRecorrido>(
    'SELECT * FROM recorridos_marimba WHERE id = $1',
    [id],
  );
  return rows[0] ? aRecorrido(rows[0]) : null;
}

/// Abre un recorrido nuevo — valida que la marimba no tenga ya uno
/// `abierto` (evita dos jornadas simultáneas de la misma unidad, que
/// haría ambigua la conciliación de litros).
export async function crearRecorrido(datos: {
  marimbaId: string;
  operadorId: string;
  frente: string;
  cargaId?: string | null | undefined;
  litrosIniciales: number;
  kmInicio?: number | null | undefined;
  horasEquipoMenorInicio?: number | null | undefined;
}): Promise<RecorridoMarimba> {
  const { rows: abiertos } = await pool.query<{ id: string }>(
    "SELECT id FROM recorridos_marimba WHERE marimba_id = $1 AND estado = 'abierto'",
    [datos.marimbaId],
  );
  if (abiertos[0]) {
    throw new ApiError(409, 'Esta marimba ya tiene un recorrido abierto — ciérralo antes de abrir otro.');
  }

  const { rows } = await pool.query<FilaRecorrido>(
    `INSERT INTO recorridos_marimba
       (marimba_id, operador_id, frente, carga_id, litros_iniciales, km_inicio,
        horas_equipo_menor_inicio)
     VALUES ($1, $2, $3, $4, $5, $6, $7)
     RETURNING *`,
    [
      datos.marimbaId,
      datos.operadorId,
      datos.frente,
      datos.cargaId ?? null,
      datos.litrosIniciales,
      datos.kmInicio ?? null,
      datos.horasEquipoMenorInicio ?? null,
    ],
  );
  const recorrido = aRecorrido(rows[0]!);

  void registrarAuditoria({
    usuarioId: datos.operadorId,
    accion: 'abrir_recorrido_marimba',
    entidad: 'recorrido_marimba',
    entidadId: recorrido.id,
    detalle: { marimbaId: datos.marimbaId, frente: datos.frente, litrosIniciales: datos.litrosIniciales },
  });

  return recorrido;
}

/// Agrega un despacho a un recorrido — delega en
/// `despachosMarimbaService.crearDespacho` (mismo lock/validación de
/// saldo, sin duplicar esa lógica), pasando el `recorridoId` para que el
/// despacho herede el frente y quede ligado a esta jornada.
export async function agregarDespacho(
  recorridoId: string,
  datos: Omit<Parameters<typeof despachosMarimbaService.crearDespacho>[0], 'recorridoId' | 'sitio'>,
) {
  return despachosMarimbaService.crearDespacho({ ...datos, recorridoId, sitio: null });
}

export async function listarRecorridos(filtros?: {
  marimbaId?: string | undefined;
  requiereRevision?: boolean | undefined;
}): Promise<RecorridoMarimba[]> {
  const condiciones: string[] = [];
  const valores: unknown[] = [];
  if (filtros?.marimbaId) {
    valores.push(filtros.marimbaId);
    condiciones.push(`marimba_id = $${valores.length}`);
  }
  if (filtros?.requiereRevision !== undefined) {
    valores.push(filtros.requiereRevision);
    condiciones.push(`requiere_revision = $${valores.length}`);
  }
  const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : '';
  const { rows } = await pool.query<FilaRecorrido>(
    `SELECT * FROM recorridos_marimba ${where} ORDER BY iniciado_en DESC`,
    valores,
  );
  return rows.map(aRecorrido);
}

/// Cierra un recorrido: calcula la conciliación (litros iniciales − suma
/// de despachos) con `Decimal` (mismo patrón que ya usa
/// `despachosMarimbaService`, nada de float nativo) y persiste el
/// resultado como snapshot inmutable — no se recalcula si la tolerancia
/// configurada cambia después.
export async function cerrarRecorrido(
  recorridoId: string,
  datos: {
    kmCierre?: number | null | undefined;
    horasEquipoMenorCierre?: number | null | undefined;
    fotoCierrePath: string;
  },
  actorId?: string | null | undefined,
): Promise<RecorridoMarimba> {
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    // Mismo advisory lock que `crearDespacho` usa por marimba — evita que
    // un despacho se inserte a mitad del cálculo de conciliación.
    const { rows: filaActual } = await cliente.query<FilaRecorrido>(
      'SELECT * FROM recorridos_marimba WHERE id = $1 FOR UPDATE',
      [recorridoId],
    );
    const actual = filaActual[0];
    if (!actual) throw new ApiError(404, 'Recorrido no encontrado.');
    if (actual.estado === 'cerrado') {
      throw new ApiError(409, 'Este recorrido ya está cerrado.');
    }
    await cliente.query('SELECT pg_advisory_xact_lock(hashtext($1))', [actual.marimba_id]);

    const totalDespachado = await despachosMarimbaService.totalDespachadoDeRecorrido(
      recorridoId,
      cliente,
    );
    const litrosIniciales = new Decimal(actual.litros_iniciales);
    const existenciaCalculada = litrosIniciales.minus(totalDespachado);
    const tolerancia = await toleranciaVigente();
    const requiereRevision = existenciaCalculada.abs().greaterThan(tolerancia);

    const { rows } = await cliente.query<FilaRecorrido>(
      `UPDATE recorridos_marimba
       SET estado = 'cerrado', km_cierre = $1, horas_equipo_menor_cierre = $2,
           foto_cierre_path = $3, litros_despachados_total = $4,
           existencia_calculada = $5, diferencia_conciliacion = $5,
           tolerancia_usada = $6, requiere_revision = $7, cerrado_en = now()
       WHERE id = $8
       RETURNING *`,
      [
        datos.kmCierre ?? null,
        datos.horasEquipoMenorCierre ?? null,
        datos.fotoCierrePath,
        totalDespachado.toString(),
        existenciaCalculada.toString(),
        tolerancia.toString(),
        requiereRevision,
        recorridoId,
      ],
    );

    await cliente.query('COMMIT');
    const recorrido = aRecorrido(rows[0]!);

    void registrarAuditoria({
      usuarioId: actorId,
      accion: 'cerrar_recorrido_marimba',
      entidad: 'recorrido_marimba',
      entidadId: recorrido.id,
      detalle: {
        litrosDespachadosTotal: totalDespachado.toString(),
        existenciaCalculada: existenciaCalculada.toString(),
        requiereRevision,
      },
    });

    return recorrido;
  } catch (err) {
    await cliente.query('ROLLBACK');
    throw err;
  } finally {
    cliente.release();
  }
}
