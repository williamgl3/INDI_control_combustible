-- ROLLBACK de 0024_libro_mayor_incluye_pipa.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0024_libro_mayor_incluye_pipa.sql

BEGIN;

DROP VIEW saldo_marimba;
DROP VIEW movimientos_marimba;

CREATE VIEW movimientos_marimba AS
  SELECT c.vehiculo_id AS marimba_id,
         c.creada_en AS fecha,
         'carga'::text AS tipo,
         c.litros_cargados AS litros,
         c.id AS referencia_id
    FROM cargas c
    JOIN vehiculos v ON v.id = c.vehiculo_id
   WHERE v.tipo_unidad::text = 'Marimba'::text
  UNION ALL
  SELECT d.marimba_id,
         d.creado_en AS fecha,
         'despacho'::text AS tipo,
         - d.litros_suministrados AS litros,
         d.id AS referencia_id
    FROM despachos_marimba d;

CREATE VIEW saldo_marimba AS
  SELECT marimba_id,
         COALESCE(sum(litros), 0::numeric) AS saldo_actual
    FROM movimientos_marimba
   GROUP BY marimba_id;

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0024_libro_mayor_incluye_pipa.sql';
