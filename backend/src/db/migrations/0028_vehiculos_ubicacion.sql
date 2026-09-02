-- Migración 0028 — `ubicacion`: frente/banco donde opera la unidad hoy
-- (ej. "BANCO EL HUIZACHITO"), para filtrar el catálogo de máquinas
-- destino al capturar despachos de marimba por recorrido.
--
-- Hallazgo durante la implementación del PASO 3 (filtro por ubicación):
-- el catálogo maquinaria_gami.csv importado SÍ traía una columna
-- `ubicacion`, pero `importarVehiculos.ts` la descartó a propósito en su
-- momento (no existía ninguna columna de esquema ni caso de uso para
-- ella todavía) — el diseño de recorridos de marimba asumió que ya
-- existía. Se agrega ahora, nullable (no se puede reconstruir el dato
-- descartado sin volver a importar desde el CSV original).
ALTER TABLE vehiculos ADD COLUMN ubicacion TEXT;
CREATE INDEX idx_vehiculos_ubicacion ON vehiculos (ubicacion);
