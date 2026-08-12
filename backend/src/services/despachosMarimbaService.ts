import Decimal from 'decimal.js';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import type { DespachoMarimba, EstadoDespacho, RolUsuario } from '../types';
import { registrarAuditoria } from './auditoriaService';
import { bloquearInventario } from '../db/inventarioLock';

interface FilaDespacho {
  id: string; marimba_id: string; vehiculo_destino_id: string | null;
  destino_texto: string | null; operador_texto: string; residente_texto: string | null;
  sitio: string | null; litros_solicitados: string | null; litros_suministrados: string;
  lectura_medidor: string | null; precio_referencia_usado: string | null;
  estado: EstadoDespacho; foto_evidencia_path: string | null; registrado_por: string;
  creado_en: Date; recorrido_id: string | null; responsable_id: string | null;
  horometro: string | null; foto_horometro_path: string | null;
  medidor_inicial: string | null; medidor_final: string | null; foto_medidor_path: string | null;
  cantidad_declarada: boolean | null; tipo_combustible: string | null;
  ubicacion: string | null; observaciones: string | null;
}

const numero = (valor: string | null): number | null => valor === null ? null : Number(valor);
function aDespacho(fila: FilaDespacho): DespachoMarimba {
  return {
    id: fila.id, marimbaId: fila.marimba_id, vehiculoDestinoId: fila.vehiculo_destino_id,
    destinoTexto: fila.destino_texto, operadorTexto: fila.operador_texto,
    residenteTexto: fila.residente_texto, sitio: fila.sitio,
    litrosSolicitados: numero(fila.litros_solicitados),
    litrosSuministrados: fila.litros_suministrados,
    lecturaMedidor: numero(fila.lectura_medidor),
    precioReferenciaUsado: numero(fila.precio_referencia_usado), estado: fila.estado,
    fotoEvidenciaPath: fila.foto_evidencia_path, registradoPor: fila.registrado_por,
    creadoEn: fila.creado_en.toISOString(), recorridoId: fila.recorrido_id,
    responsableId: fila.responsable_id, horometro: numero(fila.horometro),
    fotoHorometroPath: fila.foto_horometro_path, medidorInicial: numero(fila.medidor_inicial),
    medidorFinal: numero(fila.medidor_final), fotoMedidorPath: fila.foto_medidor_path,
    cantidadDeclarada: fila.cantidad_declarada, ubicacion: fila.ubicacion,
    tipoCombustible: fila.tipo_combustible,
    observaciones: fila.observaciones,
  };
}

export async function saldoDeMarimba(
  marimbaId: string,
  tipoCombustible: string,
  cliente: { query: typeof pool.query } = pool,
): Promise<Decimal> {
  const { rows } = await cliente.query<{ saldo: string }>(
    `SELECT COALESCE(SUM(CASE WHEN tipo='entrada_granel' THEN litros ELSE -litros END),0) AS saldo
     FROM movimientos_inventario_marimba
     WHERE marimba_id=$1 AND tipo_combustible=$2`, [marimbaId, tipoCombustible],
  );
  return new Decimal(rows[0]?.saldo ?? 0);
}

