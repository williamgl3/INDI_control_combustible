import { randomUUID } from 'node:crypto';
import { copyFile, readdir } from 'node:fs/promises';
import { join } from 'node:path';
import { pool } from './pool';
import { enviarSolicitud } from '../services/solicitudesService';
import { fingerprintSolicitud } from '../utils/idempotenciaSolicitud';
import { ApiError } from '../utils/asyncHandler';
import { UPLOADS_DIR } from '../middleware/upload';

async function probar(): Promise<void> {
  const { rows: usuarios } = await pool.query<{ id: string }>(
    "SELECT id FROM usuarios WHERE rol='chofer' AND activo=true ORDER BY creado_en LIMIT 1",
  );
  const { rows: vehiculos } = await pool.query<{ id: string }>(
    `SELECT id FROM vehiculos
     WHERE activo=true AND tipo_unidad IN ('Vehiculo','Vehículo','Maquinaria')
       AND tipo_combustible IS NULL
     ORDER BY creado_en LIMIT 1`,
  );
  if (!usuarios[0] || !vehiculos[0]) {
    throw new Error('Falta una cuenta o unidad local apta para la prueba aislada.');
  }

  const idempotencyKey = randomUUID();
  const fechaProgramada = '2099-12-29T06:00:00.000Z';
  const nombreFoto = `prueba-idempotencia-${idempotencyKey}.jpeg`;
  await copyFile(
    join(process.cwd(), '..', 'frontend', 'assets', 'images', 'logo_indi.jpeg'),
    join(UPLOADS_DIR, nombreFoto),
  );
  const base = {
    choferId: usuarios[0].id,
    rol: 'chofer' as const,
    vehiculoId: vehiculos[0].id,
    litrosSolicitados: 37.25,
    esUrgente: false,
    motivoChofer: null,
    actividad: 'Prueba automatizada de idempotencia',
    fechaProgramada,
    fotoTableroPath: `/uploads/${nombreFoto}`,
    idempotencyKey,
  };
  const payloadFingerprint = fingerprintSolicitud({
    ...base,
    fotoSha256: '0'.repeat(64),
  });

  const resultados = await Promise.all(
    Array.from({ length: 10 }, () => enviarSolicitud({ ...base, payloadFingerprint })),
  );
  const ids = new Set(resultados.map((resultado) => resultado.id));

  let conflictoClave = false;
  try {
    await enviarSolicitud({
      ...base,
      actividad: 'Payload deliberadamente diferente',
      payloadFingerprint: 'f'.repeat(64),
    });
  } catch (error) {
    conflictoClave =
      error instanceof ApiError &&
      error.codigo === 'IDEMPOTENCY_KEY_REUSED_WITH_DIFFERENT_PAYLOAD';
  }

  let conflictoNegocio = false;
  try {
    await enviarSolicitud({
      ...base,
      idempotencyKey: randomUUID(),
      payloadFingerprint,
    });
  } catch (error) {
    conflictoNegocio =
      error instanceof ApiError && error.codigo === 'SOLICITUD_PENDIENTE_EXISTENTE';
  }

  const { rows: verificacion } = await pool.query<{
    filas: number;
    evidencias: number;
  }>(
    `SELECT COUNT(*)::int AS filas,
       COUNT(foto_tablero_path)::int AS evidencias
     FROM solicitudes_autorizacion
     WHERE chofer_id=$1 AND idempotency_key=$2`,
    [base.choferId, idempotencyKey],
  );
  const archivos = (await readdir(UPLOADS_DIR)).filter((nombre) =>
    nombre.includes(idempotencyKey),
  ).length;
  process.stdout.write(`${JSON.stringify({
    peticionesSimultaneas: resultados.length,
    idsDistintos: ids.size,
    creaciones: resultados.filter((r) => !r.replayed).length,
    replays: resultados.filter((r) => r.replayed).length,
    conflictoClave,
    conflictoNegocio,
    filas: verificacion[0]?.filas ?? 0,
    evidencias: verificacion[0]?.evidencias ?? 0,
    archivos,
  })}\n`);
}

probar()
  .finally(() => pool.end())
  .catch(() => process.exit(1));
