import Decimal from 'decimal.js';
import type { PoolClient } from 'pg';
import { pool } from '../db/pool';
import type { RolUsuario, SolicitudAutorizacion, SolicitudPartida, TipoPartidaSolicitud } from '../types';
import { ApiError } from '../utils/asyncHandler';
import { registrarAuditoria } from './auditoriaService';

const COMBUSTIBLES_VALIDOS = new Set(['Diésel', 'Magna', 'Premium']);

function combustibleValido(valor: string): string {
  const combustible = valor.trim();
  if (!COMBUSTIBLES_VALIDOS.has(combustible)) {
    throw new ApiError(400, 'El tipo de combustible no es válido.');
  }
  return combustible;
}

export interface PartidaEntrada {
  tipo: TipoPartidaSolicitud;
  litros: number;
  tipoCombustible: string;
  observaciones?: string | null | undefined;
}

export interface PartidaCargaEntrada {
  tipo: TipoPartidaSolicitud;
  litros: number;
  tipoCombustible: string;
}

export interface ComprobanteEntrada {
  folioEstacion: string;
  concepto: TipoPartidaSolicitud | 'visita_completa';
  litrosIndicados?: number | null | undefined;
  fotoPath?: string | null | undefined;
  fecha?: string | null | undefined;
}

interface FilaPartida {
  id: string;
  solicitud_id: string;
  tipo: TipoPartidaSolicitud;
  litros_solicitados: string;
  litros_autorizados: string | null;
  litros_cargados: string;
  tipo_combustible: string;
  estado: 'pendiente' | 'aprobada' | 'rechazada';
  observaciones: string | null;
}

function aPartida(fila: FilaPartida): SolicitudPartida {
  return {
    id: fila.id,
    solicitudId: fila.solicitud_id,
    tipo: fila.tipo,
    litrosSolicitados: fila.litros_solicitados,
    litrosAutorizados: fila.litros_autorizados,
    litrosCargados: fila.litros_cargados,
    tipoCombustible: fila.tipo_combustible,
    estado: fila.estado,
    observaciones: fila.observaciones,
  };
}

const seleccionarPartidas = `
  SELECT sp.*,
         COALESCE(SUM(cp.litros_cargados), 0) AS litros_cargados
  FROM solicitud_partidas sp
  LEFT JOIN carga_partidas cp ON cp.solicitud_partida_id = sp.id
  WHERE sp.solicitud_id = $1
  GROUP BY sp.id
  ORDER BY sp.tipo`;

export async function listarPartidas(solicitudId: string, cliente?: PoolClient): Promise<SolicitudPartida[]> {
  const { rows } = await (cliente ?? pool).query<FilaPartida>(seleccionarPartidas, [solicitudId]);
  return rows.map(aPartida);
}

export function validarPartidas(partidas: PartidaEntrada[]): void {
  if (partidas.length < 1 || partidas.length > 2) {
    throw new ApiError(400, 'La solicitud debe contener una o dos partidas.');
  }
  if (new Set(partidas.map((p) => p.tipo)).size !== partidas.length) {
    throw new ApiError(400, 'No se permite repetir un concepto de combustible.');
  }
  for (const partida of partidas) {
    if (!new Decimal(partida.litros).greaterThan(0)) {
      throw new ApiError(400, 'Los litros de cada partida deben ser mayores a cero.');
    }
    combustibleValido(partida.tipoCombustible);
  }
}

