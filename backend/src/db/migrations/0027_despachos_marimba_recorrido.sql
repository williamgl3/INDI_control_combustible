-- Migración 0027 — liga cada despacho a su recorrido (jornada).
--
-- `recorrido_id` es nullable a propósito: un despacho suelto (sin pasar
-- por el flujo de recorrido) sigue siendo válido, mismo comportamiento
-- que hoy tiene `POST /despachos-marimba` sin cambios.
ALTER TABLE despachos_marimba ADD COLUMN recorrido_id UUID REFERENCES recorridos_marimba(id);
CREATE INDEX idx_despachos_marimba_recorrido ON despachos_marimba (recorrido_id);

-- `sitio` era obligatorio por despacho porque no existía ningún concepto
-- de jornada/frente — ahora se hereda de `recorridos_marimba.frente`
-- cuando el despacho pertenece a un recorrido, así que deja de ser
-- obligatorio a nivel de esquema (la ruta sigue exigiéndolo cuando NO hay
-- recorrido_id, ver `despachosMarimbaService`).
ALTER TABLE despachos_marimba ALTER COLUMN sitio DROP NOT NULL;
