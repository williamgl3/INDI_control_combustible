-- Migración 0006 — foto del tablero al solicitar carga.
--
-- Mismo respaldo visual que ya se manda por WhatsApp en el proceso real:
-- el chofer adjunta una foto del tablero (km/horómetro actual) desde el
-- momento en que PIDE combustible, no solo al comprobar la carga (ver
-- `foto_tablero_path` en `cargas`). `NULL` en solicitudes anteriores a
-- este campo.

ALTER TABLE solicitudes_autorizacion ADD COLUMN IF NOT EXISTS foto_tablero_path TEXT;