export async function crearSolicitudConPartidas(datos: {
  solicitanteId: string;
  rol: RolUsuario;
  vehiculoId: string;
  partidas: PartidaEntrada[];
  actividad: string;
  fechaProgramada: string;
  esUrgente: boolean;
  motivoChofer?: string | null | undefined;
  fotoTableroPath?: string | null | undefined;
  idempotencyKey: string;
  payloadFingerprint: string;
}, clienteExterno?: PoolClient): Promise<SolicitudAutorizacion & { replayed: boolean }> {
  validarPartidas(datos.partidas);
  if (datos.rol !== 'supervisor') {
    throw new ApiError(403, 'El flujo de unidad abastecedora requiere un supervisor.');
  }
  const total = datos.partidas.reduce(
    (suma, partida) => suma.plus(partida.litros),
    new Decimal(0),
  );
  const cliente = clienteExterno ?? await pool.connect();
  const transaccionPropia = clienteExterno === undefined;
  try {
    if (transaccionPropia) await cliente.query('BEGIN');
    const { rows: historicas } = await cliente.query<Record<string, unknown>>(
      'SELECT * FROM solicitudes_autorizacion WHERE chofer_id=$1 AND idempotency_key=$2 FOR UPDATE',
      [datos.solicitanteId, datos.idempotencyKey],
    );
    if (historicas[0]) {
      const original = historicas[0];
      if (original.payload_fingerprint !== datos.payloadFingerprint) {
        throw new ApiError(409, 'La clave idempotente ya fue usada con otros datos.', {
          codigo: 'IDEMPOTENCY_KEY_PAYLOAD_MISMATCH',
        });
      }
      const respuesta = {
        id: original.id as string, choferId: original.chofer_id as string,
        vehiculoId: original.vehiculo_id as string, litrosSolicitados: Number(original.litros_solicitados),
        litrosAutorizados: original.litros_autorizados === null ? null : Number(original.litros_autorizados),
        costoEstimado: original.costo_estimado === null ? null : Number(original.costo_estimado),
        esUrgente: original.es_urgente as boolean, motivoChofer: original.motivo_chofer as string | null,
        actividad: original.actividad as string, fechaProgramada: (original.fecha_programada as Date).toISOString(),
        estado: original.estado as 'pendiente', aprobadaPor: null, folioAutorizacion: original.folio_autorizacion as string | null,
        comentario: original.comentario as string | null, creadaEn: (original.creada_en as Date).toISOString(),
        fotoTableroPath: original.foto_tablero_path as string | null,
        partidas: await listarPartidas(original.id as string, cliente), replayed: true,
      };
      if (transaccionPropia) await cliente.query('COMMIT');
      return respuesta;
    }
    const { rows: pendientes } = await cliente.query<{ id: string }>(
      `SELECT id FROM solicitudes_autorizacion
       WHERE chofer_id=$1 AND vehiculo_id=$2
         AND (fecha_programada AT TIME ZONE 'America/Mexico_City')::date =
             ($3::timestamptz AT TIME ZONE 'America/Mexico_City')::date
         AND estado='pendiente' LIMIT 1 FOR UPDATE`,
      [datos.solicitanteId, datos.vehiculoId, datos.fechaProgramada],
    );
    if (pendientes[0]) {
      throw new ApiError(409, 'Ya existe una solicitud pendiente para esta unidad y fecha.', {
        codigo: 'SOLICITUD_PENDIENTE_EXISTENTE',
        detalles: { solicitudId: pendientes[0].id },
      });
    }
    const { rows: unidades } = await cliente.query<{
      tipo_unidad: string;
      activo: boolean;
      tipo_combustible: string | null;
    }>(
      'SELECT tipo_unidad,activo,tipo_combustible FROM vehiculos WHERE id=$1 FOR UPDATE',
      [datos.vehiculoId],
    );
    const unidad = unidades[0];
    if (!unidad || !['Marimba', 'Pipa'].includes(unidad.tipo_unidad) || !unidad.activo) {
      throw new ApiError(404, 'La unidad abastecedora no está disponible.');
    }
    if (!unidad.tipo_combustible) {
      throw new ApiError(409, 'La unidad no tiene combustible de motor configurado.');
    }
    for (const partida of datos.partidas) {
      const combustible = combustibleValido(partida.tipoCombustible);
      if (partida.tipo === 'consumo_propio' && combustible !== unidad.tipo_combustible) {
        throw new ApiError(409, 'El combustible de consumo propio no coincide con el motor.');
      }
    }
    const { rows } = await cliente.query<Record<string, unknown>>(
      `INSERT INTO solicitudes_autorizacion
         (chofer_id, vehiculo_id, litros_solicitados, litros_autorizados, costo_estimado,
          es_urgente, motivo_chofer, actividad, fecha_programada, estado, comentario,
          foto_tablero_path,idempotency_key,payload_fingerprint)
       VALUES ($1,$2,$3,NULL,NULL,$4,$5,$6,$7,'pendiente',$8,$9,$10,$11)
       RETURNING *`,
      [datos.solicitanteId, datos.vehiculoId, total.toString(), datos.esUrgente,
       datos.motivoChofer ?? null, datos.actividad, datos.fechaProgramada,
       'Solicitud de unidad abastecedora pendiente de autorización por concepto.',
       datos.fotoTableroPath ?? null, datos.idempotencyKey, datos.payloadFingerprint],
    );
    const solicitud = rows[0]!;
    for (const partida of datos.partidas) {
      await cliente.query(
        `INSERT INTO solicitud_partidas
           (solicitud_id,vehiculo_id,tipo,litros_solicitados,tipo_combustible,observaciones)
         VALUES ($1,$2,$3,$4,$5,$6)`,
        [solicitud.id, datos.vehiculoId, partida.tipo,
         new Decimal(partida.litros).toFixed(2), combustibleValido(partida.tipoCombustible),
         partida.observaciones?.trim() || null],
      );
    }
    if (transaccionPropia) await cliente.query('COMMIT');
    return {
      id: solicitud.id as string,
      choferId: solicitud.chofer_id as string,
      vehiculoId: solicitud.vehiculo_id as string,
      litrosSolicitados: total.toNumber(),
      litrosAutorizados: null,
      costoEstimado: null,
      esUrgente: solicitud.es_urgente as boolean,
      motivoChofer: solicitud.motivo_chofer as string | null,
      actividad: solicitud.actividad as string,
      fechaProgramada: (solicitud.fecha_programada as Date).toISOString(),
      estado: 'pendiente',
      aprobadaPor: null,
      folioAutorizacion: null,
      comentario: solicitud.comentario as string,
      creadaEn: (solicitud.creada_en as Date).toISOString(),
      fotoTableroPath: solicitud.foto_tablero_path as string | null,
      partidas: await listarPartidas(solicitud.id as string, cliente),
      replayed: false,
    };
  } catch (error) {
    if (transaccionPropia) await cliente.query('ROLLBACK');
    const pg = error as { code?: string; constraint?: string };
    if (pg.code === '23505' && pg.constraint === 'uq_solicitudes_pendiente_negocio') {
      const { rows } = await pool.query<{ id: string }>(
        `SELECT id FROM solicitudes_autorizacion
         WHERE chofer_id=$1 AND vehiculo_id=$2
           AND (fecha_programada AT TIME ZONE 'America/Mexico_City')::date =
               ($3::timestamptz AT TIME ZONE 'America/Mexico_City')::date
           AND estado='pendiente' ORDER BY creada_en LIMIT 1`,
        [datos.solicitanteId, datos.vehiculoId, datos.fechaProgramada],
      );
      throw new ApiError(409, 'Ya existe una solicitud pendiente para esta unidad y fecha.', {
        codigo: 'SOLICITUD_PENDIENTE_EXISTENTE',
        ...(rows[0] ? { detalles: { solicitudId: rows[0].id } } : {}),
      });
    }
    throw error;
  } finally {
    if (transaccionPropia) cliente.release();
  }
}

