-- Migración 0012 — índices en las columnas de orden cronológico que
-- faltaban (creada_en/registrada_en) en las tablas que crecen todos los
-- días (una fila por solicitud/carga/cierre de cada chofer). Sin esto,
-- los listados que ordenan por fecha (`ORDER BY creada_en DESC`, usados
-- por el panel de Autorizaciones/Concentrado) hacen un sort completo sin
-- índice de soporte — mismo patrón que ya tenía `auditoria_acciones`
-- (ver `idx_auditoria_creado_en` en 0003_auditoria_acciones.sql).

CREATE INDEX IF NOT EXISTS idx_solicitudes_creada_en ON solicitudes_autorizacion (creada_en DESC);
CREATE INDEX IF NOT EXISTS idx_cargas_creada_en ON cargas (creada_en DESC);
CREATE INDEX IF NOT EXISTS idx_cierres_registrada_en ON cierres_dia (registrada_en DESC);
