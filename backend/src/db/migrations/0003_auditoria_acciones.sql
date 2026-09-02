-- Migración 0003 — auditoría de acciones administrativas.
--
-- Registra quién hizo qué sobre qué entidad, para poder reconstruir un
-- historial de acciones sensibles (aprobar/rechazar solicitudes, editar
-- vehículos/topes, mantenimiento, incidencias, precios, gestión de
-- usuarios). El insert lo hace `src/services/auditoriaService.ts` —
-- nunca debe tirar la operación principal si falla (ver ese archivo).

CREATE TABLE IF NOT EXISTS auditoria_acciones (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID REFERENCES usuarios (id),
  accion TEXT NOT NULL,
  entidad TEXT NOT NULL,
  entidad_id TEXT,
  detalle JSONB,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_auditoria_creado_en ON auditoria_acciones (creado_en DESC);
