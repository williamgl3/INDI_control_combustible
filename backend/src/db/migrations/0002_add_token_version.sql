-- Migración 0002 — revocación de JWT vía token_version.
--
-- Cada usuario tiene un contador `token_version` que se embebe en el
-- payload del JWT al firmarlo (ver `src/utils/jwt.ts`). El middleware
-- `requireAuth` (`src/middleware/auth.ts`) compara el valor del token
-- contra el valor actual en BD; si no coinciden, el token se considera
-- revocado (401) aunque su firma siga siendo válida y no haya expirado.
--
-- Se incrementa en `cambiarPassword` (invalida cualquier sesión anterior
-- una vez que la contraseña cambió) — punto de "compromiso detectado"
-- señalado en la auditoría.

ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 1;
