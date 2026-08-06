-- 0011: nuevo rol `superadmin`, por encima de `administrativo` — puede
-- todo lo que un administrativo más crear/gestionar cuentas de
-- administrativo. Los enums de Postgres solo permiten agregar valores al
-- final (no se puede insertar entre 'chofer' y 'administrativo'), así que
-- el orden del tipo queda 'chofer', 'administrativo', 'superadmin' — el
-- orden no importa para la lógica de la app, que compara por nombre, no
-- por posición.
ALTER TYPE rol_usuario ADD VALUE IF NOT EXISTS 'superadmin';
