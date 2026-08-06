-- ROLLBACK de 0021_pipa_a_marimba.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0021_pipa_a_marimba.sql
--
-- ⚠️ Escrito asumiendo que "Pipa" ya no existía como valor real de
-- `tipo_unidad` (todo lo que decía "Pipa" se había renombrado a
-- "Marimba"). Eso dejó de ser cierto: el catálogo real del cliente
-- reintrodujo "Pipa" como categoría propia y distinta de "Marimba"
-- (14 pipas normales vs. 1 camión especial), sin pasar por una
-- migración — fue simplemente una decisión de negocio insertando datos
-- nuevos, ya que `tipo_unidad` es texto libre sin CHECK que lo
-- restrinja. Si este rollback corriera tal cual sobre esos datos,
-- `UPDATE ... SET tipo_unidad = 'Pipa' WHERE tipo_unidad = 'Marimba'`
-- fusionaría las 2 Marimba reales con las 14 Pipa reales bajo una sola
-- etiqueta, perdiendo la distinción del cliente. Por eso se niega a
-- correr si ya existe algún `tipo_unidad = 'Pipa'` — revisa a mano
-- cuáles filas son cuáles antes de forzarlo.
BEGIN;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM vehiculos WHERE tipo_unidad = 'Pipa') THEN
    RAISE EXCEPTION 'Ya existen unidades con tipo_unidad=Pipa (categoría real, no residuo) — este rollback no puede distinguirlas de las que él mismo renombraría. Revísalo a mano antes de continuar.';
  END IF;
END $$;

DROP VIEW saldo_marimba;
DROP VIEW movimientos_marimba;

CREATE VIEW movimientos_pipa AS
  SELECT c.vehiculo_id AS pipa_id,
         c.creada_en AS fecha,
         'carga'::text AS tipo,
         c.litros_cargados AS litros,
         c.id AS referencia_id
    FROM cargas c
    JOIN vehiculos v ON v.id = c.vehiculo_id
   WHERE v.tipo_unidad::text = 'Pipa'::text
  UNION ALL
  SELECT d.pipa_id,
         d.creado_en AS fecha,
         'despacho'::text AS tipo,
         - d.litros_suministrados AS litros,
         d.id AS referencia_id
    FROM despachos_marimba d;

CREATE VIEW saldo_pipa AS
  SELECT pipa_id,
         COALESCE(sum(litros), 0::numeric) AS saldo_actual
    FROM movimientos_pipa
   GROUP BY pipa_id;

ALTER INDEX idx_despachos_marimba_marimba RENAME TO idx_despachos_pipa_pipa;
ALTER INDEX idx_despachos_marimba_destino RENAME TO idx_despachos_pipa_destino;
ALTER INDEX idx_despachos_marimba_creado RENAME TO idx_despachos_pipa_creado;

ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_marimba_pkey TO despachos_pipa_pkey;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_marimba_marimba_id_fkey TO despachos_pipa_pipa_id_fkey;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_marimba_vehiculo_destino_id_fkey TO despachos_pipa_vehiculo_destino_id_fkey;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_marimba_registrado_por_fkey TO despachos_pipa_registrado_por_fkey;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_marimba_estado_check TO despachos_pipa_estado_check;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_marimba_lectura_medidor_check TO despachos_pipa_lectura_medidor_check;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_marimba_litros_suministrados_check TO despachos_pipa_litros_suministrados_check;

ALTER TABLE despachos_marimba RENAME COLUMN marimba_id TO pipa_id;
ALTER TABLE despachos_marimba RENAME TO despachos_pipa;

UPDATE vehiculos SET tipo_unidad = 'Pipa' WHERE tipo_unidad = 'Marimba';

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0021_pipa_a_marimba.sql';
