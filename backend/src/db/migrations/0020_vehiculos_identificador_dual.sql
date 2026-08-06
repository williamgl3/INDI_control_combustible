-- Migración 0020 — identificador dual: `placas` y `numero_economico`
-- como columnas independientes, en vez de una sola `placas` obligatoria.
--
-- Motivo (inventario real de 96 unidades, 3 casos):
--   · 39 unidades SOLO con placa       (38 vehículos ligeros + la marimba GX-7447-C)
--   · 42 unidades SOLO con económico   (maquinaria pesada, no circula por carretera)
--   · 15 unidades con AMBOS            (14 pipas + la marimba COL-25-014: circulan
--                                        por carretera —Tránsito exige placa— y
--                                        GAMI además les asigna económico interno)
-- Una sola columna `placas` ya no representa el dominio. El campo de
-- API `identificador` (`types/index.ts`, modelo Flutter) sigue existiendo
-- tal cual hoy — esta migración es solo de esquema; la propiedad de
-- display que decide cuál de los dos mostrar llega en un paso posterior.

-- 1. Columna nueva, nullable — las 39 unidades solo-placa la dejan NULL.
ALTER TABLE vehiculos ADD COLUMN numero_economico TEXT;

-- 2. Normaliza `placas` ANTES de imponer las constraints nuevas —
--    mayúsculas + sin espacios al inicio/fin, mismo criterio que ya
--    aplica `vehiculosService.ts` en cada escritura desde este cambio.
--    (Verificado antes de escribir esta migración: los 40 registros ya
--    estaban en mayúsculas, sin espacios, sin vacíos — este UPDATE no
--    debería tocar ninguna fila, pero se deja explícito por si el
--    catálogo crece con datos importados sin pasar por el servicio.)
UPDATE vehiculos SET placas = upper(trim(placas)) WHERE placas IS NOT NULL;

-- 3. `placas` deja de ser obligatoria — la maquinaria pesada no tiene.
ALTER TABLE vehiculos ALTER COLUMN placas DROP NOT NULL;

-- 4. La UNIQUE plana (`vehiculos_identificador_key`, de la migración
--    0014, heredada por 0019 al renombrar la columna) se reemplaza por
--    índices únicos funcionales sobre la forma normalizada. Esto cubre
--    dos cosas a la vez: (a) sensibilidad a mayúsculas — 'pl-0762-c' y
--    'PL-0762-C' ya no pueden coexistir aunque algo se le escape a la
--    normalización de la app, y (b) el mismo mecanismo se necesita para
--    `numero_economico`. Postgres permite múltiples NULL en un índice
--    único sin configuración especial — no se necesita una cláusula
--    WHERE para eso.
ALTER TABLE vehiculos DROP CONSTRAINT vehiculos_identificador_key;

CREATE UNIQUE INDEX vehiculos_placas_normalizada_key
  ON vehiculos (upper(trim(placas)));

CREATE UNIQUE INDEX vehiculos_numero_economico_normalizado_key
  ON vehiculos (upper(trim(numero_economico)));

-- 5. Cadena vacía o solo-espacios no debe colarse como identificador
--    "presente" — a nivel de app se normaliza a NULL antes de guardar,
--    pero esta es la red de seguridad si algo llega directo por SQL.
ALTER TABLE vehiculos ADD CONSTRAINT chk_placas_no_vacia
  CHECK (placas IS NULL OR length(trim(placas)) > 0);

ALTER TABLE vehiculos ADD CONSTRAINT chk_numero_economico_no_vacio
  CHECK (numero_economico IS NULL OR length(trim(numero_economico)) > 0);

-- 6. Toda unidad necesita AL MENOS un identificador físico. Verificado
--    antes de escribir esta migración: 0 de las 40 filas existentes
--    tienen `placas` vacía/NULL, así que este CHECK no encuentra ningún
--    registro que lo viole.
ALTER TABLE vehiculos ADD CONSTRAINT chk_identificador
  CHECK (numero_economico IS NOT NULL OR placas IS NOT NULL);
