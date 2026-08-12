-- Migración 0031 — separa el combustible del motor del inventario a granel
-- de Marimbas/Pipas. Convive con las tablas y vistas legadas: no clasifica,
-- actualiza ni elimina registros anteriores.

-- Las cargas históricas no conocen su solicitud por UUID. Las operaciones
-- nuevas con partidas siempre llenan solicitud_id desde el servicio.
ALTER TABLE solicitudes_autorizacion
  ADD CONSTRAINT solicitudes_id_vehiculo_unique UNIQUE (id, vehiculo_id);
ALTER TABLE cargas
  ADD COLUMN solicitud_id UUID REFERENCES solicitudes_autorizacion(id),
  ADD CONSTRAINT cargas_id_solicitud_vehiculo_unique
    UNIQUE (id, solicitud_id, vehiculo_id),
  ADD CONSTRAINT cargas_solicitud_vehiculo_fk
    FOREIGN KEY (solicitud_id, vehiculo_id)
    REFERENCES solicitudes_autorizacion(id, vehiculo_id);
CREATE INDEX idx_cargas_solicitud ON cargas(solicitud_id);

CREATE TABLE solicitud_partidas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  solicitud_id UUID NOT NULL,
  vehiculo_id UUID NOT NULL,
  tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('consumo_propio', 'carga_granel')),
  litros_solicitados NUMERIC(10, 2) NOT NULL CHECK (litros_solicitados > 0),
  litros_autorizados NUMERIC(10, 2) CHECK (litros_autorizados > 0),
  tipo_combustible VARCHAR(50) NOT NULL
    CHECK (tipo_combustible IN ('Diésel', 'Magna', 'Premium')),
  estado VARCHAR(20) NOT NULL DEFAULT 'pendiente'
    CHECK (estado IN ('pendiente', 'aprobada', 'rechazada')),
  observaciones TEXT,
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (solicitud_id, tipo),
  UNIQUE (id, solicitud_id, vehiculo_id, tipo, tipo_combustible),
  FOREIGN KEY (solicitud_id, vehiculo_id)
    REFERENCES solicitudes_autorizacion(id, vehiculo_id),
  CHECK (estado <> 'aprobada' OR litros_autorizados IS NOT NULL),
  CHECK (litros_autorizados IS NULL OR litros_autorizados <= litros_solicitados)
);
CREATE INDEX idx_solicitud_partidas_solicitud ON solicitud_partidas(solicitud_id);

CREATE TABLE carga_partidas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  carga_id UUID NOT NULL,
  solicitud_id UUID NOT NULL,
  vehiculo_id UUID NOT NULL,
  solicitud_partida_id UUID NOT NULL,
  tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('consumo_propio', 'carga_granel')),
  tipo_combustible VARCHAR(50) NOT NULL
    CHECK (tipo_combustible IN ('Diésel', 'Magna', 'Premium')),
  litros_cargados NUMERIC(10, 2) NOT NULL CHECK (litros_cargados > 0),
  creada_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (carga_id, tipo),
  UNIQUE (id, carga_id, tipo),
  UNIQUE (id, vehiculo_id, tipo, tipo_combustible),
  FOREIGN KEY (carga_id, solicitud_id, vehiculo_id)
    REFERENCES cargas(id, solicitud_id, vehiculo_id),
  FOREIGN KEY (solicitud_partida_id, solicitud_id, vehiculo_id, tipo, tipo_combustible)
    REFERENCES solicitud_partidas(id, solicitud_id, vehiculo_id, tipo, tipo_combustible)
);
CREATE INDEX idx_carga_partidas_carga ON carga_partidas(carga_id);
CREATE INDEX idx_carga_partidas_solicitud ON carga_partidas(solicitud_partida_id);

CREATE TABLE comprobantes_estacion (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  carga_id UUID NOT NULL REFERENCES cargas(id),
  carga_partida_id UUID,
  concepto VARCHAR(30) NOT NULL
    CHECK (concepto IN ('consumo_propio', 'carga_granel', 'visita_completa')),
  folio_estacion VARCHAR(100) NOT NULL CHECK (length(btrim(folio_estacion)) BETWEEN 1 AND 100),
  foto_path TEXT,
  litros_indicados NUMERIC(10, 2) CHECK (litros_indicados > 0),
  gasolinera VARCHAR(150) NOT NULL CHECK (length(btrim(gasolinera)) BETWEEN 1 AND 150),
  fecha TIMESTAMPTZ NOT NULL DEFAULT now(),
  registrado_por UUID NOT NULL REFERENCES usuarios(id),
  CHECK (
    (concepto = 'visita_completa' AND carga_partida_id IS NULL) OR
    (concepto <> 'visita_completa' AND carga_partida_id IS NOT NULL)
  ),
  UNIQUE (carga_id, folio_estacion),
  FOREIGN KEY (carga_partida_id, carga_id, concepto)
    REFERENCES carga_partidas(id, carga_id, tipo)
);
CREATE INDEX idx_comprobantes_carga ON comprobantes_estacion(carga_id);
CREATE INDEX idx_comprobantes_partida ON comprobantes_estacion(carga_partida_id);

