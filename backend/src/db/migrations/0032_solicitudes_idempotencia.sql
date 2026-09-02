-- Migracion 0032 - identidad estable para solicitudes creadas por clientes.
-- Las filas historicas permanecen intactas: ambas columnas son NULLables.
ALTER TABLE solicitudes_autorizacion
  ADD COLUMN idempotency_key UUID,
  ADD COLUMN payload_fingerprint CHAR(64);

ALTER TABLE solicitudes_autorizacion
  ADD CONSTRAINT solicitudes_payload_fingerprint_formato
  CHECK (payload_fingerprint IS NULL OR payload_fingerprint ~ '^[0-9a-f]{64}$');

CREATE UNIQUE INDEX uq_solicitudes_chofer_idempotency
  ON solicitudes_autorizacion (chofer_id, idempotency_key)
  WHERE idempotency_key IS NOT NULL;

-- Defensa final ante dos dispositivos que expresan la misma necesidad.
-- Los estados resueltos no bloquean solicitudes futuras legitimas.
CREATE UNIQUE INDEX uq_solicitudes_pendiente_negocio
  ON solicitudes_autorizacion
    (chofer_id, vehiculo_id, ((fecha_programada AT TIME ZONE 'America/Mexico_City')::date))
  WHERE estado = 'pendiente';

-- Rollback seguro (manual, conforme al runner sin down migrations):
-- DROP INDEX IF EXISTS uq_solicitudes_pendiente_negocio;
-- DROP INDEX IF EXISTS uq_solicitudes_chofer_idempotency;
-- ALTER TABLE solicitudes_autorizacion
--   DROP CONSTRAINT IF EXISTS solicitudes_payload_fingerprint_formato,
--   DROP COLUMN IF EXISTS payload_fingerprint,
--   DROP COLUMN IF EXISTS idempotency_key;
