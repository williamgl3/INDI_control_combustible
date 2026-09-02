-- Migración 0025 — `unidad_padre_id`: permite modelar una unidad como
-- accesorio/sub-unidad de otra, en vez de forzar "1 vehículo = 1
-- combustible + 1 métrica" en una sola fila.
--
-- Motivo (flujo de marimba, ver diseño acordado): la marimba consume DOS
-- combustibles a la vez — el camión (Diésel, se mide por km) y un equipo
-- menor de gasolina que opera la bomba de despacho (Gasolina, se mide por
-- horas). `vehiculos` solo tiene un `tipo_combustible` y una métrica por
-- fila, así que el equipo menor se modela como OTRA fila de `vehiculos`
-- (con su propio combustible/métrica, reutilizando el 100% del modelo
-- existente) ligada a su unidad padre con esta columna, en vez de
-- convertir `vehiculos` en una entidad con N combustibles por fila.
--
-- Se eligió esta forma (Opción B, sub-unidad) sobre una tabla aparte de
-- "consumos de la unidad" (Opción A) porque generaliza a futuros
-- accesorios reales con identidad propia (ej. martillos hidráulicos que
-- se pueden desmontar y reasignar a otra excavadora) sin rehacer el
-- modelo — y porque no requiere tocar ningún código existente que ya
-- asume "1 vehículo = 1 combustible + 1 métrica" (selector, catálogo,
-- mantenimiento, finanzas): cada fila sigue siendo exactamente eso.
ALTER TABLE vehiculos ADD COLUMN unidad_padre_id UUID REFERENCES vehiculos(id);

-- Solo 2 niveles: un hijo no puede a su vez ser padre de otra unidad. No
-- se puede expresar como CHECK simple (necesitaría ver la fila referida),
-- así que se aplica el filtro más barato aquí (una unidad no puede ser
-- padre de sí misma) y el resto se valida a nivel de aplicación.
ALTER TABLE vehiculos ADD CONSTRAINT chk_unidad_padre_no_autorreferencia
  CHECK (unidad_padre_id IS NULL OR unidad_padre_id != id);

CREATE INDEX idx_vehiculos_unidad_padre ON vehiculos (unidad_padre_id);
