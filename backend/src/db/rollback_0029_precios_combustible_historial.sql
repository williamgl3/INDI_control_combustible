-- ROLLBACK de 0029_precios_combustible_historial.sql — correr a mano:
--   docker exec -i backend-db-1 psql -U indi -d indi_combustible \
--     < backend/src/db/rollback_0029_precios_combustible_historial.sql
--
-- ADVERTENCIA: es un rollback CON PÉRDIDA DE DATOS a propósito — el
-- esquema viejo (una fila por tipo) no puede representar historial.
-- Reconstruye cada tipo con su precio VIGENTE MÁS RECIENTE únicamente;
-- cualquier cambio de precio intermedio que haya ocurrido después de
-- aplicar 0029 se pierde. 'Magna' vuelve a llamarse 'Gasolina' (inverso
-- exacto del rename de la migración); si además se llegó a registrar un
-- precio de 'Premium', esa fila simplemente no tiene equivalente en el
-- modelo viejo de 2 tipos — se conserva tal cual (el esquema viejo no
-- tenía un CHECK de valores permitidos, así que no rompe nada, pero es
-- información que el modelo anterior nunca esperó tener).

BEGIN;

ALTER TABLE evidencias
  DROP COLUMN IF EXISTS requiere_revision,
  DROP COLUMN IF EXISTS desviacion_precio_porcentaje,
  DROP COLUMN IF EXISTS precio_referencia_comparado,
  DROP COLUMN IF EXISTS carga_id;

ALTER TABLE solicitudes_autorizacion ALTER COLUMN costo_estimado SET NOT NULL;

ALTER TABLE cargas
  DROP COLUMN IF EXISTS precio_referencia_por_litro,
  DROP COLUMN IF EXISTS costo_referencia;

CREATE TABLE precios_combustible_legacy (
  tipo_combustible VARCHAR(50) PRIMARY KEY,
  precio_por_litro NUMERIC(10, 2) NOT NULL,
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO precios_combustible_legacy (tipo_combustible, precio_por_litro, actualizado_en)
SELECT
  CASE WHEN tipo_combustible = 'Magna' THEN 'Gasolina' ELSE tipo_combustible END,
  precio_por_litro,
  vigente_desde
FROM (
  SELECT DISTINCT ON (tipo_combustible) tipo_combustible, precio_por_litro, vigente_desde
  FROM precios_combustible
  ORDER BY tipo_combustible, vigente_desde DESC
) vigentes;

DROP INDEX IF EXISTS idx_precios_tipo_vigente;
DROP TABLE precios_combustible;
ALTER TABLE precios_combustible_legacy RENAME TO precios_combustible;

COMMIT;

-- Después de correr esto, borra también el registro de la migración:
--   DELETE FROM schema_migrations WHERE name = '0029_precios_combustible_historial.sql';
