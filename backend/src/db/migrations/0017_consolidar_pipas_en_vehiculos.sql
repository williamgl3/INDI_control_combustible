-- Migración 0017 — consolida el catálogo de pipas: `vehiculos` (que ya
-- acepta tipo_unidad='Pipa' en la UI, ver `catalogos_vehiculo.dart`) pasa
-- a ser la única fuente de verdad. La tabla `pipas` separada, hasta hoy
-- desconectada del catálogo real de vehículos, se elimina.
--
-- Sin pérdida de datos: al momento de esta migración `pipas` y
-- `suministros` están vacías en todos los entornos conocidos (verificado
-- antes de escribirla) — si alguna vez tuvieran filas, habría que migrar
-- pipas -> vehiculos y `suministros.pipa_id` antes de este paso.
ALTER TABLE suministros DROP CONSTRAINT suministros_pipa_id_fkey;
ALTER TABLE suministros
  ADD CONSTRAINT suministros_pipa_id_fkey FOREIGN KEY (pipa_id) REFERENCES vehiculos (id);

DROP TABLE pipas;
