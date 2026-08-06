import Decimal from 'decimal.js';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import { logger } from '../utils/logger';
import type { DespachoMarimba, EstadoDespacho } from '../types';
import * as preciosService from './preciosService';
import { registrarAuditoria } from './auditoriaService';

interface FilaDespacho {
  id: string;
  marimba_id: string;
  vehiculo_destino_id: string | null;
  destino_texto: string | null;
  operador_texto: string;
  residente_texto: string | null;
  sitio: string | null;
  litros_solicitados: string | null;
  litros_suministrados: string;
  lectura_medidor: string | null;
  precio_referencia_usado: string | null;
  estado: EstadoDespacho;
  foto_evidencia_path: string | null;
  registrado_por: string;
  creado_en: Date;
  recorrido_id: string | null;
}

function aDespacho(fila: FilaDespacho): DespachoMarimba {
  return {
    id: fila.id,
    marimbaId: fila.marimba_id,
    vehiculoDestinoId: fila.vehiculo_destino_id,
    destinoTexto: fila.destino_texto,
    operadorTexto: fila.operador_texto,
    residenteTexto: fila.residente_texto,
    sitio: fila.sitio,
    litrosSolicitados: fila.litros_solicitados === null ? null : Number(fila.litros_solicitados),
    litrosSuministrados: Number(fila.litros_suministrados),
    lecturaMedidor: fila.lectura_medidor === null ? null : Number(fila.lectura_medidor),
    precioReferenciaUsado:
      fila.precio_referencia_usado === null ? null : Number(fila.precio_referencia_usado),
    estado: fila.estado,
    fotoEvidenciaPath: fila.foto_evidencia_path,
    registradoPor: fila.registrado_por,
    creadoEn: fila.creado_en.toISOString(),
    recorridoId: fila.recorrido_id,
  };
}

/// Saldo actual del libro mayor de la marimba (entradas por carga −
/// salidas por despacho) — nunca se reinicia por carga ni por jornada.
/// Puede llamarse dentro de una transacción ya abierta (pasando
/// `cliente`) para que la lectura participe del mismo bloqueo que la
/// inserción.
export async function saldoDeMarimba(
  marimbaId: string,
  cliente: { query: typeof pool.query } = pool,
): Promise<Decimal> {
  const { rows } = await cliente.query<{ saldo_actual: string | null }>(
    'SELECT saldo_actual FROM saldo_marimba WHERE marimba_id = $1',
    [marimbaId],
  );
  return new Decimal(rows[0]?.saldo_actual ?? 0);
}

