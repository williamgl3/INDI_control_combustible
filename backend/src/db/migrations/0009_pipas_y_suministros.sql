-- Catálogo de pipas (camiones cisterna) que realizan suministros de
-- combustible en obra. Administrado por el área administrativa, igual
-- que el catálogo de vehículos.
CREATE TABLE IF NOT EXISTS pipas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(150) NOT NULL,
  modelo VARCHAR(150),
  numero_economico VARCHAR(100),
  activo BOOLEAN NOT NULL DEFAULT true,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Registro de suministro de pipa (despacho de combustible de la cisterna
-- al vehículo del chofer). pipa_id + los campos de texto permiten
-- conservar el dato aunque la pipa se desactive o el chofer la haya
-- capturado como "otra" (sin catálogo).
CREATE TABLE IF NOT EXISTS suministros (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chofer_id UUID NOT NULL REFERENCES usuarios (id),
  gasolinera VARCHAR(150) NOT NULL,
  litros NUMERIC(10, 2) NOT NULL,
  foto_ticket_path TEXT,
  pipa_id UUID REFERENCES pipas (id),
  pipa_nombre VARCHAR(150),
  pipa_modelo VARCHAR(150),
  pipa_numero_economico VARCHAR(100),
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_suministros_chofer ON suministros (chofer_id);
CREATE INDEX IF NOT EXISTS idx_suministros_pipa ON suministros (pipa_id);
