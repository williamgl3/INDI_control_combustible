import type { PoolClient } from 'pg';

/** Serializa movimientos del mismo inventario sin mezclar combustibles. */
export async function bloquearInventario(
  cliente: PoolClient,
  unidadId: string,
  tipoCombustible: string,
): Promise<void> {
  await cliente.query(
    'SELECT pg_advisory_xact_lock(hashtextextended($1, 0))',
    [`inventario:${unidadId}:${tipoCombustible}`],
  );
}
