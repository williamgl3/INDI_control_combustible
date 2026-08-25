import { randomUUID } from 'node:crypto';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';
import { pool } from '../../src/db/pool';
import { ejecutarIdempotente, OPERACIONES_IDEMPOTENTES } from '../../src/services/idempotenciaService';
import * as despachosService from '../../src/services/despachosMarimbaService';
import * as incidenciasService from '../../src/services/incidenciasService';
import * as partidasService from '../../src/services/marimbaPartidasService';
import * as cierresService from '../../src/services/cierresDiaService';

const suite = process.env.RUN_IDEMPOTENCY_INTEGRATION === '1' ? describe.sequential : describe.skip;

function protegerBaseAislada(): void {
  const url = new URL(process.env.DATABASE_URL ?? '');
  if (!['127.0.0.1', 'localhost'].includes(url.hostname) || !url.pathname.endsWith('_test') || url.port === '5432') {
    throw new Error('La integracion de idempotencia exige una base local *_test fuera del puerto 5432.');
  }
}

const ids = {
  supervisor: randomUUID(), otroUsuario: randomUUID(), marimba: randomUUID(), maquinaria: randomUUID(),
  solicitud: randomUUID(), solicitudPartida: randomUUID(), carga: randomUUID(), cargaPartida: randomUUID(),
  recorrido: randomUUID(),
};

const hash = 'a'.repeat(64);

