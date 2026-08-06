-- Migración 0005 — refresh tokens.
--
-- El access token (JWT) ahora dura poco (ver `ACCESS_TOKEN_EXPIRES_IN` en
-- `.env.example` / `src/utils/jwt.ts`). Para no forzar un re-login cada
-- pocos minutos, login/registro además entregan un refresh token de vida
-- larga — se guarda su HASH (sha256), nunca el valor crudo, igual que un
-- password (ver `src/services/refreshTokenService.ts`).
--
-- Rotación: `POST /auth/refresh` marca el token usado como
-- `revocado = true` y crea uno nuevo — si un refresh token robado se usa
-- dos veces, la segunda vez ya aparece revocado.

CREATE TABLE IF NOT EXISTS refresh_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  usuario_id UUID NOT NULL REFERENCES usuarios (id),
  token_hash TEXT NOT NULL,
  expira_en TIMESTAMPTZ NOT NULL,
  revocado BOOLEAN NOT NULL DEFAULT false,
  creado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_refresh_tokens_hash ON refresh_tokens (token_hash);
CREATE INDEX IF NOT EXISTS idx_refresh_tokens_usuario ON refresh_tokens (usuario_id);
