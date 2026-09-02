-- Migración 0029 — historial de precios de combustible + snapshots.
--
-- Origen: `precios_combustible` tenía una sola fila por tipo (PK), así
-- que actualizar un precio perdía el anterior — cualquier reporte
-- financiero que recalculara "el costo de una carga vieja" contra la
-- tabla actual quedaba retroactivamente equivocado cada vez que alguien
-- tocaba un precio. Se detectó además que `concentrado_tab.dart` (ver
-- ese archivo) ya hacía exactamente eso, con un fallback silencioso a
-- "el primer precio de la lista" cuando el tipo no coincidía — el mismo
-- antipatrón que motivó esta migración.
--
-- Modelo nuevo: histórico append-only con `vigente_desde` únicamente (sin
-- `vigente_hasta` — el siguiente registro cierra implícitamente al
-- anterior; menos superficie de inconsistencia que mantener dos columnas
-- sincronizadas). "Precio vigente en fecha X" = la fila con mayor
-- `vigente_desde <= X` para ese tipo. Actualizar un precio ya no es
-- UPDATE, es INSERT — el histórico nunca se sobrescribe.
--
-- 'Gasolina' (semilla original, ver 0001_baseline.sql) se migra a
-- 'Magna' como primer registro histórico — es la fila real, no un
-- placeholder: el catálogo importado nunca usó "Gasolina" como valor
-- (0 filas en `vehiculos.tipo_combustible`), así que no hay datos de
-- choferes/cargas que reinterpretar, solo esta fila de configuración.
-- 'Premium' NO se siembra a propósito: ninguna de las 96 unidades reales
-- la usa hoy, y sembrarla con un precio inventado (ej. igual a Magna)
-- sería un número plausible-pero-falso que subestimaría el gasto sin que
-- nadie lo cuestione — mejor que falle explícito (ver `preciosService.
-- precioDeDecimal`) hasta que un admin capture el precio real.
ALTER TABLE precios_combustible RENAME TO precios_combustible_legacy;

CREATE TABLE precios_combustible (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_combustible VARCHAR(50) NOT NULL,
  precio_por_litro NUMERIC(10, 2) NOT NULL CHECK (precio_por_litro > 0),
  vigente_desde TIMESTAMPTZ NOT NULL DEFAULT now(),
  registrado_por UUID REFERENCES usuarios(id),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_precios_tipo_vigente ON precios_combustible (tipo_combustible, vigente_desde DESC);

INSERT INTO precios_combustible (tipo_combustible, precio_por_litro, vigente_desde)
SELECT
  CASE WHEN tipo_combustible = 'Gasolina' THEN 'Magna' ELSE tipo_combustible END,
  precio_por_litro,
  actualizado_en
FROM precios_combustible_legacy;

-- No se sigue sin verificar: con datos financieros, un mismatch de
-- conteo silencioso es peor que abortar la migración (el rollback de
-- abajo reconstruye desde la tabla NUEVA — si la copia de datos falló a
-- medias, ya no habría fuente original que rescatar).
DO $$
DECLARE
  original_count int;
  nuevo_count int;
BEGIN
  SELECT count(*) INTO original_count FROM precios_combustible_legacy;
  SELECT count(*) INTO nuevo_count FROM precios_combustible;
  IF original_count <> nuevo_count THEN
    RAISE EXCEPTION
      'Migración de precios abortada: % filas originales, % migradas',
      original_count, nuevo_count;
  END IF;
END $$;

DROP TABLE precios_combustible_legacy;

-- Snapshot de referencia en `cargas` — mismo patrón que ya existía en
-- `solicitudes_autorizacion.costo_estimado` (migración 0001) y en
-- `despachos_marimba.precio_referencia_usado` (migración 0027), pero
-- faltaba aquí: `cargas` no tenía ninguna columna de precio/costo, así
-- que el reporte de Concentrado no tenía nada que "congelar" y
-- recalculaba contra el precio vigente HOY sin importar cuándo ocurrió
-- la carga.
ALTER TABLE cargas
  ADD COLUMN precio_referencia_por_litro NUMERIC(10, 2),
  ADD COLUMN costo_referencia NUMERIC(10, 2);

-- `costo_estimado` deja de ser NOT NULL: una unidad de maquinaria/pipa
-- sin `tipo_combustible` confirmado (55 de 96 unidades del catálogo real)
-- ahora SÍ puede generar una solicitud — antes `solicitudesService.
-- enviarSolicitud` lo bloqueaba con un error 400 ("combustible no
-- confirmado"), lo cual en la práctica dejaba a más de la mitad de la
-- flota sin poder solicitar combustible. Con costo NULL, la solicitud se
-- crea pero nunca se autoaprueba (va a revisión manual, donde el admin
-- puede completar el dato o aprobar a ojo) — ver `solicitudesService.ts`.
ALTER TABLE solicitudes_autorizacion ALTER COLUMN costo_estimado DROP NOT NULL;

-- FK opcional directa carga→evidencia: hoy `evidencias.folio_id` solo
-- apunta a la SOLICITUD, no a la carga puntual, y una solicitud puede
-- tener varias cargas (ej. autorizan 300 L y el chofer los carga en dos
-- visitas) mientras que una evidencia comprobante puede repetirse para el
-- mismo folio (hasta 5 fotos, o un reintento tras una foto borrosa) — sin
-- `carga_id`, "el gasto real de ESTA carga" queda ambiguo si hay N cargas
-- y M evidencias sobre el mismo folio. Se agrega el esquema ahora,
-- nullable; el flujo de UI para llenarlo (elegir carga en vez de
-- solicitud al subir el comprobante) es un cambio de UX aparte, no entra
-- en esta migración — ver análisis de vinculación offline pendiente.
ALTER TABLE evidencias ADD COLUMN carga_id UUID REFERENCES cargas(id);

-- Bandera de revisión por desviación de precio (punto 4b): se guarda el
-- número, no solo el booleano, para poder ajustar el umbral después sin
-- tener que recalcular contra precios que ya cambiaron. Vive en la propia
-- evidencia (no solo en `auditoria_acciones`) para poder construir después
-- una pantalla de "evidencias pendientes de revisión" con una consulta
-- directa, sin tener que reconstruir estado de negocio escaneando logs.
ALTER TABLE evidencias
  ADD COLUMN requiere_revision BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN desviacion_precio_porcentaje NUMERIC(6, 4),
  ADD COLUMN precio_referencia_comparado NUMERIC(10, 2);
