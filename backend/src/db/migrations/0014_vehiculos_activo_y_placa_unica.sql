-- Migración 0014 — catálogo de vehículos: soft-delete + placas únicas.
--
-- (a) `activo`, mismo patrón que `usuarios` (0004) y `pipas` (0009): un
-- vehículo desactivado deja de ofrecerse en el selector del chofer
-- (`SelectorVehiculo`) pero conserva su historial de solicitudes/cargas
-- (relacionadas por `vehiculo_id`, nunca se borra la fila).
ALTER TABLE vehiculos
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

-- (b) UNIQUE en `identificador` (placa/número económico/descripción
-- libre de maquinaria) — el catálogo de altas manuales no debe permitir
-- capturar el mismo identificador dos veces. Solo se recorta espacios
-- sueltos antes de aplicar la constraint (mismo `.trim()` que ya hace la
-- UI al guardar); no se fuerza mayúsculas aquí porque este campo también
-- guarda descripciones libres de maquinaria sin placas (ej.
-- "Retroexcavadora amarilla"), que no deben deformarse.
UPDATE vehiculos SET identificador = TRIM(identificador);

ALTER TABLE vehiculos
  ADD CONSTRAINT vehiculos_identificador_key UNIQUE (identificador);
