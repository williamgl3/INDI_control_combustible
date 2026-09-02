-- ROLLBACK de 0026_recorridos_marimba.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0026_recorridos_marimba.sql
--
-- Se niega a correr si ya hay despachos_marimba.recorrido_id apuntando a
-- esta tabla (migración 0027) — borrarla primero dejaría esa columna con
-- FKs colgando. Corre 0027 en reversa antes que esta.

BEGIN;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'despachos_marimba' AND column_name = 'recorrido_id'
  ) THEN
    RAISE EXCEPTION 'despachos_marimba.recorrido_id todavía existe — revierte 0027 primero.';
  END IF;
END $$;

DELETE FROM configuracion WHERE clave = 'tolerancia_merma_marimba_litros';
DROP TABLE recorridos_marimba;

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0026_recorridos_marimba.sql';
