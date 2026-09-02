import { randomUUID } from 'node:crypto';
import type { DatabaseError } from 'pg';
import { describe, expect, it } from 'vitest';
import { pool } from '../../src/db/pool';
import * as partidasService from '../../src/services/marimbaPartidasService';
import * as recorridosService from '../../src/services/recorridosMarimbaService';
import * as cargasService from '../../src/services/cargasService';
import { ApiError } from '../../src/utils/asyncHandler';

const ejecutar = process.env.RUN_MARIMBA_INTEGRATION === '1';
const suite = ejecutar ? describe.sequential : describe.skip;

function protegerBaseAislada(): void {
  const raw = process.env.DATABASE_URL ?? '';
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error('La integración requiere una URL válida para la base temporal.');
  }
  const hostPermitido = url.hostname === '127.0.0.1' || url.hostname === 'localhost';
  if (!hostPermitido || !url.pathname.toLowerCase().endsWith('_test') || url.port === '5432') {
    throw new Error('La integración requiere una base temporal local, terminada en _test y fuera del puerto 5432.');
  }
}

interface Fixture {
  supervisor: string;
  admin: string;
  marimba: string;
  maquinariaDiesel: string;
  maquinariaMagna: string;
}

interface SolicitudAutorizada {
  id: string;
  folio: string;
}

async function crearFixture(): Promise<Fixture> {
  protegerBaseAislada();
  const suffix = randomUUID().replaceAll('-', '');
  const fixture: Fixture = {
    supervisor: randomUUID(),
    admin: randomUUID(),
    marimba: randomUUID(),
    maquinariaDiesel: randomUUID(),
    maquinariaMagna: randomUUID(),
  };
  await pool.query(
    `INSERT INTO usuarios(id,usuario,password_hash,nombre,correo,rol) VALUES
     ($1,$2,'no-login','Supervisor ficticio',$3,'supervisor'),
     ($4,$5,'no-login','Administrativo ficticio',$6,'administrativo')`,
    [
      fixture.supervisor,
      `supervisor-${suffix}`,
      `supervisor-${suffix}@test.invalid`,
      fixture.admin,
      `admin-${suffix}`,
      `admin-${suffix}@test.invalid`,
    ],
  );
  await pool.query(
    `INSERT INTO vehiculos(id,tipo_unidad,numero_economico,tipo_combustible,modelo,activo) VALUES
     ($1,'Marimba',$2,'Diésel','Unidad abastecedora ficticia',true),
     ($3,'Maquinaria',$4,'Diésel','Maquinaria ficticia',true),
     ($5,'Maquinaria',$6,'Magna','Maquinaria ficticia',true)`,
    [
      fixture.marimba,
      `MAR-${suffix}`,
      fixture.maquinariaDiesel,
      `MAQ-D-${suffix}`,
      fixture.maquinariaMagna,
      `MAQ-M-${suffix}`,
    ],
  );
  return fixture;
}

async function crearSolicitudAutorizada(
  fixture: Fixture,
  tipoCombustible: 'Diésel' | 'Magna',
  litros = 100,
): Promise<SolicitudAutorizada> {
  const solicitud = await partidasService.crearSolicitudConPartidas({
    solicitanteId: fixture.supervisor,
    rol: 'supervisor',
    vehiculoId: fixture.marimba,
    actividad: 'Prueba temporal',
    fechaProgramada: new Date().toISOString(),
    esUrgente: false,
    partidas: [{ tipo: 'carga_granel', litros, tipoCombustible }],
  });
  const autorizacion = await partidasService.autorizarPartidas({
    solicitudId: solicitud.id,
    aprobadaPor: 'Administrativo ficticio',
    aprobadaPorId: fixture.admin,
    decisiones: [{ tipo: 'carga_granel', aprobar: true, litrosAutorizados: litros }],
  });
  expect(autorizacion.folioAutorizacion).not.toBeNull();
  return { id: solicitud.id, folio: autorizacion.folioAutorizacion! };
}

async function registrarEntrada(
  fixture: Fixture,
  solicitud: SolicitudAutorizada,
  tipoCombustible: 'Diésel' | 'Magna',
  litros: number,
): Promise<void> {
  await partidasService.registrarCargaConPartidas({
    usuarioId: fixture.supervisor,
    vehiculoId: fixture.marimba,
    folioAutorizacion: solicitud.folio,
    kmAlCargar: 10,
    gasolinera: 'Estación ficticia',
    partidas: [{ tipo: 'carga_granel', litros, tipoCombustible }],
    comprobantes: [],
  });
}

