-- ROLLBACK de 0020_vehiculos_identificador_dual.sql
--
-- NO vive en `migrations/` a propósito — el runner (`migrate.ts`) solo
-- lee ese directorio y la aplicaría hacia adelante como si fuera una
-- migración más. Este archivo se corre a mano:
--
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0020_vehiculos_identificador_dual.sql
--
-- Requiere que ninguna fila dependa YA de `numero_economico` como único
-- identificador (es decir, que no se haya importado maquinaria pesada
-- todavía). El paso 3 falla a propósito si eso no se cumple — es
-- preferible un rollback que se detiene a uno que borra datos en
-- silencio.

BEGIN;

ALTER TABLE vehiculos DROP CONSTRAINT IF EXISTS chk_identificador;
ALTER TABLE vehiculos DROP CONSTRAINT IF EXISTS chk_numero_economico_no_vacio;
ALTER TABLE vehiculos DROP CONSTRAINT IF EXISTS chk_placas_no_vacia;

DROP INDEX IF EXISTS vehiculos_numero_economico_normalizado_key;
DROP INDEX IF EXISTS vehiculos_placas_normalizada_key;

-- Si alguna fila no tiene `placas` (dependía solo de económico), este
-- ALTER falla aquí mismo — intencional, evita perder datos en silencio.
ALTER TABLE vehiculos ALTER COLUMN placas SET NOT NULL;

ALTER TABLE vehiculos ADD CONSTRAINT vehiculos_identificador_key UNIQUE (placas);

ALTER TABLE vehiculos DROP COLUMN numero_economico;

COMMIT;

-- Después de correr esto, borra también el registro de la migración
-- para que `npm run migrate` la vuelva a tratar como pendiente:
--
--   DELETE FROM schema_migrations WHERE name = '0020_vehiculos_identificador_dual.sql';
