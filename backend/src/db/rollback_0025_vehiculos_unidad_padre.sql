-- ROLLBACK de 0025_vehiculos_unidad_padre.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0025_vehiculos_unidad_padre.sql
--
-- Sin guardas especiales: `unidad_padre_id` es la única columna nueva y
-- no participa de ningún otro cálculo — borrarla no puede corromper datos
-- de otra migración (a diferencia de 0021/pipa-marimba).

BEGIN;

DROP INDEX IF EXISTS idx_vehiculos_unidad_padre;
ALTER TABLE vehiculos DROP CONSTRAINT IF EXISTS chk_unidad_padre_no_autorreferencia;
ALTER TABLE vehiculos DROP COLUMN IF EXISTS unidad_padre_id;

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0025_vehiculos_unidad_padre.sql';
