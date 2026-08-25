-- Migracion 0033 - ledger transaccional para comandos reintentables.
-- No se rellenan operaciones historicas y no se purgan claves automaticamente.
CREATE TABLE operaciones_idempotentes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios(id),
  operacion VARCHAR(80) NOT NULL,
  idempotency_key UUID NOT NULL,
  request_hash CHAR(64) NOT NULL,
  resource_type VARCHAR(50),
  resource_id UUID,
  http_status SMALLINT,
  response_body JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at TIMESTAMPTZ,
  CONSTRAINT operaciones_idempotentes_scope_unique
    UNIQUE (usuario_id, operacion, idempotency_key),
  CONSTRAINT operaciones_idempotentes_hash_check
    CHECK (request_hash ~ '^[0-9a-f]{64}$'),
  CONSTRAINT operaciones_idempotentes_status_check
    CHECK (http_status IS NULL OR http_status BETWEEN 200 AND 299),
  CONSTRAINT operaciones_idempotentes_completion_check
    CHECK (
      (completed_at IS NULL AND http_status IS NULL)
      OR (completed_at IS NOT NULL AND http_status IS NOT NULL)
    )
);

CREATE INDEX operaciones_idempotentes_created_at_idx
  ON operaciones_idempotentes(created_at);

CREATE INDEX operaciones_idempotentes_resource_idx
  ON operaciones_idempotentes(resource_type, resource_id)
  WHERE resource_id IS NOT NULL;
