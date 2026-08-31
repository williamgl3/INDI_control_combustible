import { randomUUID } from 'node:crypto';
import { beforeAll, describe, expect, it } from 'vitest';
import { pool } from '../../src/db/pool';
import * as partidasService from '../../src/services/marimbaPartidasService';
import * as recorridosService from '../../src/services/recorridosMarimbaService';

const ejecutar = process.env.RUN_MARIMBA_INTEGRATION === '1';
const suite = ejecutar ? describe.sequential : describe.skip;

function protegerBaseAislada(): void {
  const raw = process.env.DATABASE_URL ?? '';
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    throw new Error('DATABASE_URL de integración inválida.');
  }
  const hostPermitido = url.hostname === '127.0.0.1' || url.hostname === 'localhost';
  if (!hostPermitido || !url.pathname.toLowerCase().endsWith('_test') || url.port === '5432') {
    throw new Error(
      'La integración exige una base temporal local, terminada en _test y fuera del puerto 5432.',
    );
  }
}

const ids = {
  supervisor: randomUUID(),
  admin: randomUUID(),
  marimba: randomUUID(),
  maquinariaDiesel: randomUUID(),
  maquinariaMagna: randomUUID(),
};

suite('flujo Marimba/Pipa con PostgreSQL temporal', () => {
  beforeAll(async () => {
    protegerBaseAislada();
    const { rows } = await pool.query<{ total: string }>(
      'SELECT count(*) total FROM schema_migrations',
    );
    expect(Number(rows[0]?.total)).toBe(34);
    await pool.query(
      `INSERT INTO usuarios(id,usuario,password_hash,nombre,correo,rol) VALUES
       ($1,'supervisor-test','no-login','Supervisor','supervisor@test.invalid','supervisor'),
       ($2,'admin-test','no-login','Admin','admin@test.invalid','administrativo')`,
      [ids.supervisor, ids.admin],
    );
    await pool.query(
      `INSERT INTO vehiculos(id,tipo_unidad,numero_economico,tipo_combustible,modelo,activo) VALUES
       ($1,'Marimba','MAR-TEST','Diésel','Marimba ficticia',true),
       ($2,'Maquinaria','MAQ-D-TEST','Diésel','Maquinaria ficticia',true),
       ($3,'Maquinaria','MAQ-M-TEST','Magna','Maquinaria ficticia',true)`,
      [ids.marimba, ids.maquinariaDiesel, ids.maquinariaMagna],
    );
  });

  it('separa inventario Diésel y Magna y evita consumo cruzado', async () => {
    const solicitud = await partidasService.crearSolicitudConPartidas({
      solicitanteId: ids.supervisor,
      rol: 'supervisor',
      vehiculoId: ids.marimba,
      actividad: 'Prueba aislada',
      fechaProgramada: new Date().toISOString(),
      esUrgente: false,
      partidas: [
        { tipo: 'consumo_propio', litros: 30, tipoCombustible: 'Diésel' },
        { tipo: 'carga_granel', litros: 100, tipoCombustible: 'Magna' },
      ],
    });
    await partidasService.autorizarPartidas({
      solicitudId: solicitud.id,
      aprobadaPor: 'Admin ficticio',
      aprobadaPorId: ids.admin,
      decisiones: [
        { tipo: 'consumo_propio', aprobar: true, litrosAutorizados: 30 },
        { tipo: 'carga_granel', aprobar: true, litrosAutorizados: 100 },
      ],
    });
    const autorizada = await pool.query<{ folio_autorizacion: string }>(
      'SELECT folio_autorizacion FROM solicitudes_autorizacion WHERE id=$1',
      [solicitud.id],
    );
    const carga = await partidasService.registrarCargaConPartidas({
      usuarioId: ids.supervisor,
      vehiculoId: ids.marimba,
      folioAutorizacion: autorizada.rows[0]!.folio_autorizacion,
      kmAlCargar: 10,
      gasolinera: 'Estación ficticia',
      partidas: [
        { tipo: 'consumo_propio', litros: 30, tipoCombustible: 'Diésel' },
        { tipo: 'carga_granel', litros: 100, tipoCombustible: 'Magna' },
      ],
      comprobantes: [
        {
          folioEstacion: 'TICKET-TEST',
          concepto: 'visita_completa',
          litrosIndicados: 130,
        },
      ],
    });

    expect(carga.saldosGranel.Magna).toBe('100.00');
    expect(carga.saldosGranel['Diésel']).toBeUndefined();
    expect(
      (await partidasService.saldoNuevoDeMarimba(ids.marimba, 'Diésel')).toFixed(2),
    ).toBe('0.00');

    const recorrido = await recorridosService.crearRecorrido({
      marimbaId: ids.marimba,
      operadorId: ids.supervisor,
      registradoPor: ids.admin,
      frente: 'Frente ficticio',
      tipoCombustible: 'Magna',
    });
    const resultados = await Promise.allSettled([
      recorridosService.agregarDespacho(recorrido.id, {
        marimbaId: ids.marimba,
        vehiculoDestinoId: ids.maquinariaMagna,
        operadorTexto: 'Operador ficticio',
        registradoPor: ids.admin,
        actorRol: 'administrativo',
        tipoCombustible: 'Magna',
        litrosSuministrados: 60,
        horometro: 10,
        fotoHorometroPath: '/uploads/test-h1.jpg',
        fotoEvidenciaPath: '/uploads/test-e1.jpg',
      }),
      recorridosService.agregarDespacho(recorrido.id, {
        marimbaId: ids.marimba,
        vehiculoDestinoId: ids.maquinariaMagna,
        operadorTexto: 'Operador ficticio',
        registradoPor: ids.admin,
        actorRol: 'administrativo',
        tipoCombustible: 'Magna',
        litrosSuministrados: 60,
        horometro: 10,
        fotoHorometroPath: '/uploads/test-h2.jpg',
        fotoEvidenciaPath: '/uploads/test-e2.jpg',
      }),
    ]);

    expect(resultados.filter((resultado) => resultado.status === 'fulfilled')).toHaveLength(1);
    expect(resultados.filter((resultado) => resultado.status === 'rejected')).toHaveLength(1);
    expect(
      (await partidasService.saldoNuevoDeMarimba(ids.marimba, 'Magna')).toFixed(2),
    ).toBe('40.00');
    expect(
      (await partidasService.saldoNuevoDeMarimba(ids.marimba, 'Diésel')).toFixed(2),
    ).toBe('0.00');
  });
});