async function contar(tabla: string, columna: string, valor: string): Promise<number> {
  const tablasPermitidas = new Set([
    'cargas',
    'carga_partidas',
    'comprobantes_estacion',
    'movimientos_inventario_marimba',
  ]);
  const columnasPermitidas = new Set(['id', 'solicitud_id', 'carga_id', 'marimba_id']);
  if (!tablasPermitidas.has(tabla) || !columnasPermitidas.has(columna)) {
    throw new Error('Consulta de prueba no permitida.');
  }
  const { rows } = await pool.query<{ total: string }>(
    `SELECT count(*) AS total FROM ${tabla} WHERE ${columna}=$1`,
    [valor],
  );
  return Number(rows[0]!.total);
}

async function esperarIntegridad(operacion: Promise<unknown>): Promise<DatabaseError> {
  try {
    await operacion;
  } catch (error) {
    const databaseError = error as DatabaseError;
    expect(databaseError.code).toMatch(/^23/);
    return databaseError;
  }
  throw new Error('PostgreSQL aceptó una relación que debía rechazar.');
}

suite('cobertura PostgreSQL del flujo de unidad abastecedora', () => {
  it('un despacho Diésel no modifica el inventario Magna', async () => {
    const fixture = await crearFixture();
    const diesel = await crearSolicitudAutorizada(fixture, 'Diésel', 80);
    const magna = await crearSolicitudAutorizada(fixture, 'Magna', 90);
    await registrarEntrada(fixture, diesel, 'Diésel', 80);
    await registrarEntrada(fixture, magna, 'Magna', 90);
    const recorrido = await recorridosService.crearRecorrido({
      marimbaId: fixture.marimba,
      operadorId: fixture.supervisor,
      registradoPor: fixture.admin,
      frente: 'Frente ficticio',
      tipoCombustible: 'Diésel',
    });

    await recorridosService.agregarDespacho(recorrido.id, {
      marimbaId: fixture.marimba,
      vehiculoDestinoId: fixture.maquinariaDiesel,
      operadorTexto: 'Operador ficticio',
      registradoPor: fixture.admin,
      actorRol: 'administrativo',
      tipoCombustible: 'Diésel',
      litrosSuministrados: 25,
      horometro: 10,
      fotoHorometroPath: '/uploads/horometro-ficticio.jpg',
      fotoEvidenciaPath: '/uploads/suministro-ficticio.jpg',
    });

    expect((await partidasService.saldoNuevoDeMarimba(fixture.marimba, 'Diésel')).toFixed(2)).toBe('55.00');
    expect((await partidasService.saldoNuevoDeMarimba(fixture.marimba, 'Magna')).toFixed(2)).toBe('90.00');
    const { rows } = await pool.query<{ tipo_combustible: string }>(
      `SELECT tipo_combustible FROM movimientos_inventario_marimba
       WHERE recorrido_id=$1 AND tipo='despacho_maquinaria'`,
      [recorrido.id],
    );
    expect(rows).toEqual([{ tipo_combustible: 'Diésel' }]);
  });

  it('dos cargas concurrentes no superan la autorización ni dejan filas parciales', async () => {
    const fixture = await crearFixture();
    const solicitud = await crearSolicitudAutorizada(fixture, 'Magna', 100);
    const crearCarga = (folioTicket: string) =>
      partidasService.registrarCargaConPartidas({
        usuarioId: fixture.supervisor,
        vehiculoId: fixture.marimba,
        folioAutorizacion: solicitud.folio,
        kmAlCargar: 10,
        gasolinera: 'Estación ficticia',
        partidas: [{ tipo: 'carga_granel', litros: 60, tipoCombustible: 'Magna' }],
        comprobantes: [{ folioEstacion: folioTicket, concepto: 'carga_granel', litrosIndicados: 60 }],
      });

    const resultados = await Promise.allSettled([
      crearCarga(`T-${randomUUID()}`),
      crearCarga(`T-${randomUUID()}`),
    ]);
    expect(resultados.filter((resultado) => resultado.status === 'fulfilled')).toHaveLength(1);
    const rechazados = resultados.filter(
      (resultado): resultado is PromiseRejectedResult => resultado.status === 'rejected',
    );
    expect(rechazados).toHaveLength(1);
    expect(rechazados[0]!.reason).toBeInstanceOf(ApiError);
    expect((rechazados[0]!.reason as ApiError).status).toBe(409);

    const { rows } = await pool.query<{
      litros: string;
      cargas: string;
      partidas: string;
      movimientos: string;
      comprobantes: string;
    }>(
      `SELECT
         COALESCE(SUM(cp.litros_cargados),0) AS litros,
         count(DISTINCT c.id) AS cargas,
         count(DISTINCT cp.id) AS partidas,
         count(DISTINCT m.id) AS movimientos,
         count(DISTINCT ce.id) AS comprobantes
       FROM solicitudes_autorizacion s
       LEFT JOIN cargas c ON c.solicitud_id=s.id
       LEFT JOIN carga_partidas cp ON cp.carga_id=c.id
       LEFT JOIN movimientos_inventario_marimba m ON m.carga_partida_id=cp.id
       LEFT JOIN comprobantes_estacion ce ON ce.carga_id=c.id
       WHERE s.id=$1`,
      [solicitud.id],
    );
    expect(rows[0]).toMatchObject({
      litros: '60.00',
      cargas: '1',
      partidas: '1',
      movimientos: '1',
      comprobantes: '1',
    });
    expect((await partidasService.saldoNuevoDeMarimba(fixture.marimba, 'Magna')).toFixed(2)).toBe('60.00');
  });

  it('PostgreSQL rechaza una partida perteneciente a otra solicitud', async () => {
    const fixture = await crearFixture();
    const solicitudA = await crearSolicitudAutorizada(fixture, 'Diésel');
    const solicitudB = await crearSolicitudAutorizada(fixture, 'Magna');
    const { rows: partidasB } = await pool.query<{ id: string }>(
      'SELECT id FROM solicitud_partidas WHERE solicitud_id=$1',
      [solicitudB.id],
    );
    const cargaId = randomUUID();
    await pool.query(
      `INSERT INTO cargas(id,chofer_id,vehiculo_id,folio_autorizacion,litros_cargados,
       km_al_cargar,gasolinera,solicitud_id) VALUES($1,$2,$3,$4,10,1,'Estación ficticia',$5)`,
      [cargaId, fixture.supervisor, fixture.marimba, solicitudA.folio, solicitudA.id],
    );

    await esperarIntegridad(
      pool.query(
        `INSERT INTO carga_partidas(carga_id,solicitud_id,vehiculo_id,solicitud_partida_id,
         tipo,tipo_combustible,litros_cargados)
         VALUES($1,$2,$3,$4,'carga_granel','Magna',10)`,
        [cargaId, solicitudA.id, fixture.marimba, partidasB[0]!.id],
      ),
    );
    expect(await contar('carga_partidas', 'carga_id', cargaId)).toBe(0);
  });

  it('PostgreSQL rechaza un comprobante asociado a la partida de otra carga', async () => {
    const fixture = await crearFixture();
    const solicitudA = await crearSolicitudAutorizada(fixture, 'Diésel');
    const solicitudB = await crearSolicitudAutorizada(fixture, 'Magna');
    await registrarEntrada(fixture, solicitudA, 'Diésel', 10);
    await registrarEntrada(fixture, solicitudB, 'Magna', 10);
    const { rows } = await pool.query<{ carga_id: string; partida_id: string; tipo: string }>(
      `SELECT cp.carga_id,cp.id AS partida_id,cp.tipo FROM carga_partidas cp
       JOIN cargas c ON c.id=cp.carga_id WHERE c.solicitud_id IN ($1,$2) ORDER BY c.solicitud_id`,
      [solicitudA.id, solicitudB.id],
    );
    const [primera, segunda] = rows;
    expect(primera).toBeDefined();
    expect(segunda).toBeDefined();

    await esperarIntegridad(
      pool.query(
        `INSERT INTO comprobantes_estacion(carga_id,carga_partida_id,concepto,folio_estacion,
         gasolinera,registrado_por) VALUES($1,$2,$3,$4,'Estación ficticia',$5)`,
        [primera!.carga_id, segunda!.partida_id, segunda!.tipo, `T-${randomUUID()}`, fixture.supervisor],
      ),
    );
    expect(await contar('comprobantes_estacion', 'carga_id', primera!.carga_id)).toBe(0);
  });

  it('PostgreSQL rechaza una entrada granel desde consumo propio o con combustible distinto', async () => {
    const fixture = await crearFixture();
    const solicitud = await partidasService.crearSolicitudConPartidas({
      solicitanteId: fixture.supervisor,
      rol: 'supervisor',
      vehiculoId: fixture.marimba,
      actividad: 'Prueba temporal',
      fechaProgramada: new Date().toISOString(),
      esUrgente: false,
      partidas: [
        { tipo: 'consumo_propio', litros: 20, tipoCombustible: 'Diésel' },
        { tipo: 'carga_granel', litros: 20, tipoCombustible: 'Magna' },
      ],
    });
    const autorizacion = await partidasService.autorizarPartidas({
      solicitudId: solicitud.id,
      aprobadaPor: 'Administrativo ficticio',
      aprobadaPorId: fixture.admin,
      decisiones: [
        { tipo: 'consumo_propio', aprobar: true, litrosAutorizados: 20 },
        { tipo: 'carga_granel', aprobar: true, litrosAutorizados: 20 },
      ],
    });
    const { rows: partidas } = await pool.query<{ id: string; tipo: string }>(
      'SELECT id,tipo FROM solicitud_partidas WHERE solicitud_id=$1 ORDER BY tipo',
      [solicitud.id],
    );
    const cargaId = randomUUID();
    expect(autorizacion.folioAutorizacion).not.toBeNull();
    await pool.query(
      `INSERT INTO cargas(id,chofer_id,vehiculo_id,folio_autorizacion,litros_cargados,
       km_al_cargar,gasolinera,solicitud_id) VALUES($1,$2,$3,$4,40,1,'Estación ficticia',$5)`,
      [
        cargaId,
        fixture.supervisor,
        fixture.marimba,
        autorizacion.folioAutorizacion,
        solicitud.id,
      ],
    );
    const ids = new Map<string, string>();
    for (const partida of partidas) {
      const cargaPartidaId = randomUUID();
      ids.set(partida.tipo, cargaPartidaId);
      await pool.query(
        `INSERT INTO carga_partidas(id,carga_id,solicitud_id,vehiculo_id,solicitud_partida_id,
         tipo,tipo_combustible,litros_cargados) VALUES($1,$2,$3,$4,$5,$6,$7,20)`,
        [
          cargaPartidaId,
          cargaId,
          solicitud.id,
          fixture.marimba,
          partida.id,
          partida.tipo,
          partida.tipo === 'consumo_propio' ? 'Diésel' : 'Magna',
        ],
      );
    }

    await esperarIntegridad(
      pool.query(
        `INSERT INTO movimientos_inventario_marimba(marimba_id,tipo_combustible,tipo,litros,
         carga_partida_id,carga_partida_tipo,registrado_por)
         VALUES($1,'Diésel','entrada_granel',20,$2,'carga_granel',$3)`,
        [fixture.marimba, ids.get('consumo_propio'), fixture.supervisor],
      ),
    );
    await esperarIntegridad(
      pool.query(
        `INSERT INTO movimientos_inventario_marimba(marimba_id,tipo_combustible,tipo,litros,
         carga_partida_id,carga_partida_tipo,registrado_por)
         VALUES($1,'Diésel','entrada_granel',20,$2,'carga_granel',$3)`,
        [fixture.marimba, ids.get('carga_granel'), fixture.supervisor],
      ),
    );
    expect(await contar('movimientos_inventario_marimba', 'marimba_id', fixture.marimba)).toBe(0);
  });

  it('una transacción fallida revierte carga, partida, comprobante y movimiento', async () => {
    const fixture = await crearFixture();
    const solicitud = await crearSolicitudAutorizada(fixture, 'Magna');
    const { rows: partidas } = await pool.query<{ id: string }>(
      'SELECT id FROM solicitud_partidas WHERE solicitud_id=$1',
      [solicitud.id],
    );
    const cargaId = randomUUID();
    const cargaPartidaId = randomUUID();
    const cliente = await pool.connect();
    try {
      await cliente.query('BEGIN');
      await cliente.query(
        `INSERT INTO cargas(id,chofer_id,vehiculo_id,folio_autorizacion,litros_cargados,
         km_al_cargar,gasolinera,solicitud_id) VALUES($1,$2,$3,$4,10,1,'Estación ficticia',$5)`,
        [cargaId, fixture.supervisor, fixture.marimba, solicitud.folio, solicitud.id],
      );
      await cliente.query(
        `INSERT INTO carga_partidas(id,carga_id,solicitud_id,vehiculo_id,solicitud_partida_id,
         tipo,tipo_combustible,litros_cargados)
         VALUES($1,$2,$3,$4,$5,'carga_granel','Magna',10)`,
        [cargaPartidaId, cargaId, solicitud.id, fixture.marimba, partidas[0]!.id],
      );
      await cliente.query(
        `INSERT INTO comprobantes_estacion(carga_id,carga_partida_id,concepto,folio_estacion,
         gasolinera,registrado_por) VALUES($1,$2,'carga_granel',$3,'Estación ficticia',$4)`,
        [cargaId, cargaPartidaId, `T-${randomUUID()}`, fixture.supervisor],
      );
      await cliente.query(
        `INSERT INTO movimientos_inventario_marimba(marimba_id,tipo_combustible,tipo,litros,
         carga_partida_id,carga_partida_tipo,registrado_por)
         VALUES($1,'Magna','entrada_granel',10,$2,'carga_granel',$3)`,
        [fixture.marimba, cargaPartidaId, fixture.supervisor],
      );
      await expect(
        cliente.query(
          `INSERT INTO movimientos_inventario_marimba(marimba_id,tipo_combustible,tipo,litros,
           carga_partida_id,carga_partida_tipo,registrado_por)
           VALUES($1,'Magna','entrada_granel',10,$2,'carga_granel',$3)`,
          [fixture.marimba, cargaPartidaId, fixture.supervisor],
        ),
      ).rejects.toMatchObject({ code: '23505' });
      await cliente.query('ROLLBACK');
    } finally {
      cliente.release();
    }

    expect(await contar('cargas', 'id', cargaId)).toBe(0);
    expect(await contar('carga_partidas', 'carga_id', cargaId)).toBe(0);
    expect(await contar('comprobantes_estacion', 'carga_id', cargaId)).toBe(0);
    expect(await contar('movimientos_inventario_marimba', 'marimba_id', fixture.marimba)).toBe(0);
  });

  it('persiste cantidad declarada true sin medidor y false con medidor', async () => {
    const fixture = await crearFixture();
    const solicitud = await crearSolicitudAutorizada(fixture, 'Magna', 100);
    await registrarEntrada(fixture, solicitud, 'Magna', 100);
    const recorrido = await recorridosService.crearRecorrido({
      marimbaId: fixture.marimba,
      operadorId: fixture.supervisor,
      registradoPor: fixture.admin,
      frente: 'Frente ficticio',
      tipoCombustible: 'Magna',
    });
    const declarado = await recorridosService.agregarDespacho(recorrido.id, {
      marimbaId: fixture.marimba,
      vehiculoDestinoId: fixture.maquinariaMagna,
      operadorTexto: 'Operador ficticio',
      registradoPor: fixture.admin,
      actorRol: 'administrativo',
      tipoCombustible: 'Magna',
      litrosSuministrados: 10,
      horometro: 10,
      fotoHorometroPath: '/uploads/horometro-declarado.jpg',
      fotoEvidenciaPath: '/uploads/suministro-declarado.jpg',
    });
    const medido = await recorridosService.agregarDespacho(recorrido.id, {
      marimbaId: fixture.marimba,
      vehiculoDestinoId: fixture.maquinariaMagna,
      operadorTexto: 'Operador ficticio',
      registradoPor: fixture.admin,
      actorRol: 'administrativo',
      tipoCombustible: 'Magna',
      medidorInicial: 100,
      medidorFinal: 115,
      horometro: 11,
      fotoHorometroPath: '/uploads/horometro-medidor.jpg',
      fotoMedidorPath: '/uploads/medidor.jpg',
    });
    const { rows } = await pool.query<{ id: string; cantidad_declarada: boolean | null }>(
      'SELECT id,cantidad_declarada FROM despachos_marimba WHERE id IN ($1,$2)',
      [declarado.id, medido.id],
    );
    const valores = new Map(rows.map((fila) => [fila.id, fila.cantidad_declarada]));
    expect(valores.get(declarado.id)).toBe(true);
    expect(valores.get(medido.id)).toBe(false);
  });

  it('PostgreSQL rechaza un movimiento que cruza despacho y recorrido', async () => {
    const fixture = await crearFixture();
    const solicitud = await crearSolicitudAutorizada(fixture, 'Magna', 100);
    await registrarEntrada(fixture, solicitud, 'Magna', 100);
    const recorridoA = await recorridosService.crearRecorrido({
      marimbaId: fixture.marimba,
      operadorId: fixture.supervisor,
      registradoPor: fixture.admin,
      frente: 'Frente A',
      tipoCombustible: 'Magna',
    });
    await pool.query("UPDATE recorridos_marimba SET estado='cerrado' WHERE id=$1", [recorridoA.id]);
    const recorridoB = await recorridosService.crearRecorrido({
      marimbaId: fixture.marimba,
      operadorId: fixture.supervisor,
      registradoPor: fixture.admin,
      frente: 'Frente B',
      tipoCombustible: 'Magna',
    });
    const despachoId = randomUUID();
    await pool.query(
      `INSERT INTO despachos_marimba(id,marimba_id,vehiculo_destino_id,operador_texto,
       litros_suministrados,estado,registrado_por,recorrido_id,responsable_id,tipo_combustible,
       cantidad_declarada) VALUES($1,$2,$3,'Operador ficticio',10,'activo',$4,$5,$6,'Magna',true)`,
      [
        despachoId,
        fixture.marimba,
        fixture.maquinariaMagna,
        fixture.admin,
        recorridoA.id,
        fixture.supervisor,
      ],
    );

    await esperarIntegridad(
      pool.query(
        `INSERT INTO movimientos_inventario_marimba(marimba_id,tipo_combustible,tipo,litros,
         despacho_id,recorrido_id,registrado_por,responsable_id)
         VALUES($1,'Magna','despacho_maquinaria',10,$2,$3,$4,$5)`,
        [fixture.marimba, despachoId, recorridoB.id, fixture.admin, fixture.supervisor],
      ),
    );
    const { rows } = await pool.query<{ total: string }>(
      'SELECT count(*) AS total FROM movimientos_inventario_marimba WHERE despacho_id=$1',
      [despachoId],
    );
    expect(Number(rows[0]!.total)).toBe(0);
    expect((await partidasService.saldoNuevoDeMarimba(fixture.marimba, 'Magna')).toFixed(2)).toBe('100.00');
  });

  it('acepta la forma histórica con cantidad declarada desconocida', async () => {
    const fixture = await crearFixture();
    const despachoId = randomUUID();
    await pool.query(
      `INSERT INTO despachos_marimba(id,marimba_id,destino_texto,operador_texto,
       litros_suministrados,estado,registrado_por)
       VALUES($1,$2,'Destino histórico','Operador histórico',10,'activo',$3)`,
      [despachoId, fixture.marimba, fixture.admin],
    );
    const { rows } = await pool.query<{ cantidad_declarada: boolean | null }>(
      'SELECT cantidad_declarada FROM despachos_marimba WHERE id=$1',
      [despachoId],
    );
    expect(rows[0]!.cantidad_declarada).toBeNull();
  });

  it('mantiene compatible el registro convencional de una carga', async () => {
    const fixture = await crearFixture();
    await pool.query(
      `INSERT INTO precios_combustible(tipo_combustible,precio_por_litro,vigente_desde,
       registrado_por) VALUES('Diésel',20,now() - interval '1 minute',$1)`,
      [fixture.admin],
    );
    const folioEsperado = `CONV-${randomUUID()}`;
    const { rows: solicitudes } = await pool.query<{ folio_autorizacion: string }>(
      `INSERT INTO solicitudes_autorizacion(
         chofer_id,vehiculo_id,litros_solicitados,litros_autorizados,costo_estimado,
         es_urgente,actividad,fecha_programada,estado,aprobada_por,folio_autorizacion)
       VALUES($1,$2,20,20,400,false,'Carga convencional ficticia',now(),'aprobada',
         'Administrativo ficticio',$3)
       RETURNING folio_autorizacion`,
      [fixture.supervisor, fixture.maquinariaDiesel, folioEsperado],
    );
    const carga = await cargasService.registrarCarga({
      choferId: fixture.supervisor,
      vehiculoId: fixture.maquinariaDiesel,
      folioAutorizacion: solicitudes[0]!.folio_autorizacion,
      litrosCargados: 20,
      kmAlCargar: 100,
      gasolinera: 'Estación ficticia',
    });
    const { rows } = await pool.query<{
      solicitud_id: string | null;
      partidas: string;
      movimientos: string;
    }>(
      `SELECT c.solicitud_id,
        (SELECT count(*) FROM carga_partidas cp WHERE cp.carga_id=c.id) AS partidas,
        (SELECT count(*) FROM movimientos_inventario_marimba m
         JOIN carga_partidas cp ON cp.id=m.carga_partida_id WHERE cp.carga_id=c.id) AS movimientos
       FROM cargas c WHERE c.id=$1`,
      [carga.id],
    );
    expect(rows[0]).toMatchObject({ solicitud_id: null, partidas: '0', movimientos: '0' });
    expect(carga.litrosCargados).toBe(20);
  });
});
