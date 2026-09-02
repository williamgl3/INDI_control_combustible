-- Migración 0019 — separa explícitamente "vehículo (modelo)" de "placas"
-- a nivel de nombre de columna. El dato ya vivía correcto en columnas
-- distintas desde la importación del catálogo GAMI (`modelo` = nombre
-- del vehículo, `identificador` = placa/número económico) — el problema
-- era que ninguna pantalla mostraba `modelo`, nunca que estuvieran
-- mezclados en la base de datos. Esto solo renombra la columna para que
-- el nombre refleje su contenido real.
--
-- `placas` sigue significando "identificador único físico de la
-- unidad" para los 3 tipos de unidad — placa para Vehículo/Pipa, número
-- económico para Maquinaria (ver `catalogos_vehiculo.dart`) — no se
-- agrega una columna aparte para maquinaria: la única invariante real es
-- "código único por unidad", sin importar si es placa o núm. económico,
-- y una segunda columna solo obligaría a un CHECK cruzado sin beneficio.
-- La constraint UNIQUE (antes `vehiculos_identificador_key`) se conserva
-- automáticamente bajo el nuevo nombre de columna.
ALTER TABLE vehiculos RENAME COLUMN identificador TO placas;

-- `modelo` ya existía (nullable) — las únicas 2 filas sin valor real
-- (datos de prueba de una sesión anterior, sin cargas/solicitudes reales
-- asociadas, ya confirmado y eliminadas antes de esta migración) fueron
-- borradas, así que este ALTER no encuentra ningún NULL pendiente.
ALTER TABLE vehiculos ALTER COLUMN modelo SET NOT NULL;
