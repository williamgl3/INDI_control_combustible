import crypto from 'node:crypto';
import { pool } from '../db/pool';

/// Refresh tokens de vida larga — el access token (JWT) ahora dura poco
/// (ver `ACCESS_TOKEN_EXPIRES_IN`), así que login/registro además emiten
/// uno de estos para poder renovar sin volver a pedir credenciales.
///
/// Igual que una contraseña: NUNCA se guarda el valor crudo en BD, solo
/// su hash (sha256 basta aquí — a diferencia de un password no hace
/// falta un hash lento/con sal, porque el valor ya es aleatorio de alta
/// entropía, no algo que un humano vaya a reusar/adivinar). Ver
/// migración `0005_refresh_tokens`.
const REFRESH_TOKEN_BYTES = 40;
const REFRESH_TOKEN_EXPIRES_IN_DAYS = Number(process.env.REFRESH_TOKEN_EXPIRES_IN_DAYS ?? 30);

function hashToken(tokenCrudo: string): string {
  return crypto.createHash('sha256').update(tokenCrudo).digest('hex');
}

function generarTokenCrudo(): string {
  return crypto.randomBytes(REFRESH_TOKEN_BYTES).toString('hex');
}

function fechaExpiracion(): Date {
  const fecha = new Date();
  fecha.setDate(fecha.getDate() + REFRESH_TOKEN_EXPIRES_IN_DAYS);
  return fecha;
}

/// Crea y persiste un refresh token nuevo para un usuario; devuelve el
/// valor CRUDO (el único momento en que existe fuera de la BD) para
/// mandarlo en la respuesta HTTP.
export async function emitirRefreshToken(usuarioId: string): Promise<string> {
  const tokenCrudo = generarTokenCrudo();
  await pool.query(
    `INSERT INTO refresh_tokens (usuario_id, token_hash, expira_en)
     VALUES ($1, $2, $3)`,
    [usuarioId, hashToken(tokenCrudo), fechaExpiracion()],
  );
  return tokenCrudo;
}

interface FilaRefreshToken {
  id: string;
  usuario_id: string;
  expira_en: Date;
  revocado: boolean;
}

/// Busca un refresh token válido (existe, no expirado, no revocado) por
/// su valor crudo. Devuelve `null` si no es válido por cualquier razón —
/// el llamador no necesita distinguir "no existe" de "expiró"/"revocado",
/// todos responden 401 igual (ver `POST /auth/refresh`).
export async function buscarRefreshTokenValido(
  tokenCrudo: string,
): Promise<{ id: string; usuarioId: string } | null> {
  const { rows } = await pool.query<FilaRefreshToken>(
    'SELECT id, usuario_id, expira_en, revocado FROM refresh_tokens WHERE token_hash = $1',
    [hashToken(tokenCrudo)],
  );
  const fila = rows[0];
  if (!fila) return null;
  if (fila.revocado) return null;
  if (fila.expira_en.getTime() <= Date.now()) return null;
  return { id: fila.id, usuarioId: fila.usuario_id };
}

async function revocarPorId(id: string): Promise<void> {
  await pool.query('UPDATE refresh_tokens SET revocado = true WHERE id = $1', [id]);
}

/// Rota un refresh token: revoca el usado y emite uno nuevo para el
/// mismo usuario. Si el token crudo ya no es válido, devuelve `null` (el
/// llamador responde 401 sin rotar nada).
export async function rotarRefreshToken(
  tokenCrudo: string,
): Promise<{ usuarioId: string; nuevoRefreshToken: string } | null> {
  const valido = await buscarRefreshTokenValido(tokenCrudo);
  if (!valido) return null;
  await revocarPorId(valido.id);
  const nuevoRefreshToken = await emitirRefreshToken(valido.usuarioId);
  return { usuarioId: valido.usuarioId, nuevoRefreshToken };
}

/// Revoca un único refresh token (logout de una sola sesión/dispositivo).
export async function revocarRefreshToken(tokenCrudo: string): Promise<void> {
  await pool.query('UPDATE refresh_tokens SET revocado = true WHERE token_hash = $1', [
    hashToken(tokenCrudo),
  ]);
}

/// Revoca TODOS los refresh tokens de un usuario — usado junto con el
/// incremento de `token_version` cuando cambia la contraseña (propia o
/// reseteada por un admin), para que ni el access token ni ningún refresh
/// token viejo sigan sirviendo.
export async function revocarTodosLosRefreshTokensDe(usuarioId: string): Promise<void> {
  await pool.query(
    'UPDATE refresh_tokens SET revocado = true WHERE usuario_id = $1 AND revocado = false',
    [usuarioId],
  );
}
