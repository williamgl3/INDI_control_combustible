-- Esquema de INDI Combustible.
--
-- Replica el contrato de los mocks del frontend (marcados con
-- TODO-BACKEND en el código Flutter) — nombres de campo en snake_case,
-- misma forma de dato, mismas reglas de negocio. Ver los servicios en
-- src/services/ para la lógica que consume estas tablas.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

DO $$ BEGIN
  CREATE TYPE rol_usuario AS ENUM ('chofer', 'administrativo');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE estado_solicitud AS ENUM ('pendiente', 'aprobada', 'rechazada');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Choferes y administrativos. Una sola tabla porque comparten el mismo
-- flujo de login (usuario+password) y solo se distinguen por `rol`.
CREATE TABLE IF NOT EXISTS usuarios (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario VARCHAR(50) UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  apellido_paterno VARCHAR(100) NOT NULL,
  apellido_materno VARCHAR(100),
  correo VARCHAR(150) NOT NULL,
  fecha_nacimiento DATE NOT NULL,
  rol rol_usuario NOT NULL,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Catálogo compartido de vehículos/maquinaria de la obra — ya NO vive
-- embebido en el chofer (varios choferes pueden usar la misma unidad en
-- días distintos). Incluye los campos de mantenimiento preventivo
-- (intervalo_servicio, lectura/fecha del último servicio) que ya existen
-- en el modelo `Vehiculo` del frontend.
CREATE TABLE IF NOT EXISTS vehiculos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tipo_unidad VARCHAR(50) NOT NULL,
  identificador VARCHAR(150) NOT NULL,
  tipo_combustible VARCHAR(50) NOT NULL,
  tope_semanal NUMERIC(10, 2) NOT NULL DEFAULT 0,
  modelo VARCHAR(150),
  intervalo_servicio NUMERIC(10, 2) NOT NULL DEFAULT 0,
  lectura_ultimo_servicio NUMERIC(10, 2),
  fecha_ultimo_servicio TIMESTAMPTZ,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Folios de autorización correlativos (ej. "FA-1000", "FA-1001"...),
-- igual que `_folioSeq` en el mock.
CREATE SEQUENCE IF NOT EXISTS folio_autorizacion_seq START 1000;

CREATE TABLE IF NOT EXISTS solicitudes_autorizacion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chofer_id UUID NOT NULL REFERENCES usuarios (id),
  vehiculo_id UUID NOT NULL REFERENCES vehiculos (id),
  litros_solicitados NUMERIC(10, 2) NOT NULL,
  litros_autorizados NUMERIC(10, 2),
  costo_estimado NUMERIC(10, 2) NOT NULL,
  es_urgente BOOLEAN NOT NULL DEFAULT false,
  motivo_chofer TEXT,
  actividad TEXT NOT NULL,
  fecha_programada TIMESTAMPTZ NOT NULL,
  estado estado_solicitud NOT NULL DEFAULT 'pendiente',
  aprobada_por VARCHAR(150),
  folio_autorizacion VARCHAR(50) UNIQUE,
  comentario TEXT,
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_solicitudes_vehiculo ON solicitudes_autorizacion (vehiculo_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_chofer ON solicitudes_autorizacion (chofer_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_estado ON solicitudes_autorizacion (estado);

-- Registro 1 del día: se llena justo después de cargar combustible,
-- contra un folio ya autorizado.
CREATE TABLE IF NOT EXISTS cargas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chofer_id UUID NOT NULL REFERENCES usuarios (id),
  vehiculo_id UUID NOT NULL REFERENCES vehiculos (id),
  folio_autorizacion VARCHAR(50) NOT NULL REFERENCES solicitudes_autorizacion (folio_autorizacion),
  litros_cargados NUMERIC(10, 2) NOT NULL,
  km_al_cargar NUMERIC(10, 2) NOT NULL,
  gasolinera VARCHAR(150) NOT NULL,
  foto_ticket_path TEXT,
  foto_tablero_path TEXT,
  litros_detectados_ocr NUMERIC(10, 2),
  pendiente_de_sincronizar BOOLEAN NOT NULL DEFAULT false,
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cargas_chofer ON cargas (chofer_id);
CREATE INDEX IF NOT EXISTS idx_cargas_vehiculo ON cargas (vehiculo_id);

-- Registro 2 del día: se llena cuando el chofer termina de trabajar.
CREATE TABLE IF NOT EXISTS cierres_dia (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  chofer_id UUID NOT NULL REFERENCES usuarios (id),
  carga_id UUID NOT NULL UNIQUE REFERENCES cargas (id),
  km_final NUMERIC(10, 2) NOT NULL,
  foto_tablero_path TEXT NOT NULL,
  registrada_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_cierres_chofer ON cierres_dia (chofer_id);

-- Incidencias/fallas reportadas por un chofer sobre un vehículo (ej.
-- "se ponchó una llanta", "el motor hace un ruido raro") — distinto del
-- mantenimiento preventivo por km/horómetro (`intervalo_servicio`), que
-- es programado, no reactivo. Alimenta la pestaña Mantenimiento del
-- panel admin junto con el resto del diagnóstico preventivo.
DO $$ BEGIN
  CREATE TYPE estado_incidencia AS ENUM ('abierta', 'resuelta');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS incidencias_vehiculo (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vehiculo_id UUID NOT NULL REFERENCES vehiculos (id),
  chofer_id UUID NOT NULL REFERENCES usuarios (id),
  descripcion TEXT NOT NULL,
  estado estado_incidencia NOT NULL DEFAULT 'abierta',
  resuelta_por VARCHAR(150),
  comentario_resolucion TEXT,
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  resuelta_en TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_incidencias_vehiculo ON incidencias_vehiculo (vehiculo_id);
CREATE INDEX IF NOT EXISTS idx_incidencias_estado ON incidencias_vehiculo (estado);

CREATE TABLE IF NOT EXISTS precios_combustible (
  tipo_combustible VARCHAR(50) PRIMARY KEY,
  precio_por_litro NUMERIC(10, 2) NOT NULL,
  actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Config de un solo valor por ahora (presupuesto semanal en pesos).
-- TODO-SPEC: el valor real de negocio está pendiente de confirmar; el
-- mock del frontend usa $50,000/semana como placeholder.
CREATE TABLE IF NOT EXISTS configuracion (
  clave VARCHAR(50) PRIMARY KEY,
  valor NUMERIC(12, 2) NOT NULL
);

-- Catálogo de pipas (camiones cisterna) que realizan suministros de
-- combustible en obra.
CREATE TABLE IF NOT EXISTS pipas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre VARCHAR(150) NOT NULL,
  modelo VARCHAR(150),
  numero_economico VARCHAR(100),
  activo BOOLEAN NOT NULL DEFAULT true,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Registro de suministro de pipa (despacho de combustible de la cisterna
-- al vehículo del chofer).
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

INSERT INTO
  precios_combustible (tipo_combustible, precio_por_litro)
VALUES
  ('Diésel', 24.50),
  ('Gasolina', 23.80) ON CONFLICT (tipo_combustible) DO NOTHING;

INSERT INTO
  configuracion (clave, valor)
VALUES
  ('presupuesto_semanal_total', 50000) ON CONFLICT (clave) DO NOTHING;
