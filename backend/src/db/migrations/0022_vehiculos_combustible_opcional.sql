-- Migración 0022 — `tipo_combustible` deja de ser obligatorio.
--
-- Motivo: la maquinaria pesada (catálogo aún pendiente del cliente) va
-- a importarse sin combustible confirmado en varios casos. Antes de
-- esta migración, `tipo_combustible NOT NULL` habría forzado un valor
-- inventado ("Magna" por default) que el panel admin mostraría como si
-- fuera un dato real — mejor mostrar explícitamente "sin especificar".
--
-- Verificado antes de escribir esta migración: 0 de los 40 registros
-- existentes tienen `tipo_combustible` NULL/vacío (36 Magna + 4 Diésel),
-- así que este ALTER no encuentra ningún NULL pendiente.
ALTER TABLE vehiculos ALTER COLUMN tipo_combustible DROP NOT NULL;

-- Misma red de seguridad que ya aplicamos a `placas`/`numero_economico`
-- en la migración 0020: cadena vacía no debe colarse como "hay dato".
ALTER TABLE vehiculos ADD CONSTRAINT chk_tipo_combustible_no_vacio
  CHECK (tipo_combustible IS NULL OR length(trim(tipo_combustible)) > 0);