export async function crearDespacho(datos: {
  marimbaId: string; vehiculoDestinoId: string; operadorTexto: string;
  responsableId: string; registradoPor: string; recorridoId: string;
  actorRol: RolUsuario;
  tipoCombustible: string;
  litrosSuministrados?: number | null | undefined; horometro: number; fotoHorometroPath: string;
  medidorInicial?: number | null | undefined; medidorFinal?: number | null | undefined;
  fotoMedidorPath?: string | null | undefined; fotoEvidenciaPath?: string | null | undefined;
  ubicacion?: string | null | undefined; observaciones?: string | null | undefined;
  estado?: EstadoDespacho | undefined;
}): Promise<DespachoMarimba> {
  const cliente = await pool.connect();
  try {
    await cliente.query('BEGIN');
    await bloquearInventario(cliente, datos.marimbaId, datos.tipoCombustible);
    const { rows: recorridos } = await cliente.query<{
      marimba_id: string; operador_id: string; frente: string; estado: string;
      tipo_combustible: string | null;
    }>('SELECT marimba_id,operador_id,frente,estado,tipo_combustible FROM recorridos_marimba WHERE id=$1 FOR UPDATE', [datos.recorridoId]);
    const recorrido = recorridos[0];
    if (!recorrido || recorrido.estado !== 'abierto' || recorrido.marimba_id !== datos.marimbaId) {
      throw new ApiError(404, 'El recorrido no está disponible.');
    }
    if (recorrido.tipo_combustible !== datos.tipoCombustible) {
      throw new ApiError(409, 'El combustible no coincide con el recorrido.');
    }
    if (recorrido.operador_id !== datos.responsableId) {
      throw new ApiError(409, 'El responsable no coincide con el operador del recorrido.');
    }
    if (datos.actorRol === 'supervisor' && recorrido.operador_id !== datos.registradoPor) {
      throw new ApiError(404, 'El recorrido no estÃ¡ disponible.');
    }
    const { rows: unidades } = await cliente.query<{
      tipo_unidad: string; activo: boolean; tipo_combustible: string | null;
    }>('SELECT tipo_unidad,activo,tipo_combustible FROM vehiculos WHERE id=$1 FOR UPDATE', [datos.vehiculoDestinoId]);
    const destino = unidades[0];
    if (!destino || destino.tipo_unidad !== 'Maquinaria' || !destino.activo) {
      throw new ApiError(404, 'La maquinaria destino no está disponible.');
    }
    const { rows: abastecedoras } = await cliente.query<{ tipo_unidad: string; activo: boolean }>(
      'SELECT tipo_unidad,activo FROM vehiculos WHERE id=$1 FOR UPDATE', [datos.marimbaId],
    );
    const abastecedora = abastecedoras[0];
    if (!abastecedora || !abastecedora.activo || !['Marimba', 'Pipa'].includes(abastecedora.tipo_unidad)) {
      throw new ApiError(404, 'La unidad abastecedora no está disponible.');
    }
    if (!destino.tipo_combustible || destino.tipo_combustible !== datos.tipoCombustible) {
      throw new ApiError(409, 'El combustible de la maquinaria no es compatible.');
    }
    const horometro = new Decimal(datos.horometro);
    if (horometro.isNegative()) throw new ApiError(400, 'El horómetro no es válido.');
    const { rows: previas } = await cliente.query<{ horometro: string | null }>(
      `SELECT horometro FROM despachos_marimba
       WHERE vehiculo_destino_id=$1 AND horometro IS NOT NULL
       ORDER BY creado_en DESC LIMIT 1`, [datos.vehiculoDestinoId],
    );
    if (previas[0]?.horometro && horometro.lessThan(previas[0].horometro)) {
      throw new ApiError(409, 'El horómetro no puede ser menor que la última lectura válida.');
    }
    const tieneMedidor = datos.medidorInicial != null || datos.medidorFinal != null;
    if (tieneMedidor && (datos.medidorInicial == null || datos.medidorFinal == null)) {
      throw new ApiError(400, 'Indica ambas lecturas del medidor.');
    }
    const litros = tieneMedidor
      ? new Decimal(datos.medidorFinal!).minus(datos.medidorInicial!)
      : new Decimal(datos.litrosSuministrados ?? 0);
    if (!litros.greaterThan(0)) throw new ApiError(400, 'Los litros deben ser mayores a cero.');
    if (tieneMedidor && !datos.fotoMedidorPath) throw new ApiError(400, 'La foto del medidor es obligatoria.');
    if (!tieneMedidor && !datos.fotoEvidenciaPath) {
      throw new ApiError(400, 'La evidencia es obligatoria para una cantidad declarada.');
    }
    const saldo = await saldoDeMarimba(datos.marimbaId, datos.tipoCombustible, cliente);
    if (litros.greaterThan(saldo)) throw new ApiError(409, 'Saldo insuficiente en la unidad abastecedora.');
    const { rows } = await cliente.query<FilaDespacho>(
      `INSERT INTO despachos_marimba
       (marimba_id,vehiculo_destino_id,destino_texto,operador_texto,sitio,
        litros_suministrados,lectura_medidor,estado,foto_evidencia_path,registrado_por,
        recorrido_id,responsable_id,horometro,foto_horometro_path,medidor_inicial,
        medidor_final,foto_medidor_path,cantidad_declarada,ubicacion,observaciones,tipo_combustible)
       VALUES($1,$2,NULL,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13,$14,$15,$16,$17,$18,$19,$20)
       RETURNING *`,
      [datos.marimbaId, datos.vehiculoDestinoId, datos.operadorTexto, recorrido.frente,
       litros.toString(), horometro.toString(), datos.estado ?? 'activo',
       datos.fotoEvidenciaPath ?? null, datos.registradoPor, datos.recorridoId,
       datos.responsableId, horometro.toString(), datos.fotoHorometroPath,
       datos.medidorInicial ?? null, datos.medidorFinal ?? null, datos.fotoMedidorPath ?? null,
       !tieneMedidor, datos.ubicacion ?? recorrido.frente, datos.observaciones ?? null,
       datos.tipoCombustible],
    );
    await cliente.query(
      `INSERT INTO movimientos_inventario_marimba
       (marimba_id,tipo_combustible,tipo,litros,despacho_id,recorrido_id,
        registrado_por,responsable_id,observacion)
       VALUES($1,$2,'despacho_maquinaria',$3,$4,$5,$6,$7,$8)`,
      [datos.marimbaId, datos.tipoCombustible, litros.toFixed(2), rows[0]!.id, datos.recorridoId,
       datos.registradoPor, datos.responsableId, datos.observaciones ?? null],
    );
    if ((await saldoDeMarimba(datos.marimbaId, datos.tipoCombustible, cliente)).isNegative()) {
      throw new ApiError(409, 'La operación produciría inventario negativo.');
    }
    await cliente.query('COMMIT');
    const despacho = aDespacho(rows[0]!);
    void registrarAuditoria({ usuarioId: datos.registradoPor, accion: 'registrar_despacho_marimba',
      entidad: 'despacho_marimba', entidadId: despacho.id,
      detalle: { responsableId: datos.responsableId, litros: litros.toString() } });
    return despacho;
  } catch (error) {
    await cliente.query('ROLLBACK');
    throw error;
  } finally { cliente.release(); }
}

