-- Migración 0013 — unifica los tipos de evidencia "ticket" y "comprobante"
-- en uno solo ("comprobante"), y agrega las columnas estructuradas que
-- captura el chofer al subir un comprobante: tipo de combustible cargado,
-- litros, precio por litro y monto pagado. Antes solo se guardaba la foto
-- (y, para "tablero", el km) — Finanzas necesita el dato real capturado,
-- no solo la imagen.

-- 1) Backfill: cualquier fila histórica con tipo='ticket' pasa a
-- 'comprobante' ANTES de endurecer el CHECK — si esto se corriera al
-- revés, el UPDATE fallaría contra el nuevo constraint.
UPDATE evidencias SET tipo = 'comprobante' WHERE tipo = 'ticket';

-- 2) Reemplaza el CHECK para ya no aceptar 'ticket'.
ALTER TABLE evidencias DROP CONSTRAINT IF EXISTS evidencias_tipo_check;
ALTER TABLE evidencias
  ADD CONSTRAINT evidencias_tipo_check CHECK (tipo IN ('tablero', 'comprobante'));

-- 3) Columnas nuevas, solo pobladas cuando tipo = 'comprobante' — mismo
-- NUMERIC(10,2) que el resto de columnas de dinero/litros de la app (ver
-- auditoría de precisión financiera).
ALTER TABLE evidencias
  ADD COLUMN tipo_combustible_cargado TEXT,
  ADD COLUMN litros NUMERIC(10, 2),
  ADD COLUMN precio_por_litro NUMERIC(10, 2),
  ADD COLUMN monto_pagado NUMERIC(10, 2);
