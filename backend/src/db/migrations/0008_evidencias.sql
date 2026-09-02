-- 0008: Tabla de evidencias fotográficas subidas por los choferes.
CREATE TABLE IF NOT EXISTS evidencias (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id  UUID NOT NULL REFERENCES usuarios(id),
  tipo        TEXT NOT NULL CHECK (tipo IN ('ticket', 'tablero', 'comprobante')),
  foto_url    TEXT NOT NULL,
  folio_id    UUID REFERENCES solicitudes_autorizacion(id),
  notas       TEXT,
  creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_evidencias_usuario ON evidencias (usuario_id);
CREATE INDEX IF NOT EXISTS idx_evidencias_folio   ON evidencias (folio_id);