export async function crearDespacho(datos: {
  marimbaId: string;
  vehiculoDestinoId?: string | null | undefined;
  destinoTexto?: string | null | undefined;
  operadorTexto: string;
  residenteTexto?: string | null | undefined;
  sitio?: string | null | undefined;
  litrosSolicitados?: number | null | undefined;
  litrosSuministrados: number;
  lecturaMedidor?: number | null | undefined;
  estado?: EstadoDespacho | undefined;
  fotoEvidenciaPath?: string | null | undefined;
  registradoPor: string;
  recorridoId?: string | null | undefined;
}): Promise<DespachoMarimba> {
  if (!datos.vehiculoDestinoId && !datos.destinoTexto) {
    throw new ApiError(400, 'Indica la unidad destino (del catálogo o como texto).');
  }
  if (!datos.recorridoId && !datos.sitio) {
    throw new ApiError(400, 'Indica el sitio o frente de trabajo.');
  }

  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    // Advisory lock por marimba: `saldo_marimba` es una vista sobre un
    // UNION de dos tablas, no se puede hacer `SELECT ... FOR UPDATE`
    // directo sobre ella — este lock serializa despachos concurrentes de
    // la MISMA marimba (relevante al sincronizar varios despachos
    // encolados offline a la vez) sin bloquear despachos de otras
    // marimbas.
    await cliente.query('SELECT pg_advisory_xact_lock(hashtext($1))', [datos.marimbaId]);

    // El sitio se hereda del recorrido (frente único de la jornada) si no
    // se manda explícito — se guarda denormalizado en el propio despacho
    // para no romper ninguna lectura existente que espera `sitio` lleno.
    let sitio = datos.sitio ?? null;
    if (!sitio && datos.recorridoId) {
      const { rows: filaRecorrido } = await cliente.query<{
        frente: string;
        estado: string;
      }>('SELECT frente, estado FROM recorridos_marimba WHERE id = $1', [datos.recorridoId]);
      if (!filaRecorrido[0]) {
        throw new ApiError(404, 'El recorrido indicado no existe.');
      }
      if (filaRecorrido[0].estado !== 'abierto') {
        throw new ApiError(409, 'Este recorrido ya está cerrado — no admite más despachos.');
      }
      sitio = filaRecorrido[0].frente;
    }

    const litrosSuministrados = new Decimal(datos.litrosSuministrados);
    if (litrosSuministrados.greaterThan(0)) {
      const saldo = await saldoDeMarimba(datos.marimbaId, cliente);
      if (litrosSuministrados.greaterThan(saldo)) {
        throw new ApiError(
          409,
          `Saldo insuficiente en la marimba: hay ${saldo.toFixed(2)} L disponibles, se intentó despachar ${litrosSuministrados.toFixed(2)} L.`,
        );
      }
    }

    // Precio de referencia (Finanzas), snapshot al momento del despacho —
    // no el costo real pagado en la carga: el saldo de la marimba mezcla
    // combustible de varias cargas a distinto precio, así que "el costo
    // real de este litro" no es una pregunta con una sola respuesta (ver
    // decisión de diseño). Se toma del tipo de combustible de la MARIMBA
    // misma, no un valor fijo.
    const { rows: filaMarimba } = await cliente.query<{ tipo_combustible: string | null }>(
      'SELECT tipo_combustible FROM vehiculos WHERE id = $1',
      [datos.marimbaId],
    );
    const combustibleMarimba = filaMarimba[0]?.tipo_combustible;
    // El ternario ya cubre el caso "sin tipoCombustible confirmado" (no
    // llama a precioDeDecimal con null, nunca lanza por eso). El
    // `.catch` de abajo solo puede atrapar el otro caso: tipo definido
    // pero sin precio vigente configurado (ej. Premium) — eso sí es una
    // configuración faltante que alguien debería ver, así que ya no se
    // descarta en silencio (antes: `.catch(() => null)` sin rastro). No
    // se bloquea el despacho físico por un dato contable faltante — el
    // combustible ya está en el tanque de la marimba — pero queda en
    // logs para que se note y se complete el precio.
    const precioReferencia = combustibleMarimba
      ? await preciosService.precioDeDecimal(combustibleMarimba, new Date()).catch((e: Error) => {
          logger.warn(
            { marimbaId: datos.marimbaId, combustibleMarimba, error: e.message },
            'Despacho sin precio de referencia — falta configurar el precio de este combustible.',
          );
          return null;
        })
      : null;

    const { rows } = await cliente.query<FilaDespacho>(
      `INSERT INTO despachos_marimba
         (marimba_id, vehiculo_destino_id, destino_texto, operador_texto, residente_texto,
          sitio, litros_solicitados, litros_suministrados, lectura_medidor,
          precio_referencia_usado, estado, foto_evidencia_path, registrado_por, recorrido_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
       RETURNING *`,
      [
        datos.marimbaId,
        datos.vehiculoDestinoId ?? null,
        datos.destinoTexto ?? null,
        datos.operadorTexto,
        datos.residenteTexto ?? null,
        sitio,
        datos.litrosSolicitados ?? null,
        litrosSuministrados.toString(),
        datos.lecturaMedidor ?? null,
        precioReferencia?.toString() ?? null,
        datos.estado ?? 'activo',
        datos.fotoEvidenciaPath ?? null,
        datos.registradoPor,
        datos.recorridoId ?? null,
      ],
    );

    await cliente.query('COMMIT');
    const despacho = aDespacho(rows[0]!);

    void registrarAuditoria({
      usuarioId: datos.registradoPor,
      accion: 'registrar_despacho_marimba',
      entidad: 'despacho_marimba',
      entidadId: despacho.id,
      detalle: { marimbaId: datos.marimbaId, litros: litrosSuministrados.toString() },
    });

    return despacho;
  } catch (err) {
    await cliente.query('ROLLBACK');
    throw err;
  } finally {
    cliente.release();
  }
}

export async function listarDespachosDeMarimba(marimbaId: string): Promise<DespachoMarimba[]> {
  const { rows } = await pool.query<FilaDespacho>(
    'SELECT * FROM despachos_marimba WHERE marimba_id = $1 ORDER BY creado_en DESC',
    [marimbaId],
  );
  return rows.map(aDespacho);
}

export async function listarDespachosDeRecorrido(recorridoId: string): Promise<DespachoMarimba[]> {
  const { rows } = await pool.query<FilaDespacho>(
    'SELECT * FROM despachos_marimba WHERE recorrido_id = $1 ORDER BY creado_en ASC',
    [recorridoId],
  );
  return rows.map(aDespacho);
}

/// Suma `litros_suministrados` de un recorrido con `Decimal` — se llama
/// dentro de la MISMA transacción de cierre (`cliente` ya abierto), nunca
/// como lectura suelta, para que el total no pueda cambiar entre que se
/// calcula y que se persiste el snapshot de conciliación.
export async function totalDespachadoDeRecorrido(
  recorridoId: string,
  cliente: { query: typeof pool.query },
): Promise<Decimal> {
  const { rows } = await cliente.query<{ total: string | null }>(
    'SELECT COALESCE(SUM(litros_suministrados), 0) AS total FROM despachos_marimba WHERE recorrido_id = $1',
    [recorridoId],
  );
  return new Decimal(rows[0]?.total ?? 0);
}

export async function rendimientoDeDespacho(despachoId: string): Promise<number | null> {
  const { rows } = await pool.query<{ rendimiento_l_por_hora: string | null }>(
    'SELECT rendimiento_l_por_hora FROM rendimiento_despacho WHERE despacho_id = $1',
    [despachoId],
  );
  const valor = rows[0]?.rendimiento_l_por_hora;
  return valor === null || valor === undefined ? null : Number(valor);
}
