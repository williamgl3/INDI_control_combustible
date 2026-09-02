-- Migración 0007 — foto al reportar una incidencia/falla de vehículo.
--
-- Antes el reporte era solo texto ("se ponchó una llanta", "ruido raro en
-- el motor"), sin poder mostrar el daño — el resto de la app ya usa
-- fotos para todo lo demás (tablero, ticket), esto lo alinea. `NULL` en
-- incidencias anteriores a este campo.

ALTER TABLE incidencias_vehiculo ADD COLUMN IF NOT EXISTS foto_path TEXT;