export async function autorizarPartidas(datos: {
  solicitudId: string;
  decisiones: Array<{
    tipo: TipoPartidaSolicitud;
    aprobar: boolean;
    litrosAutorizados?: number | null | undefined;
    observaciones?: string | null | undefined;
  }>; 
  aprobadaPor: string;
  aprobadaPorId: string;
}): Promise<{ folioAutorizacion: string | null; litrosAutorizados: string; estado: string }> {
  if (datos.decisiones.length < 1 || new Set(datos.decisiones.map((d) => d.tipo)).size !== datos.decisiones.length) {
    throw new ApiError(400, 'Indica una decisión única para cada partida.');
  }
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    const { rows: solicitudRows } = await cliente.query<{ estado: string }>(
      'SELECT estado FROM solicitudes_autorizacion WHERE id=$1 FOR UPDATE', [datos.solicitudId],
    );
    if (!solicitudRows[0]) throw new ApiError(404, 'Solicitud no encontrada.');
    if (solicitudRows[0].estado !== 'pendiente') throw new ApiError(409, 'La solicitud ya fue resuelta.');
    const { rows: partidas } = await cliente.query<{ tipo: TipoPartidaSolicitud; litros_solicitados: string }>(
      'SELECT tipo, litros_solicitados FROM solicitud_partidas WHERE solicitud_id=$1 FOR UPDATE',
      [datos.solicitudId],
    );
    if (partidas.length !== datos.decisiones.length) throw new ApiError(400, 'Debe resolver todas las partidas.');
    let total = new Decimal(0);
    let aprobadas = 0;
    for (const partida of partidas) {
      const decision = datos.decisiones.find((d) => d.tipo === partida.tipo);
      if (!decision) throw new ApiError(400, 'Falta resolver una partida.');
      let autorizados: Decimal | null = null;
      if (decision.aprobar) {
        autorizados = new Decimal(decision.litrosAutorizados ?? partida.litros_solicitados);
        if (!autorizados.greaterThan(0) || autorizados.greaterThan(partida.litros_solicitados)) {
          throw new ApiError(400, 'Los litros autorizados no son válidos para la partida.');
        }
        total = total.plus(autorizados);
        aprobadas++;
      }
      await cliente.query(
        `UPDATE solicitud_partidas SET estado=$1, litros_autorizados=$2, observaciones=$3
         WHERE solicitud_id=$4 AND tipo=$5`,
        [decision.aprobar ? 'aprobada' : 'rechazada', autorizados?.toString() ?? null,
         decision.observaciones?.trim() || null, datos.solicitudId, partida.tipo],
      );
    }
    const estado = aprobadas > 0 ? 'aprobada' : 'rechazada';
    const { rows: folioRows } = aprobadas > 0
      ? await cliente.query<{ folio: string }>("SELECT 'FA-' || nextval('folio_autorizacion_seq') AS folio")
      : { rows: [] as Array<{ folio: string }> };
    const folio = folioRows[0]?.folio ?? null;
    await cliente.query(
      `UPDATE solicitudes_autorizacion SET estado=$1, litros_autorizados=$2,
       aprobada_por=$3, folio_autorizacion=$4 WHERE id=$5`,
      [estado, aprobadas > 0 ? total.toString() : 0, datos.aprobadaPor, folio, datos.solicitudId],
    );
    await cliente.query('COMMIT');
    void registrarAuditoria({
      usuarioId: datos.aprobadaPorId,
      accion: estado === 'aprobada'
        ? 'autorizar_partidas_solicitud'
        : 'rechazar_partidas_solicitud',
      entidad: 'solicitud_autorizacion',
      entidadId: datos.solicitudId,
      detalle: { tipos: datos.decisiones.map((decision) => decision.tipo) },
    });
    return { folioAutorizacion: folio, litrosAutorizados: total.toFixed(2), estado };
  } catch (error) {
    await cliente.query('ROLLBACK');
    throw error;
  } finally {
    cliente.release();
  }
}