suite('ledger idempotente con PostgreSQL real', () => {
  beforeAll(async () => {
    protegerBaseAislada();
    const migraciones = await pool.query<{ total: string }>('SELECT count(*) total FROM schema_migrations');
    expect(Number(migraciones.rows[0]!.total)).toBe(33);
    await pool.query(`INSERT INTO usuarios(id,usuario,password_hash,nombre,correo,rol) VALUES
      ($1,$2,'x','Supervisor','supervisor-idem@test.invalid','supervisor'),
      ($3,$4,'x','Supervisor dos','supervisor2-idem@test.invalid','supervisor')`,
      [ids.supervisor, `idem-${ids.supervisor}`, ids.otroUsuario, `idem-${ids.otroUsuario}`]);
    await pool.query(`INSERT INTO vehiculos(id,tipo_unidad,numero_economico,tipo_combustible,modelo,activo) VALUES
      ($1,'Marimba',$2,'Di\u00e9sel','Marimba idempotencia',true),
      ($3,'Maquinaria',$4,'Di\u00e9sel','Maquinaria idempotencia',true)`,
      [ids.marimba, `M-${ids.marimba}`, ids.maquinaria, `Q-${ids.maquinaria}`]);
    await pool.query(`INSERT INTO solicitudes_autorizacion
      (id,chofer_id,vehiculo_id,litros_solicitados,litros_autorizados,costo_estimado,es_urgente,
       actividad,fecha_programada,estado,folio_autorizacion)
      VALUES($1,$2,$3,100,100,1000,false,'Fixture',now(),'aprobada',$4)`,
      [ids.solicitud, ids.supervisor, ids.marimba, `FA-IDEM-${ids.solicitud}`]);
    await pool.query(`INSERT INTO solicitud_partidas
      (id,solicitud_id,vehiculo_id,tipo,litros_solicitados,litros_autorizados,tipo_combustible,estado)
      VALUES($1,$2,$3,'carga_granel',100,100,'Di\u00e9sel','aprobada')`,
      [ids.solicitudPartida, ids.solicitud, ids.marimba]);
    await pool.query(`INSERT INTO cargas
      (id,chofer_id,vehiculo_id,folio_autorizacion,litros_cargados,km_al_cargar,gasolinera,solicitud_id)
      VALUES($1,$2,$3,$4,100,1,'Fixture',$5)`,
      [ids.carga, ids.supervisor, ids.marimba, `FA-IDEM-${ids.solicitud}`, ids.solicitud]);
    await pool.query(`INSERT INTO carga_partidas
      (id,carga_id,solicitud_id,vehiculo_id,solicitud_partida_id,tipo,tipo_combustible,litros_cargados)
      VALUES($1,$2,$3,$4,$5,'carga_granel','Di\u00e9sel',100)`,
      [ids.cargaPartida, ids.carga, ids.solicitud, ids.marimba, ids.solicitudPartida]);
    await pool.query(`INSERT INTO movimientos_inventario_marimba
      (marimba_id,tipo_combustible,tipo,litros,carga_partida_id,carga_partida_tipo,registrado_por,responsable_id)
      VALUES($1,'Di\u00e9sel','entrada_granel',100,$2,'carga_granel',$3,$3)`,
      [ids.marimba, ids.cargaPartida, ids.supervisor]);
    await pool.query(`INSERT INTO recorridos_marimba
      (id,marimba_id,operador_id,registrado_por,frente,tipo_combustible,litros_iniciales)
      VALUES($1,$2,$3,$3,'Frente test','Di\u00e9sel',100)`, [ids.recorrido, ids.marimba, ids.supervisor]);
  });

  afterAll(async () => { await pool.end(); });

  it('dos despachos concurrentes ejecutan negocio, inventario y auditoria una sola vez', async () => {
    const key = randomUUID();
    const ejecutar = () => ejecutarIdempotente({ usuarioId: ids.supervisor,
      operacion: OPERACIONES_IDEMPOTENTES.crearDespachoMarimba, idempotencyKey: key, requestHash: hash,
      ejecutar: async (cliente) => {
        const despacho = await despachosService.crearDespacho({ marimbaId: ids.marimba,
          vehiculoDestinoId: ids.maquinaria, operadorTexto: 'Operador', responsableId: ids.supervisor,
          registradoPor: ids.supervisor, recorridoId: ids.recorrido, actorRol: 'supervisor',
          tipoCombustible: 'Di\u00e9sel', litrosSuministrados: 10, horometro: 20,
          fotoHorometroPath: '/uploads/11111111-1111-4111-8111-111111111111.jpg',
          fotoEvidenciaPath: '/uploads/22222222-2222-4222-8222-222222222222.jpg' }, cliente);
        return { status: 201, body: despacho, resourceType: 'despacho_marimba', resourceId: despacho.id };
      },
    });
    const [a, b] = await Promise.all([ejecutar(), ejecutar()]);
    expect(a.status).toBe(201); expect(b.status).toBe(201);
    expect(a.resourceId).toBe(b.resourceId);
    expect([a.replayed, b.replayed].sort()).toEqual([false, true]);
    const conteos = await pool.query<{ despachos: string; movimientos: string; auditorias: string; ledger: string }>(
      `SELECT
       (SELECT count(*) FROM despachos_marimba WHERE recorrido_id=$1) despachos,
       (SELECT count(*) FROM movimientos_inventario_marimba WHERE recorrido_id=$1 AND tipo='despacho_maquinaria') movimientos,
       (SELECT count(*) FROM auditoria_acciones WHERE entidad='despacho_marimba' AND entidad_id=$4) auditorias,
       (SELECT count(*) FROM operaciones_idempotentes WHERE usuario_id=$2 AND operacion='despacho_marimba.crear' AND idempotency_key=$3) ledger`,
      [ids.recorrido, ids.supervisor, key, a.resourceId]);
    expect(conteos.rows[0]).toEqual({ despachos: '1', movimientos: '1', auditorias: '1', ledger: '1' });
    expect((await despachosService.saldoDeMarimba(ids.marimba, 'Di\u00e9sel')).toFixed(2)).toBe('90.00');
  });

  it('replay tras respuesta perdida conserva status, body e id', async () => {
    const key = randomUUID(); let ejecuciones = 0;
    const comando = () => ejecutarIdempotente({ usuarioId: ids.supervisor,
      operacion: OPERACIONES_IDEMPOTENTES.reportarIncidencia, idempotencyKey: key, requestHash: hash,
      ejecutar: async (cliente) => { ejecuciones++; const incidencia = await incidenciasService.reportar({
        vehiculoId: ids.maquinaria, choferId: ids.supervisor, descripcion: 'Respuesta perdida' }, cliente);
        return { status: 201, body: incidencia, resourceType: 'incidencia_vehiculo', resourceId: incidencia.id }; },
    });
    const primera = await comando(); // se simula que el cliente no la recibio
    const replay = await comando();
    expect(replay).toMatchObject({ status: primera.status, body: primera.body, resourceId: primera.resourceId, replayed: true });
    expect(ejecuciones).toBe(1);
  });

  it('payload distinto da 409 y no modifica negocio', async () => {
    const key = randomUUID();
    await ejecutarIdempotente({ usuarioId: ids.supervisor, operacion: OPERACIONES_IDEMPOTENTES.reportarIncidencia,
      idempotencyKey: key, requestHash: hash, ejecutar: async (cliente) => { const item = await incidenciasService.reportar({
        vehiculoId: ids.maquinaria, choferId: ids.supervisor, descripcion: 'Original' }, cliente);
        return { status: 201, body: item, resourceId: item.id }; } });
    await expect(ejecutarIdempotente({ usuarioId: ids.supervisor,
      operacion: OPERACIONES_IDEMPOTENTES.reportarIncidencia, idempotencyKey: key,
      requestHash: 'b'.repeat(64), ejecutar: async () => { throw new Error('no debe ejecutarse'); } }))
      .rejects.toMatchObject({ status: 409, codigo: 'IDEMPOTENCY_KEY_PAYLOAD_MISMATCH' });
  });

  it('misma UUID tiene scope independiente por usuario y operacion', async () => {
    const key = randomUUID();
    const insertar = (usuarioId: string, operacion: typeof OPERACIONES_IDEMPOTENTES.reportarIncidencia | typeof OPERACIONES_IDEMPOTENTES.subirEvidencia) =>
      ejecutarIdempotente({ usuarioId, operacion, idempotencyKey: key, requestHash: hash,
        ejecutar: async (cliente) => { const item = await incidenciasService.reportar({ vehiculoId: ids.maquinaria,
          choferId: usuarioId, descripcion: operacion }, cliente); return { status: 201, body: item, resourceId: item.id }; } });
    const resultados = await Promise.all([insertar(ids.supervisor, OPERACIONES_IDEMPOTENTES.reportarIncidencia),
      insertar(ids.otroUsuario, OPERACIONES_IDEMPOTENTES.reportarIncidencia),
      insertar(ids.supervisor, OPERACIONES_IDEMPOTENTES.subirEvidencia)]);
    expect(new Set(resultados.map((r) => r.resourceId)).size).toBe(3);
  });

  it('rollback no consume key y el retry posterior ejecuta', async () => {
    const key = randomUUID(); const descripcion = `rollback-${key}`;
    await expect(ejecutarIdempotente({ usuarioId: ids.supervisor,
      operacion: OPERACIONES_IDEMPOTENTES.reportarIncidencia, idempotencyKey: key, requestHash: hash,
      ejecutar: async (cliente) => { await incidenciasService.reportar({ vehiculoId: ids.maquinaria,
        choferId: ids.supervisor, descripcion }, cliente); throw new Error('fallo simulado'); } })).rejects.toThrow('fallo simulado');
    expect((await pool.query('SELECT 1 FROM operaciones_idempotentes WHERE idempotency_key=$1', [key])).rowCount).toBe(0);
    expect((await pool.query('SELECT 1 FROM incidencias_vehiculo WHERE descripcion=$1', [descripcion])).rowCount).toBe(0);
    const retry = await ejecutarIdempotente({ usuarioId: ids.supervisor,
      operacion: OPERACIONES_IDEMPOTENTES.reportarIncidencia, idempotencyKey: key, requestHash: hash,
      ejecutar: async (cliente) => { const item = await incidenciasService.reportar({ vehiculoId: ids.maquinaria,
        choferId: ids.supervisor, descripcion }, cliente); return { status: 201, body: item, resourceId: item.id }; } });
    expect(retry.replayed).toBe(false);
  });

  it('carga con partidas, comprobante y movimiento se crea una sola vez', async () => {
    const solicitudId = randomUUID(); const partidaId = randomUUID(); const folio = `FA-CARGA-${randomUUID()}`;
    await pool.query(`INSERT INTO solicitudes_autorizacion
      (id,chofer_id,vehiculo_id,litros_solicitados,litros_autorizados,costo_estimado,es_urgente,
       actividad,fecha_programada,estado,folio_autorizacion)
      VALUES($1,$2,$3,40,40,400,false,'Carga idempotente',now(),'aprobada',$4)`,
      [solicitudId, ids.supervisor, ids.marimba, folio]);
    await pool.query(`INSERT INTO solicitud_partidas
      (id,solicitud_id,vehiculo_id,tipo,litros_solicitados,litros_autorizados,tipo_combustible,estado)
      VALUES($1,$2,$3,'carga_granel',40,40,'Di\u00e9sel','aprobada')`, [partidaId, solicitudId, ids.marimba]);
    const key = randomUUID();
    const comando = () => ejecutarIdempotente({ usuarioId: ids.supervisor,
      operacion: OPERACIONES_IDEMPOTENTES.registrarCarga, idempotencyKey: key, requestHash: hash,
      ejecutar: async (cliente) => { const carga = await partidasService.registrarCargaConPartidas({
        usuarioId: ids.supervisor, vehiculoId: ids.marimba, folioAutorizacion: folio,
        partidas: [{ tipo: 'carga_granel', litros: 40, tipoCombustible: 'Di\u00e9sel' }],
        comprobantes: [{ concepto: 'carga_granel', folioEstacion: `T-${key}`, litrosIndicados: 40 }],
        kmAlCargar: 2, gasolinera: 'Estacion idempotente' }, cliente);
        return { status: 201, body: carga, resourceType: 'carga', resourceId: carga.carga.id as string }; },
    });
    const primero = await comando(); const replay = await comando();
    expect(replay).toMatchObject({ status: 201, resourceId: primero.resourceId, replayed: true });
    const conteo = await pool.query<{ cargas: string; partidas: string; comprobantes: string; movimientos: string }>(
      `SELECT (SELECT count(*) FROM cargas WHERE solicitud_id=$1) cargas,
       (SELECT count(*) FROM carga_partidas WHERE solicitud_id=$1) partidas,
       (SELECT count(*) FROM comprobantes_estacion ce JOIN cargas c ON c.id=ce.carga_id WHERE c.solicitud_id=$1) comprobantes,
       (SELECT count(*) FROM movimientos_inventario_marimba m JOIN carga_partidas cp ON cp.id=m.carga_partida_id WHERE cp.solicitud_id=$1) movimientos`,
      [solicitudId]);
    expect(conteo.rows[0]).toEqual({ cargas: '1', partidas: '1', comprobantes: '1', movimientos: '1' });
  });

  it('cierre reproduce exactamente el resultado original', async () => {
    const cargaId = randomUUID(); const folio = `FA-CIERRE-${randomUUID()}`; const solicitudId = randomUUID();
    await pool.query(`INSERT INTO solicitudes_autorizacion
      (id,chofer_id,vehiculo_id,litros_solicitados,litros_autorizados,costo_estimado,es_urgente,
       actividad,fecha_programada,estado,folio_autorizacion)
      VALUES($1,$2,$3,10,10,100,false,'Cierre fixture',now(),'aprobada',$4)`,
      [solicitudId, ids.supervisor, ids.maquinaria, folio]);
    await pool.query(`INSERT INTO cargas(id,chofer_id,vehiculo_id,folio_autorizacion,litros_cargados,km_al_cargar,gasolinera)
      VALUES($1,$2,$3,$4,10,100,'Fixture')`, [cargaId, ids.supervisor, ids.maquinaria, folio]);
    const key = randomUUID();
    const comando = () => ejecutarIdempotente({ usuarioId: ids.supervisor,
      operacion: OPERACIONES_IDEMPOTENTES.crearCierreDia, idempotencyKey: key, requestHash: hash,
      ejecutar: async (cliente) => { const cierre = await cierresService.cerrarDia({ choferId: ids.supervisor,
        cargaId, kmFinal: 150, fotoTableroPath: '/uploads/33333333-3333-4333-8333-333333333333.jpg' }, cliente);
        return { status: 201, body: cierre, resourceType: 'cierre_dia', resourceId: cierre.id }; },
    });
    const primero = await comando(); const replay = await comando();
    expect(replay.status).toBe(primero.status); expect(replay.body).toEqual(primero.body);
    expect(replay.resourceId).toBe(primero.resourceId);
    expect((await pool.query('SELECT 1 FROM cierres_dia WHERE carga_id=$1', [cargaId])).rowCount).toBe(1);
  });

  it('constraints reales rechazan hash y status invalidos', async () => {
    await expect(pool.query(`INSERT INTO operaciones_idempotentes
      (usuario_id,operacion,idempotency_key,request_hash) VALUES($1,'incidencia.reportar',$2,'INVALIDO')`,
      [ids.supervisor, randomUUID()])).rejects.toMatchObject({ code: '23514' });
    await expect(pool.query(`INSERT INTO operaciones_idempotentes
      (usuario_id,operacion,idempotency_key,request_hash,http_status,completed_at)
      VALUES($1,'incidencia.reportar',$2,$3,500,now())`, [ids.supervisor, randomUUID(), hash]))
      .rejects.toMatchObject({ code: '23514' });
  });
});
