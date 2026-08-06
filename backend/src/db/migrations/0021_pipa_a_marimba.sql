-- Migración 0021 — unifica terminología: "Pipa" y "Marimba" eran el
-- mismo concepto con dos nombres (uno genérico del dominio de
-- combustibles, otro el que usa el cliente en campo). Se deja
-- "Marimba" en todo el sistema —de punta a punta, esquema y código—
-- porque así la llama el cliente.

-- 1. El valor que ve/elige el usuario. Solo 2 filas hoy
--    (GX-7447-C, CV-4156-H) — verificado antes de escribir esta
--    migración.
UPDATE vehiculos SET tipo_unidad = 'Marimba' WHERE tipo_unidad = 'Pipa';

-- 2. La tabla del libro mayor de despachos y su columna de FK. Postgres
--    actualiza automáticamente las vistas dependientes para que sigan
--    apuntando al objeto renombrado (son punteros internos por OID, no
--    por nombre) — aun así, las 2 vistas de abajo se recrean explícito
--    en vez de confiar en eso, porque ambas tienen texto/alias propio
--    que si no se toca queda mostrando "pipa" aunque la tabla ya no se
--    llame así.
ALTER TABLE despachos_pipa RENAME TO despachos_marimba;
ALTER TABLE despachos_marimba RENAME COLUMN pipa_id TO marimba_id;

ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_pipa_pkey TO despachos_marimba_pkey;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_pipa_pipa_id_fkey TO despachos_marimba_marimba_id_fkey;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_pipa_vehiculo_destino_id_fkey TO despachos_marimba_vehiculo_destino_id_fkey;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_pipa_registrado_por_fkey TO despachos_marimba_registrado_por_fkey;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_pipa_estado_check TO despachos_marimba_estado_check;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_pipa_lectura_medidor_check TO despachos_marimba_lectura_medidor_check;
ALTER TABLE despachos_marimba RENAME CONSTRAINT despachos_pipa_litros_suministrados_check TO despachos_marimba_litros_suministrados_check;

ALTER INDEX idx_despachos_pipa_pipa RENAME TO idx_despachos_marimba_marimba;
ALTER INDEX idx_despachos_pipa_destino RENAME TO idx_despachos_marimba_destino;
ALTER INDEX idx_despachos_pipa_creado RENAME TO idx_despachos_marimba_creado;

-- 3. Las 2 vistas del libro mayor — recreadas explícito (DROP + CREATE,
--    no solo renombradas) porque ambas tienen texto que hay que
--    corregir de verdad, no solo el nombre:
--      · `movimientos_marimba` compara contra el literal 'Pipa' en su
--        WHERE — si solo se renombra la vista, ese filtro se queda
--        comparando contra un valor que ya no existe en la tabla
--        (paso 1 ya lo cambió a 'Marimba') y el saldo de TODAS las
--        unidades se leería como 0 en silencio. Es el bug más peligroso
--        posible aquí, por eso se verifica el saldo después de aplicar.
--      · Los alias de columna (`AS pipa_id`) son texto fijo del CREATE
--        VIEW original — no siguen el rename de la tabla/columna typ
--        automáticamente.
DROP VIEW saldo_pipa;
DROP VIEW movimientos_pipa;

CREATE VIEW movimientos_marimba AS
  SELECT c.vehiculo_id AS marimba_id,
         c.creada_en AS fecha,
         'carga'::text AS tipo,
         c.litros_cargados AS litros,
         c.id AS referencia_id
    FROM cargas c
    JOIN vehiculos v ON v.id = c.vehiculo_id
   WHERE v.tipo_unidad::text = 'Marimba'::text
  UNION ALL
  SELECT d.marimba_id,
         d.creado_en AS fecha,
         'despacho'::text AS tipo,
         - d.litros_suministrados AS litros,
         d.id AS referencia_id
    FROM despachos_marimba d;

CREATE VIEW saldo_marimba AS
  SELECT marimba_id,
         COALESCE(sum(litros), 0::numeric) AS saldo_actual
    FROM movimientos_marimba
   GROUP BY marimba_id;

-- `rendimiento_despacho` no tiene "pipa" en su propio nombre y no
-- referencia el literal 'Pipa' en texto — solo hace FROM despachos_pipa
-- (ahora despachos_marimba), que Postgres sigue automáticamente por
-- ser un rename de tabla. No necesita recrearse. Se verifica igual
-- después de aplicar.
