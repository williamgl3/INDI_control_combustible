-- Migración 0026 — recorridos de marimba: agrupa N despachos de una
-- misma jornada bajo un encabezado con conciliación de litros.
--
-- Hoy `despachos_marimba` (0018/0021/0024) modela cada despacho como un
-- evento suelto contra el libro mayor de saldo de la marimba — cubre bien
-- el despacho individual, pero no existe ningún concepto de "jornada":
-- de dónde salió, con cuántos litros salió el camión, ni si lo que se
-- despachó cuadra contra lo que traía. Esta tabla es ese encabezado.
CREATE TABLE recorridos_marimba (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  marimba_id UUID NOT NULL REFERENCES vehiculos(id),
  operador_id UUID NOT NULL REFERENCES usuarios(id),
  frente VARCHAR(150) NOT NULL,
  -- De qué carga (gasolinera/pipa) salió el combustible con el que el
  -- camión arrancó este recorrido — trazabilidad hacia `cargas`, no un
  -- mecanismo nuevo de registro de carga.
  carga_id UUID REFERENCES cargas(id),
  litros_iniciales NUMERIC(10, 2) NOT NULL CHECK (litros_iniciales >= 0),
  km_inicio NUMERIC(12, 2),
  km_cierre NUMERIC(12, 2),
  horas_equipo_menor_inicio NUMERIC(12, 2),
  horas_equipo_menor_cierre NUMERIC(12, 2),
  estado VARCHAR(20) NOT NULL DEFAULT 'abierto' CHECK (estado IN ('abierto', 'cerrado')),
  -- Snapshot de conciliación — se llena SOLO al cerrar (ver
  -- `recorridosMarimbaService.cerrarRecorrido`), nunca se recalcula
  -- después: si la tolerancia configurada cambia más adelante, un
  -- recorrido ya cerrado no debe re-evaluarse solo (mismo criterio que
  -- `precio_referencia_usado` en `despachos_marimba`).
  litros_despachados_total NUMERIC(10, 2),
  existencia_calculada NUMERIC(10, 2),
  diferencia_conciliacion NUMERIC(10, 2),
  tolerancia_usada NUMERIC(10, 2),
  requiere_revision BOOLEAN NOT NULL DEFAULT false,
  foto_cierre_path TEXT,
  iniciado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  cerrado_en TIMESTAMPTZ
);

CREATE INDEX idx_recorridos_marimba_marimba ON recorridos_marimba (marimba_id);
CREATE INDEX idx_recorridos_marimba_estado ON recorridos_marimba (estado);

-- Config de tolerancia de merma — mismo mecanismo clave/valor que ya usa
-- `presupuesto_semanal_total` (ver 0001_baseline.sql), no una tabla
-- nueva. Valor inicial PLACEHOLDER, igual criterio que el presupuesto:
-- pendiente de confirmar con el cliente (ver PASO 5 del diseño).
INSERT INTO configuracion (clave, valor) VALUES ('tolerancia_merma_marimba_litros', 20)
  ON CONFLICT (clave) DO NOTHING;
