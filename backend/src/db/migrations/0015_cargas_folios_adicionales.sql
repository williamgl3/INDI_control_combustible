-- Migración 0015 — soporta que UNA carga se haya pagado con VARIOS folios
-- de la estación (caso real: la carga a granel de la pipa llega con 8
-- folios de una sola visita). `folio_autorizacion` sigue siendo el folio
-- principal (nada cambia para el chofer individual, que siempre trae
-- exactamente 1) — `folios_adicionales` guarda los folios extra, vacío
-- en el caso normal. Se eligió sobre normalizar a una tabla `carga_folios`
-- para no tocar ninguna consulta/pantalla existente del flujo de chofer
-- individual, que hoy asume un solo `folioAutorizacion` por carga.
ALTER TABLE cargas
  ADD COLUMN IF NOT EXISTS folios_adicionales TEXT[] NOT NULL DEFAULT '{}';