async function saldoInventario(
  cliente: PoolClient,
  marimbaId: string,
  tipoCombustible: string,
): Promise<Decimal> {
  const { rows } = await cliente.query<{ saldo: string }>(
    `SELECT COALESCE(SUM(CASE WHEN tipo='entrada_granel' THEN litros ELSE -litros END),0) AS saldo
     FROM movimientos_inventario_marimba
     WHERE marimba_id=$1 AND tipo_combustible=$2`,
    [marimbaId, combustibleValido(tipoCombustible)],
  );
  return new Decimal(rows[0]!.saldo);
}

export async function saldoNuevoDeMarimba(
  marimbaId: string,
  tipoCombustible: string,
): Promise<Decimal> {
  const cliente = await pool.connect();
  try { return await saldoInventario(cliente, marimbaId, tipoCombustible); } finally { cliente.release(); }
}

export async function registrarCargaConPartidas(datos: {
  usuarioId: string;
  vehiculoId: string;
  folioAutorizacion: string;
  partidas: PartidaCargaEntrada[];
  comprobantes: ComprobanteEntrada[];
  kmAlCargar: number;
  gasolinera: string;
  recorridoId?: string | null | undefined;
  fotoTicketPath?: string | null | undefined;
  fotoTableroPath?: string | null | undefined;
  litrosDetectadosOcr?: number | null | undefined;
}, clienteExterno?: PoolClient): Promise<{
  carga: Record<string, unknown>;
  litrosAutorizados: string;
  litrosConsumidos: string;
  saldoRestante: string;
  saldosGranel: Record<string, string>;
}> {
  if (datos.partidas.length < 1 || new Set(datos.partidas.map((p) => p.tipo)).size !== datos.partidas.length) {
    throw new ApiError(400, 'La carga debe contener partidas únicas.');
  }
  const folios = datos.comprobantes.map((c) => c.folioEstacion.trim());
  if (folios.some((f) => !f || f.length > 100) || new Set(folios).size !== folios.length || folios.length > 20) {
    throw new ApiError(400, 'Los comprobantes contienen folios inválidos o duplicados.');
  }
  const cliente = clienteExterno ?? await pool.connect();
  const transaccionPropia = clienteExterno === undefined;
  try {
    if (transaccionPropia) await cliente.query('BEGIN');
    const { rows: solicitudRows } = await cliente.query<{
      id: string; chofer_id: string; vehiculo_id: string; estado: string;
    }>('SELECT id,chofer_id,vehiculo_id,estado FROM solicitudes_autorizacion WHERE folio_autorizacion=$1 FOR UPDATE', [datos.folioAutorizacion]);
    const solicitud = solicitudRows[0];
    if (!solicitud || solicitud.estado !== 'aprobada') throw new ApiError(404, 'La autorización no está disponible.');
    if (solicitud.chofer_id !== datos.usuarioId || solicitud.vehiculo_id !== datos.vehiculoId) {
      throw new ApiError(404, 'La autorización no está disponible.');
    }
    const { rows: unidades } = await cliente.query<{
      tipo_unidad: string;
      activo: boolean;
      tipo_combustible: string | null;
    }>('SELECT tipo_unidad,activo,tipo_combustible FROM vehiculos WHERE id=$1 FOR UPDATE', [datos.vehiculoId]);
    const unidad = unidades[0];
    if (!unidad || !['Marimba', 'Pipa'].includes(unidad.tipo_unidad) || !unidad.activo) {
      throw new ApiError(404, 'La unidad abastecedora no está disponible.');
    }
    const { rows: partidas } = await cliente.query<{
      id: string; tipo: TipoPartidaSolicitud; estado: string; litros_autorizados: string | null;
      tipo_combustible: string;
    }>('SELECT id,tipo,estado,litros_autorizados,tipo_combustible FROM solicitud_partidas WHERE solicitud_id=$1 FOR UPDATE', [solicitud.id]);

    if (datos.recorridoId) {
      const { rows: recorridos } = await cliente.query<{
        marimba_id: string; operador_id: string; estado: string;
      }>('SELECT marimba_id,operador_id,estado FROM recorridos_marimba WHERE id=$1 FOR UPDATE', [datos.recorridoId]);
      const recorrido = recorridos[0];
      if (!recorrido || recorrido.estado !== 'abierto' || recorrido.marimba_id !== datos.vehiculoId ||
          recorrido.operador_id !== datos.usuarioId) {
        throw new ApiError(404, 'El recorrido no estÃ¡ disponible.');
      }
    }

    let total = new Decimal(0);
    const ids = new Map<TipoPartidaSolicitud, string>();
    for (const entrada of datos.partidas) {
      const partida = partidas.find((p) => p.tipo === entrada.tipo);
      if (!partida || partida.estado !== 'aprobada' || partida.litros_autorizados === null) {
        throw new ApiError(409, 'La partida no está autorizada.');
      }
      if (partida.tipo_combustible !== entrada.tipoCombustible.trim()) {
        throw new ApiError(409, 'El combustible no coincide con la partida autorizada.');
      }
      if (entrada.tipo === 'consumo_propio' && partida.tipo_combustible !== unidad.tipo_combustible) {
        throw new ApiError(409, 'El combustible de consumo propio no coincide con el motor.');
      }
      const litros = new Decimal(entrada.litros);
      if (!litros.greaterThan(0)) throw new ApiError(400, 'Los litros deben ser mayores a cero.');
      const { rows: consumidoRows } = await cliente.query<{ total: string }>(
        'SELECT COALESCE(SUM(litros_cargados),0) AS total FROM carga_partidas WHERE solicitud_partida_id=$1',
        [partida.id],
      );
      if (new Decimal(consumidoRows[0]!.total).plus(litros).greaterThan(partida.litros_autorizados)) {
        throw new ApiError(409, 'La carga supera el saldo autorizado de la partida.');
      }
      total = total.plus(litros);
      ids.set(entrada.tipo, partida.id);
    }
    for (const comprobante of datos.comprobantes) {
      if (comprobante.concepto !== 'visita_completa' && !ids.has(comprobante.concepto)) {
        throw new ApiError(400, 'El comprobante referencia una partida ausente.');
      }
      if (comprobante.concepto === 'visita_completa' && comprobante.litrosIndicados != null &&
          !new Decimal(comprobante.litrosIndicados).equals(total)) {
        throw new ApiError(409, 'El total del comprobante no coincide con el desglose de la carga.');
      }
    }
    const { rows: cargaRows } = await cliente.query<{ id: string; creada_en: Date }>(
      `INSERT INTO cargas (chofer_id,vehiculo_id,folio_autorizacion,litros_cargados,km_al_cargar,
       gasolinera,foto_ticket_path,foto_tablero_path,litros_detectados_ocr,solicitud_id)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10) RETURNING id,creada_en`,
      [datos.usuarioId, datos.vehiculoId, datos.folioAutorizacion, total.toFixed(2), datos.kmAlCargar,
       datos.gasolinera, datos.fotoTicketPath ?? null, datos.fotoTableroPath ?? null,
       datos.litrosDetectadosOcr ?? null, solicitud.id],
    );
    const cargaId = cargaRows[0]!.id;
    const cargaPartidaIds = new Map<TipoPartidaSolicitud, string>();
    for (const entrada of datos.partidas) {
      const { rows } = await cliente.query<{ id: string }>(
        `INSERT INTO carga_partidas
           (carga_id,solicitud_id,vehiculo_id,solicitud_partida_id,tipo,tipo_combustible,litros_cargados)
         VALUES($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
        [cargaId, solicitud.id, datos.vehiculoId, ids.get(entrada.tipo), entrada.tipo,
         combustibleValido(entrada.tipoCombustible), new Decimal(entrada.litros).toFixed(2)],
      );
      cargaPartidaIds.set(entrada.tipo, rows[0]!.id);
      if (entrada.tipo === 'carga_granel') {
        await cliente.query('SELECT pg_advisory_xact_lock(hashtext($1))', [datos.vehiculoId]);
        await cliente.query(
          `INSERT INTO movimientos_inventario_marimba
           (marimba_id,tipo_combustible,tipo,litros,carga_partida_id,carga_partida_tipo,
            recorrido_id,registrado_por,responsable_id)
           VALUES($1,$2,'entrada_granel',$3,$4,'carga_granel',$5,$6,$6)`,
          [datos.vehiculoId, combustibleValido(entrada.tipoCombustible),
           new Decimal(entrada.litros).toFixed(2), rows[0]!.id,
           datos.recorridoId ?? null, datos.usuarioId],
        );
      }
    }
    for (const comprobante of datos.comprobantes) {
      await cliente.query(
        `INSERT INTO comprobantes_estacion(carga_id,carga_partida_id,concepto,folio_estacion,
         foto_path,litros_indicados,gasolinera,fecha,registrado_por)
         VALUES($1,$2,$3,$4,$5,$6,$7,COALESCE($8::timestamptz,now()),$9)`,
        [cargaId, comprobante.concepto === 'visita_completa' ? null : cargaPartidaIds.get(comprobante.concepto),
         comprobante.concepto, comprobante.folioEstacion.trim(), comprobante.fotoPath ?? null,
         comprobante.litrosIndicados == null ? null : new Decimal(comprobante.litrosIndicados).toString(),
         datos.gasolinera, comprobante.fecha ?? null, datos.usuarioId],
      );
    }
    const combustiblesGranel = [...new Set(datos.partidas
      .filter((partida) => partida.tipo === 'carga_granel')
      .map((partida) => combustibleValido(partida.tipoCombustible)))];
    const saldosGranel: Record<string, string> = {};
    for (const combustible of combustiblesGranel) {
      saldosGranel[combustible] = (await saldoInventario(cliente, datos.vehiculoId, combustible)).toFixed(2);
    }
    const totalAutorizado = partidas.reduce(
      (suma, partida) => suma.plus(partida.litros_autorizados ?? 0), new Decimal(0),
    );
    const { rows: totalConsumidoRows } = await cliente.query<{ total: string }>(
      `SELECT COALESCE(SUM(cp.litros_cargados),0) total FROM carga_partidas cp
       JOIN solicitud_partidas sp ON sp.id=cp.solicitud_partida_id WHERE sp.solicitud_id=$1`,
      [solicitud.id],
    );
    const totalConsumido = new Decimal(totalConsumidoRows[0]!.total);
    await registrarAuditoria({
      usuarioId: datos.usuarioId,
      accion: 'registrar_carga_partidas',
      entidad: 'carga',
      entidadId: cargaId,
      detalle: { tipos: datos.partidas.map((partida) => partida.tipo) },
    }, cliente);
    if (transaccionPropia) await cliente.query('COMMIT');
    return {
      carga: {
        id: cargaId,
        choferId: datos.usuarioId,
        vehiculoId: datos.vehiculoId,
        folioAutorizacion: datos.folioAutorizacion,
        foliosAdicionales: [],
        litrosCargados: total.toNumber(),
        kmAlCargar: datos.kmAlCargar,
        gasolinera: datos.gasolinera,
        creadaEn: cargaRows[0]!.creada_en.toISOString(),
        fotoTicketPath: datos.fotoTicketPath ?? null,
        fotoTableroPath: datos.fotoTableroPath ?? null,
        litrosDetectadosOcr: datos.litrosDetectadosOcr ?? null,
        precioReferenciaPorLitro: null,
        costoReferencia: null,
      },
      litrosAutorizados: totalAutorizado.toFixed(2),
      litrosConsumidos: totalConsumido.toFixed(2),
      saldoRestante: totalAutorizado.minus(totalConsumido).toFixed(2),
      saldosGranel,
    };
  } catch (error) {
    if (transaccionPropia) await cliente.query('ROLLBACK');
    throw error;
  } finally {
    if (transaccionPropia) cliente.release();
  }
}
