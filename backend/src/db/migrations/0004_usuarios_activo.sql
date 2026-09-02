-- Migración 0004 — gestión de usuarios: activar/desactivar cuentas.
--
-- Cuentas desactivadas (`activo = false`) no pueden iniciar sesión (ver
-- `authService.login`) — el rechazo ocurre ANTES de validar la
-- contraseña, para no revelar si la cuenta existe/está activa vía el
-- mensaje de error.

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT true;

-- `POST /usuarios/administrativos` (alta de administrativos por otro
-- administrativo) solo pide { nombre, usuario, correo, password } — a
-- diferencia del alta de choferes (`registro-chofer`), no se le pide
-- apellido paterno/fecha de nacimiento (esos datos tienen sentido para
-- validar edad mínima de un chofer operando maquinaria, no para una
-- cuenta de escritorio administrativa). Se relajan a NULLABLE para poder
-- omitirlos en ese flujo sin romper la fila.
ALTER TABLE usuarios
  ALTER COLUMN apellido_paterno DROP NOT NULL,
  ALTER COLUMN fecha_nacimiento DROP NOT NULL;
