-- Migración 0030 — intervalo de servicio opcional.
--
-- Antes, `intervalo_servicio` era NOT NULL DEFAULT 0. Ese cero no
-- representa una periodicidad real y obligaba a inventar un intervalo al
-- crear una unidad sin configuración de mantenimiento.
--
-- Ahora NULL significa explícitamente "No configurado". Los valores
-- positivos y los ceros heredados se conservan sin UPDATE; la aplicación
-- interpreta temporalmente cualquier valor <= 0 como no configurado.
--
-- Impacto: nuevas filas sin intervalo quedan en NULL y pueden configurarse
-- posteriormente. No se modifica `lectura_ultimo_servicio` ni otra columna.
--
-- Reversión manual (NO ejecutar automáticamente): antes de recuperar
-- NOT NULL debe decidirse empresarialmente qué valor asignar a cada NULL,
-- resolverlos de forma explícita y solo entonces restaurar NOT NULL/default.
ALTER TABLE vehiculos
  ALTER COLUMN intervalo_servicio DROP NOT NULL,
  ALTER COLUMN intervalo_servicio DROP DEFAULT;
