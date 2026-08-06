-- ROLLBACK de 0022_vehiculos_combustible_opcional.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0022_vehiculos_combustible_opcional.sql
--
-- Falla a propósito si ya existe alguna fila con `tipo_combustible`
-- NULL (ej. maquinaria importada sin combustible confirmado) — evita
-- perder esa información en silencio.

BEGIN;

ALTER TABLE vehiculos DROP CONSTRAINT IF EXISTS chk_tipo_combustible_no_vacio;
ALTER TABLE vehiculos ALTER COLUMN tipo_combustible SET NOT NULL;

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0022_vehiculos_combustible_opcional.sql';
