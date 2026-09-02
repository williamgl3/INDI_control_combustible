-- ROLLBACK de 0028_vehiculos_ubicacion.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0028_vehiculos_ubicacion.sql

BEGIN;

DROP INDEX IF EXISTS idx_vehiculos_ubicacion;
ALTER TABLE vehiculos DROP COLUMN IF EXISTS ubicacion;

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0028_vehiculos_ubicacion.sql';
