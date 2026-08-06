-- ROLLBACK de 0023_elimina_tope_semanal.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0023_elimina_tope_semanal.sql
--
-- Restaura la columna con su default anterior, pero NO puede recuperar
-- valores reales que hubiera tenido cada fila antes del DROP — según lo
-- verificado antes de aplicar 0023, todas estaban en 0, así que no hay
-- nada que se pierda en la práctica.

BEGIN;

ALTER TABLE vehiculos ADD COLUMN tope_semanal NUMERIC(10,2) NOT NULL DEFAULT 0;

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0023_elimina_tope_semanal.sql';
