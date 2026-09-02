import { pool } from './pool';

async function auditar(): Promise<void> {
  const [migraciones, total, duplicados] = await Promise.all([
    pool.query<{ name: string }>(
      'SELECT name FROM schema_migrations ORDER BY name DESC LIMIT 3',
    ),
    pool.query<{ total: number }>(
      'SELECT COUNT(*)::int AS total FROM solicitudes_autorizacion',
    ),
    pool.query<{ grupos: number }>(
      `SELECT COUNT(*)::int AS grupos FROM (
         SELECT chofer_id, vehiculo_id,
           (fecha_programada AT TIME ZONE 'America/Mexico_City')::date
         FROM solicitudes_autorizacion
         WHERE estado='pendiente'
         GROUP BY 1,2,3 HAVING COUNT(*) > 1
       ) duplicados`,
    ),
  ]);
  // Solo metadatos y conteos agregados: no imprime usuarios, payloads o secretos.
  process.stdout.write(`${JSON.stringify({
    migracionesRecientes: migraciones.rows.map((fila) => fila.name),
    totalSolicitudes: total.rows[0]?.total ?? 0,
    gruposPendientesDuplicados: duplicados.rows[0]?.grupos ?? 0,
  })}\n`);
}

auditar()
  .finally(() => pool.end())
  .catch(() => process.exit(1));