CREATE TABLE movimientos_inventario_marimba (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  marimba_id UUID NOT NULL REFERENCES vehiculos(id),
  tipo_combustible VARCHAR(50) NOT NULL
    CHECK (tipo_combustible IN ('Diésel', 'Magna', 'Premium')),
  tipo VARCHAR(30) NOT NULL CHECK (tipo IN ('entrada_granel', 'despacho_maquinaria')),
  litros NUMERIC(10, 2) NOT NULL CHECK (litros > 0),
  carga_partida_id UUID,
  carga_partida_tipo VARCHAR(30),
  despacho_id UUID,
  recorrido_id UUID REFERENCES recorridos_marimba(id),
  registrado_por UUID NOT NULL REFERENCES usuarios(id),
  responsable_id UUID REFERENCES usuarios(id),
  observacion TEXT,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (
    (tipo = 'entrada_granel' AND carga_partida_id IS NOT NULL
      AND carga_partida_tipo = 'carga_granel' AND despacho_id IS NULL) OR
    (tipo = 'despacho_maquinaria' AND despacho_id IS NOT NULL
      AND recorrido_id IS NOT NULL
      AND carga_partida_id IS NULL AND carga_partida_tipo IS NULL)
  ),
  FOREIGN KEY (carga_partida_id, marimba_id, carga_partida_tipo, tipo_combustible)
    REFERENCES carga_partidas(id, vehiculo_id, tipo, tipo_combustible)
);
CREATE UNIQUE INDEX uq_movimiento_entrada_granel
  ON movimientos_inventario_marimba(carga_partida_id)
  WHERE tipo = 'entrada_granel';
CREATE UNIQUE INDEX uq_movimiento_despacho
  ON movimientos_inventario_marimba(despacho_id)
  WHERE tipo = 'despacho_maquinaria';
CREATE INDEX idx_movimientos_marimba_combustible_fecha
  ON movimientos_inventario_marimba(marimba_id, tipo_combustible, creado_en);
CREATE INDEX idx_movimientos_recorrido ON movimientos_inventario_marimba(recorrido_id);

ALTER TABLE despachos_marimba
  ADD COLUMN responsable_id UUID REFERENCES usuarios(id),
  ADD COLUMN tipo_combustible VARCHAR(50)
    CHECK (tipo_combustible IN ('Diésel', 'Magna', 'Premium')),
  ADD COLUMN horometro NUMERIC(12, 2) CHECK (horometro >= 0),
  ADD COLUMN foto_horometro_path TEXT,
  ADD COLUMN medidor_inicial NUMERIC(12, 2) CHECK (medidor_inicial >= 0),
  ADD COLUMN medidor_final NUMERIC(12, 2) CHECK (medidor_final >= 0),
  ADD COLUMN foto_medidor_path TEXT,
  ADD COLUMN cantidad_declarada BOOLEAN,
  ADD COLUMN ubicacion VARCHAR(150),
  ADD COLUMN observaciones TEXT,
  ADD CONSTRAINT despachos_medidor_orden_check
    CHECK (medidor_final IS NULL OR medidor_inicial IS NULL OR medidor_final >= medidor_inicial);
CREATE INDEX idx_despachos_responsable ON despachos_marimba(responsable_id);

ALTER TABLE recorridos_marimba
  ADD COLUMN registrado_por UUID REFERENCES usuarios(id),
  ADD COLUMN tipo_combustible VARCHAR(50)
    CHECK (tipo_combustible IN ('Diésel', 'Magna', 'Premium')),
  ADD COLUMN entradas_granel_total NUMERIC(10, 2),
  ADD COLUMN existencia_fisica NUMERIC(10, 2) CHECK (existencia_fisica >= 0),
  ADD COLUMN estado_conciliacion VARCHAR(30)
    CHECK (estado_conciliacion IN ('conciliado', 'diferencia_pendiente')),
  ADD COLUMN observaciones_cierre TEXT,
  ADD COLUMN foto_nivel_path TEXT;

CREATE UNIQUE INDEX uq_recorrido_abierto_por_marimba
  ON recorridos_marimba(marimba_id)
  WHERE estado = 'abierto';

ALTER TABLE recorridos_marimba
  ADD CONSTRAINT recorridos_id_marimba_unique UNIQUE(id, marimba_id),
  ADD CONSTRAINT recorridos_id_marimba_combustible_unique
    UNIQUE(id, marimba_id, tipo_combustible);
ALTER TABLE despachos_marimba
  ADD CONSTRAINT despachos_id_marimba_combustible_unique
    UNIQUE(id, marimba_id, tipo_combustible),
  ADD CONSTRAINT despachos_recorrido_marimba_fk
    FOREIGN KEY (recorrido_id, marimba_id) REFERENCES recorridos_marimba(id, marimba_id);
ALTER TABLE movimientos_inventario_marimba
  ADD CONSTRAINT movimientos_recorrido_marimba_combustible_fk
    FOREIGN KEY (recorrido_id, marimba_id, tipo_combustible)
    REFERENCES recorridos_marimba(id, marimba_id, tipo_combustible),
  ADD CONSTRAINT movimientos_despacho_marimba_combustible_fk
    FOREIGN KEY (despacho_id, marimba_id, tipo_combustible)
    REFERENCES despachos_marimba(id, marimba_id, tipo_combustible);

-- `suministros`, `movimientos_marimba` y `saldo_marimba` permanecen sin
-- cambios para consultas históricas. Las operaciones nuevas usan las
-- partidas y movimientos_inventario_marimba como única fuente de saldo.
