-- Migración 0016 — nuevo rol `supervisor`: opera la pipa en campo (carga
-- a granel + registro de despachos hacia maquinaria), distinto de
-- `chofer` (solicita/comprueba su propia unidad) y `administrativo`
-- (panel de oficina). Mismo patrón que agregó `superadmin` en 0011.
ALTER TYPE rol_usuario ADD VALUE IF NOT EXISTS 'supervisor';
