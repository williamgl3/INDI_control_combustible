-- ROLLBACK de 0027_despachos_marimba_recorrido.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0027_despachos_marimba_recorrido.sql
--
-- Falla a propósito si ya existe algún despacho con `sitio` NULL (creado
-- vía el flujo de recorrido, que hereda el frente en vez de pedirlo) —
-- evita perder esa información en silencio al restaurar el NOT NULL.

BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM despachos_marimba WHERE sitio IS NULL) THEN
    RAISE EXCEPTION 'Hay despachos con sitio NULL (creados vía recorrido) — no se puede restaurar NOT NULL sin decidir qué poner ahí.';
  END IF;
END $$;

DROP INDEX IF EXISTS idx_despachos_marimba_recorrido;
ALTER TABLE despachos_marimba DROP COLUMN IF EXISTS recorrido_id;
ALTER TABLE despachos_marimba ALTER COLUMN sitio SET NOT NULL;

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0027_despachos_marimba_recorrido.sql';
