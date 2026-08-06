-- 0010: la evidencia de "tablero" ahora captura el km como dato
-- estructurado (no solo la foto), un registro de evidencia puede traer
-- varias fotos (ticket + tablero + comprobante subidos juntos), y se
-- distingue explícitamente cuándo el chofer eligió "vincular después"
-- en vez de simplemente no tener folio por el tipo de evidencia.
ALTER TABLE evidencias
  ADD COLUMN km NUMERIC(10, 1),
  ADD COLUMN foto_urls TEXT[] NOT NULL DEFAULT '{}',
  ADD COLUMN pendiente_vincular BOOLEAN NOT NULL DEFAULT false;

-- Todo registro existente tenía exactamente una foto (`foto_url`);
-- se respalda ahí para que `foto_urls` nunca quede vacío.
UPDATE evidencias SET foto_urls = ARRAY[foto_url] WHERE foto_urls = '{}';
