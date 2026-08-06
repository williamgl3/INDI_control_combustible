-- Migración puntual para el cambio de esquema del 2026-07-20 (registro
-- de chofer con nombre/apellidos/fecha de nacimiento en vez de
-- nombre_completo/edad; solicitudes con actividad/fecha_programada).
-- No es idempotente ni parte de schema.sql (que ya refleja el estado
-- final para instalaciones nuevas) — se corrió una sola vez a mano
-- contra la DB local de desarrollo para no perder los datos de prueba
-- ya sembrados. Se conserva aquí solo como bitácora.

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS nombre VARCHAR(100),
  ADD COLUMN IF NOT EXISTS apellido_paterno VARCHAR(100),
  ADD COLUMN IF NOT EXISTS apellido_materno VARCHAR(100),
  ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;

-- Backfill best-effort desde nombre_completo/edad (datos de prueba, no
-- reales) — divide en la primera palabra como nombre y el resto como
-- apellido paterno.
UPDATE usuarios
SET
  nombre = split_part(nombre_completo, ' ', 1),
  apellido_paterno = trim(substring(nombre_completo FROM length(split_part(nombre_completo, ' ', 1)) + 1)),
  fecha_nacimiento = (CURRENT_DATE - (edad || ' years')::interval)::date
WHERE nombre IS NULL;

ALTER TABLE usuarios
  ALTER COLUMN nombre SET NOT NULL,
  ALTER COLUMN apellido_paterno SET NOT NULL,
  ALTER COLUMN fecha_nacimiento SET NOT NULL,
  DROP COLUMN nombre_completo,
  DROP COLUMN edad;

ALTER TABLE solicitudes_autorizacion
  ADD COLUMN IF NOT EXISTS actividad TEXT,
  ADD COLUMN IF NOT EXISTS fecha_programada TIMESTAMPTZ;

UPDATE solicitudes_autorizacion
SET
  actividad = 'Actividad no especificada (migrada, dato previo al campo)',
  fecha_programada = creada_en
WHERE actividad IS NULL;

ALTER TABLE solicitudes_autorizacion
  ALTER COLUMN actividad SET NOT NULL,
  ALTER COLUMN fecha_programada SET NOT NULL;
