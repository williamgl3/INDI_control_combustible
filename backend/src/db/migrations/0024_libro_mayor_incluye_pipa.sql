-- Migración 0024 — el libro mayor de saldo (`movimientos_marimba`) debe
-- reconocer también `tipo_unidad = 'Pipa'`, no solo `'Marimba'`.
--
-- Motivo: al reintroducir "Pipa" como categoría separada de "Marimba"
-- (el catálogo real del cliente trae 14 pipas normales + 1 camión
-- especial "orquesta"), las cargas a granel de una pipa dejarían de
-- contar como entrada del libro mayor si esta vista se queda tal cual
-- — su saldo se leería siempre en 0 sin que ningún despacho lo haya
-- gastado. Es el mismo mecanismo, solo dos categorías de unidad
-- distintas lo usan.
DROP VIEW saldo_marimba;
DROP VIEW movimientos_marimba;

CREATE VIEW movimientos_marimba AS
  SELECT c.vehiculo_id AS marimba_id,
         c.creada_en AS fecha,
         'carga'::text AS tipo,
         c.litros_cargados AS litros,
         c.id AS referencia_id
    FROM cargas c
    JOIN vehiculos v ON v.id = c.vehiculo_id
   WHERE v.tipo_unidad::text = ANY (ARRAY['Marimba', 'Pipa'])
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
