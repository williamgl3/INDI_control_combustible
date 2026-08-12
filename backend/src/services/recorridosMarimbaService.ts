import Decimal from 'decimal.js';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import type { DespachoMarimba, EstadoRecorridoMarimba, RecorridoMarimba, RolUsuario } from '../types';
import { registrarAuditoria } from './auditoriaService';
import * as despachosService from './despachosMarimbaService';
import { bloquearInventario } from '../db/inventarioLock';

interface FilaRecorrido {
  id: string; marimba_id: string; operador_id: string; frente: string; carga_id: string | null;
  litros_iniciales: string; km_inicio: string | null; km_cierre: string | null;
  horas_equipo_menor_inicio: string | null; horas_equipo_menor_cierre: string | null;
  estado: EstadoRecorridoMarimba; litros_despachados_total: string | null;
  existencia_calculada: string | null; diferencia_conciliacion: string | null;
  tolerancia_usada: string | null; requiere_revision: boolean; foto_cierre_path: string | null;
  iniciado_en: Date; cerrado_en: Date | null; registrado_por: string | null;
  entradas_granel_total: string | null; existencia_fisica: string | null;
  estado_conciliacion: 'conciliado' | 'diferencia_pendiente' | null;
  observaciones_cierre: string | null; foto_nivel_path: string | null;
  tipo_combustible: string | null;
}
const n = (v: string | null): number | null => v === null ? null : Number(v);
function aRecorrido(f: FilaRecorrido): RecorridoMarimba {
  return { id:f.id, marimbaId:f.marimba_id, operadorId:f.operador_id, frente:f.frente,
    cargaId:f.carga_id, litrosIniciales:Number(f.litros_iniciales), kmInicio:n(f.km_inicio),
    kmCierre:n(f.km_cierre), horasEquipoMenorInicio:n(f.horas_equipo_menor_inicio),
    horasEquipoMenorCierre:n(f.horas_equipo_menor_cierre), estado:f.estado,
    litrosDespachadosTotal:n(f.litros_despachados_total), existenciaCalculada:n(f.existencia_calculada),
    diferenciaConciliacion:n(f.diferencia_conciliacion), toleranciaUsada:n(f.tolerancia_usada),
    requiereRevision:f.requiere_revision, fotoCierrePath:f.foto_cierre_path,
    iniciadoEn:f.iniciado_en.toISOString(), cerradoEn:f.cerrado_en?.toISOString() ?? null,
    registradoPor:f.registrado_por, entradasGranelTotal:n(f.entradas_granel_total),
    existenciaFisica:n(f.existencia_fisica), estadoConciliacion:f.estado_conciliacion,
    observacionesCierre:f.observaciones_cierre, fotoNivelPath:f.foto_nivel_path,
    tipoCombustible:f.tipo_combustible };
}

export async function buscarRecorridoPorId(id:string):Promise<RecorridoMarimba|null>{
  const {rows}=await pool.query<FilaRecorrido>('SELECT * FROM recorridos_marimba WHERE id=$1',[id]);
  return rows[0]?aRecorrido(rows[0]):null;
}
export async function buscarRecorridoAccesible(
  id:string,actorId:string,rol:RolUsuario,
):Promise<RecorridoMarimba|null>{
  const recorrido=await buscarRecorridoPorId(id);
  if(!recorrido)return null;
  if(rol==='supervisor'&&recorrido.operadorId!==actorId)return null;
  if(!['supervisor','administrativo','superadmin'].includes(rol))return null;
  return recorrido;
}
export async function listarRecorridos(f?:{
  marimbaId?:string|undefined;requiereRevision?:boolean|undefined;
}):Promise<RecorridoMarimba[]>{
  const condiciones:string[]=[]; const valores:unknown[]=[];
  if(f?.marimbaId){valores.push(f.marimbaId);condiciones.push(`marimba_id=$${valores.length}`);}
  if(f?.requiereRevision!==undefined){valores.push(f.requiereRevision);condiciones.push(`requiere_revision=$${valores.length}`);}
  const where=condiciones.length?`WHERE ${condiciones.join(' AND ')}`:'';
  const {rows}=await pool.query<FilaRecorrido>(`SELECT * FROM recorridos_marimba ${where} ORDER BY iniciado_en DESC`,valores);
  return rows.map(aRecorrido);
}

