-- Migración 0018 — ciclo de despacho de la pipa: el saldo es un libro
-- mayor continuo por pipa (no por carga individual, ver nota de diseño:
-- una pipa mezcla el sobrante de ayer con lo cargado hoy, no se puede
-- atribuir un despacho a una carga puntual). Las ENTRADAS ya existen
-- (una carga normal de un vehículo con tipo_unidad='Pipa'); esta
-- migración solo agrega las SALIDAS.
CREATE TABLE despachos_pipa (
  id                       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pipa_id                  UUID NOT NULL REFERENCES vehiculos (id),
  vehiculo_destino_id      UUID REFERENCES vehiculos (id),
  destino_texto            VARCHAR(150),
  operador_texto           VARCHAR(150) NOT NULL,
  residente_texto          VARCHAR(150),
  sitio                    VARCHAR(150) NOT NULL,
  litros_solicitados       NUMERIC(10, 2),
  litros_suministrados     NUMERIC(10, 2) NOT NULL DEFAULT 0 CHECK (litros_suministrados >= 0),
  lectura_medidor          NUMERIC(12, 2) CHECK (lectura_medidor >= 0),
  precio_referencia_usado  NUMERIC(10, 2),
  estado                   VARCHAR(20) NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'inactivo')),
  foto_evidencia_path      TEXT,
  registrado_por           UUID NOT NULL REFERENCES usuarios (id),
  creado_en                TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_despachos_pipa_pipa    ON despachos_pipa (pipa_id);
CREATE INDEX idx_despachos_pipa_destino ON despachos_pipa (vehiculo_destino_id);
CREATE INDEX idx_despachos_pipa_creado  ON despachos_pipa (creado_en);

-- Movimientos del libro mayor: entradas (cargas de una pipa, positivas) y
-- salidas (despachos, negativas) en una sola línea de tiempo por pipa.
CREATE VIEW movimientos_pipa AS
  SELECT
    c.vehiculo_id AS pipa_id,
    c.creada_en   AS fecha,
    'carga'::text AS tipo,
    c.litros_cargados AS litros,
    c.id AS referencia_id
  FROM cargas c
  JOIN vehiculos v ON v.id = c.vehiculo_id
  WHERE v.tipo_unidad = 'Pipa'
UNION ALL
  SELECT
    d.pipa_id,
    d.creado_en,
    'despacho'::text,
    -d.litros_suministrados,
    d.id
  FROM despachos_pipa d;

-- Saldo actual por pipa — nunca se reinicia por carga ni por día.
CREATE VIEW saldo_pipa AS
  SELECT pipa_id, COALESCE(SUM(litros), 0) AS saldo_actual
  FROM movimientos_pipa
  GROUP BY pipa_id;

-- Rendimiento (litros/hora) por unidad destino, comparando cada despacho
-- contra el anterior de la MISMA unidad por lectura de medidor — mismo
-- principio que el km/L de vehículos ligeros (ratio de diagnóstico
-- calculado al leer, no un valor financiero que se almacene).
CREATE VIEW rendimiento_despacho AS
  SELECT
    d.id AS despacho_id,
    d.vehiculo_destino_id,
    d.lectura_medidor,
    d.litros_suministrados,
    d.lectura_medidor - LAG(d.lectura_medidor) OVER w AS horas_operadas,
    d.litros_suministrados
      / NULLIF(d.lectura_medidor - LAG(d.lectura_medidor) OVER w, 0) AS rendimiento_l_por_hora
  FROM despachos_pipa d
  WHERE d.vehiculo_destino_id IS NOT NULL AND d.lectura_medidor IS NOT NULL
  WINDOW w AS (PARTITION BY d.vehiculo_destino_id ORDER BY d.lectura_medidor);