export async function listarDespachosDeMarimba(marimbaId: string): Promise<DespachoMarimba[]> {
  const { rows } = await pool.query<FilaDespacho>(
    'SELECT * FROM despachos_marimba WHERE marimba_id=$1 ORDER BY creado_en DESC', [marimbaId]);
  return rows.map(aDespacho);
}
export async function listarDespachosDeRecorrido(recorridoId: string): Promise<DespachoMarimba[]> {
  const { rows } = await pool.query<FilaDespacho>(
    'SELECT * FROM despachos_marimba WHERE recorrido_id=$1 ORDER BY creado_en', [recorridoId]);
  return rows.map(aDespacho);
}
export async function totalDespachadoDeRecorrido(
  recorridoId: string, cliente: { query: typeof pool.query },
): Promise<Decimal> {
  const { rows } = await cliente.query<{ total: string }>(
    `SELECT COALESCE(SUM(litros),0) AS total FROM movimientos_inventario_marimba
     WHERE recorrido_id=$1 AND tipo='despacho_maquinaria'`, [recorridoId]);
  return new Decimal(rows[0]?.total ?? 0);
}
export async function rendimientoDeDespacho(despachoId: string): Promise<number | null> {
  const { rows } = await pool.query<{ rendimiento_l_por_hora: string | null }>(
    'SELECT rendimiento_l_por_hora FROM rendimiento_despacho WHERE despacho_id=$1', [despachoId]);
  const valor = rows[0]?.rendimiento_l_por_hora;
  return valor == null ? null : Number(valor);
}