export async function crearRecorrido(datos:{marimbaId:string;operadorId:string;registradoPor:string;frente:string;
  tipoCombustible:string;
  kmInicio?:number|null|undefined;horasEquipoMenorInicio?:number|null|undefined;}):Promise<RecorridoMarimba>{
  const cliente=await pool.connect();
  try{
    await cliente.query('BEGIN');
    await bloquearInventario(cliente,datos.marimbaId,datos.tipoCombustible);
    const {rows:unidad}=await cliente.query<{tipo_unidad:string;activo:boolean}>(
      'SELECT tipo_unidad,activo FROM vehiculos WHERE id=$1 FOR UPDATE',[datos.marimbaId]);
    if(!unidad[0]||!unidad[0].activo||!['Marimba','Pipa'].includes(unidad[0].tipo_unidad))
      throw new ApiError(404,'La unidad abastecedora no está disponible.');
    const {rows:operador}=await cliente.query<{rol:string;activo:boolean}>(
      'SELECT rol,activo FROM usuarios WHERE id=$1 FOR UPDATE',[datos.operadorId]);
    if(!operador[0]||!operador[0].activo||operador[0].rol!=='supervisor')
      throw new ApiError(404,'El operador responsable no está disponible.');
    const saldo=await despachosService.saldoDeMarimba(datos.marimbaId,datos.tipoCombustible,cliente);
    const {rows}=await cliente.query<FilaRecorrido>(
      `INSERT INTO recorridos_marimba(marimba_id,operador_id,registrado_por,frente,tipo_combustible,
       litros_iniciales,km_inicio,horas_equipo_menor_inicio)
       VALUES($1,$2,$3,$4,$5,$6,$7,$8) RETURNING *`,
      [datos.marimbaId,datos.operadorId,datos.registradoPor,datos.frente,datos.tipoCombustible,
       saldo.toFixed(2),datos.kmInicio??null,datos.horasEquipoMenorInicio??null]);
    await cliente.query('COMMIT');
    const recorrido=aRecorrido(rows[0]!);
    void registrarAuditoria({usuarioId:datos.registradoPor,accion:'abrir_recorrido_marimba',
      entidad:'recorrido_marimba',entidadId:recorrido.id,
      detalle:{operadorId:datos.operadorId,existenciaInicial:saldo.toString()}});
    return recorrido;
  }catch(e){await cliente.query('ROLLBACK');throw e;}finally{cliente.release();}
}

export async function agregarDespacho(recorridoId:string,datos:Omit<Parameters<typeof despachosService.crearDespacho>[0],
  'recorridoId'|'responsableId'>):Promise<DespachoMarimba>{
  const recorrido=await buscarRecorridoPorId(recorridoId);
  if(!recorrido)throw new ApiError(404,'El recorrido no está disponible.');
  return despachosService.crearDespacho({...datos,recorridoId,responsableId:recorrido.operadorId});
}

export async function cerrarRecorrido(recorridoId:string,datos:{existenciaFisica:number;fotoCierrePath:string;
  fotoNivelPath:string;observaciones?:string|null|undefined;kmCierre?:number|null|undefined;
  horasEquipoMenorCierre?:number|null|undefined;},
  actorId:string,actorRol:RolUsuario):Promise<RecorridoMarimba>{
  const cliente=await pool.connect();
  try{
    await cliente.query('BEGIN');
    const {rows}=await cliente.query<FilaRecorrido>('SELECT * FROM recorridos_marimba WHERE id=$1 FOR UPDATE',[recorridoId]);
    const actual=rows[0]; if(!actual)throw new ApiError(404,'El recorrido no está disponible.');
    if(actorRol==='supervisor'&&actual.operador_id!==actorId)
      throw new ApiError(404,'El recorrido no está disponible.');
    if(actual.estado!=='abierto')throw new ApiError(409,'El recorrido ya está cerrado.');
    if(!actual.tipo_combustible)throw new ApiError(409,'El recorrido histórico no tiene combustible configurado.');
    await bloquearInventario(cliente,actual.marimba_id,actual.tipo_combustible);
    const inicial=new Decimal(actual.litros_iniciales);
    const totalDespachado=await despachosService.totalDespachadoDeRecorrido(recorridoId,cliente);
    const {rows:entradasRows}=await cliente.query<{total:string}>(
      `SELECT COALESCE(SUM(litros),0) total FROM movimientos_inventario_marimba
       WHERE recorrido_id=$1 AND tipo='entrada_granel'`,[recorridoId]);
    const entradas=new Decimal(entradasRows[0]!.total);
    const teorico=inicial.plus(entradas).minus(totalDespachado);
    const fisico=new Decimal(datos.existenciaFisica);
    if(fisico.isNegative())throw new ApiError(400,'La existencia física no es válida.');
    const diferencia=fisico.minus(teorico);
    const pendiente=!diferencia.equals(0);
    if(pendiente&&(!datos.observaciones?.trim()||!datos.fotoNivelPath))
      throw new ApiError(400,'Una diferencia requiere observación y evidencia.');
    const {rows:cerrado}=await cliente.query<FilaRecorrido>(
      `UPDATE recorridos_marimba SET estado='cerrado',km_cierre=$1,horas_equipo_menor_cierre=$2,
       foto_cierre_path=$3,foto_nivel_path=$4,litros_despachados_total=$5,entradas_granel_total=$6,
       existencia_calculada=$7,existencia_fisica=$8,diferencia_conciliacion=$9,tolerancia_usada=NULL,
       requiere_revision=$10,estado_conciliacion=$11,observaciones_cierre=$12,cerrado_en=now()
       WHERE id=$13 RETURNING *`,
      [datos.kmCierre??null,datos.horasEquipoMenorCierre??null,datos.fotoCierrePath,datos.fotoNivelPath,
       totalDespachado.toString(),entradas.toString(),teorico.toString(),fisico.toString(),diferencia.toString(),
       pendiente,pendiente?'diferencia_pendiente':'conciliado',datos.observaciones?.trim()||null,recorridoId]);
    await cliente.query('COMMIT'); const resultado=aRecorrido(cerrado[0]!);
    void registrarAuditoria({usuarioId:actorId,accion:'cerrar_recorrido_marimba',entidad:'recorrido_marimba',
      entidadId:recorridoId,detalle:{operadorId:actual.operador_id,diferencia:diferencia.toString(),
        estadoConciliacion:resultado.estadoConciliacion}});
    return resultado;
  }catch(e){await cliente.query('ROLLBACK');throw e;}finally{cliente.release();}
}
