import bcrypt from 'bcrypt';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import { firmarToken } from '../utils/jwt';
import { registrarAuditoria } from './auditoriaService';
import * as refreshTokenService from './refreshTokenService';
import type { Perfil, RolUsuario } from '../types';

const SALT_ROUNDS = 12;

interface FilaUsuario {
  id: string;
  usuario: string;
  password_hash: string;
  nombre: string;
  apellido_paterno: string | null;
  apellido_materno: string | null;
  correo: string;
  fecha_nacimiento: Date | null;
  rol: RolUsuario;
  token_version: number;
  activo: boolean;
}

function aPerfil(fila: FilaUsuario): Perfil {
  return {
    id: fila.id,
    usuario: fila.usuario,
    nombre: fila.nombre,
    apellidoPaterno: fila.apellido_paterno,
    apellidoMaterno: fila.apellido_materno,
    correo: fila.correo,
    fechaNacimiento: fila.fecha_nacimiento ? fila.fecha_nacimiento.toISOString().slice(0, 10) : null,
    rol: fila.rol,
  };
}

async function emitirSesion(fila: FilaUsuario) {
  const perfil = aPerfil(fila);
  const token = firmarToken({
    sub: perfil.id,
    usuario: perfil.usuario,
    rol: perfil.rol,
    tokenVersion: fila.token_version,
  });
  const refreshToken = await refreshTokenService.emitirRefreshToken(fila.id);
  return { perfil, token, refreshToken };
}

export async function login(usuario: string, password: string) {
  const { rows } = await pool.query<FilaUsuario>('SELECT * FROM usuarios WHERE usuario = $1', [
    usuario,
  ]);
  const fila = rows[0];
  // El chequeo de cuenta desactivada va ANTES de comparar la contraseña
  // (pero después de saber si la cuenta existe, para no cambiar el
  // comportamiento de "usuario no existe" de abajo) — una cuenta
  // desactivada nunca debe dejar entrar aunque la contraseña sea
  // correcta, y el mensaje debe ser explícito para que el chofer/admin
  // sepa que tiene que contactar a un administrativo en vez de reintentar
  // contraseñas.
  if (fila && !fila.activo) {
    throw new ApiError(401, 'Esta cuenta está desactivada.');
  }
  if (!fila || !(await bcrypt.compare(password, fila.password_hash))) {
    throw new ApiError(401, 'Usuario o contraseña incorrectos.');
  }
  return emitirSesion(fila);
}

export async function registrarChofer(datos: {
  nombre: string;
  apellidoPaterno: string;
  apellidoMaterno: string;
  fechaNacimiento?: string | null | undefined;
  correo: string;
  usuario: string;
  password: string;
}) {
  const fila = await crearUsuario({ ...datos, rol: 'chofer' });
  return emitirSesion(fila);
}

/// Compartido por `registrarChofer` (auto-servicio, rol fijo `chofer`) y
/// `crearAdministrativo` (creado por un admin, rol fijo `administrativo`)
/// — misma validación de usuario único + hash de password, solo cambia el
/// rol y quién dispara la acción.
async function crearUsuario(datos: {
  nombre: string;
  apellidoPaterno?: string | null | undefined;
  apellidoMaterno?: string | null | undefined;
  fechaNacimiento?: string | null | undefined;
  correo: string;
  usuario: string;
  password: string;
  rol: RolUsuario;
}): Promise<FilaUsuario> {
  const existente = await pool.query('SELECT 1 FROM usuarios WHERE usuario = $1', [
    datos.usuario,
  ]);
  if ((existente.rowCount ?? 0) > 0) {
    throw new ApiError(409, 'Ese usuario ya está en uso.');
  }

  const passwordHash = await bcrypt.hash(datos.password, SALT_ROUNDS);
  const { rows } = await pool.query<FilaUsuario>(
    `INSERT INTO usuarios
       (usuario, password_hash, nombre, apellido_paterno, apellido_materno, correo, fecha_nacimiento, rol)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     RETURNING *`,
    [
      datos.usuario,
      passwordHash,
      datos.nombre,
      datos.apellidoPaterno ?? null,
      datos.apellidoMaterno ?? null,
      datos.correo,
      datos.fechaNacimiento ?? null,
      datos.rol,
    ],
  );
  const fila = rows[0];
  if (!fila) throw new ApiError(500, 'No se pudo crear el usuario.');
  return fila;
}

// SECURITY: resuelto — antes esta función lanzaba 404 cuando la cuenta no
// existía, lo que permitía enumerar usuarios/correos válidos probando
// contra este endpoint. Ahora SIEMPRE responde éxito sin importar si la
// cuenta existe o no; el route handler (`auth.routes.ts`) también
// devuelve el mismo status/shape en ambos casos. Si la cuenta no existe,
// simplemente no se dispara ningún envío.
export async function recuperarPassword(usuarioOCorreo: string): Promise<void> {
  const { rows } = await pool.query(
    'SELECT 1 FROM usuarios WHERE usuario = $1 OR correo = $1',
    [usuarioOCorreo],
  );
  if ((rows.length ?? 0) > 0) {
    // TODO-BACKEND: aquí se dispararía el envío real de correo/SMS de
    // recuperación una vez que se decida el proveedor (no implementado en
    // el mock original tampoco).
  }
}

export async function cambiarPassword(
  userId: string,
  passwordActual: string,
  passwordNueva: string,
) {
  const { rows } = await pool.query<FilaUsuario>('SELECT * FROM usuarios WHERE id = $1', [
    userId,
  ]);
  const fila = rows[0];
  if (!fila) throw new ApiError(404, 'Usuario no encontrado.');
  if (!(await bcrypt.compare(passwordActual, fila.password_hash))) {
    throw new ApiError(401, 'La contraseña actual no es correcta.');
  }
  const nuevoHash = await bcrypt.hash(passwordNueva, SALT_ROUNDS);
  // Incrementa token_version al cambiar la contraseña: cualquier JWT ya
  // emitido con la versión anterior queda revocado (requireAuth lo
  // rechaza), forzando a volver a iniciar sesión en todas las demás
  // sesiones/dispositivos.
  await pool.query(
    'UPDATE usuarios SET password_hash = $1, token_version = token_version + 1 WHERE id = $2',
    [nuevoHash, userId],
  );
  // Los refresh tokens viejos también deben dejar de servir — si no, con
  // uno de ellos se puede volver a sacar un access token válido después
  // de un cambio de contraseña que se supone invalida la sesión.
  await refreshTokenService.revocarTodosLosRefreshTokensDe(userId);
}

export interface ChoferOAdministrativo extends Perfil {
  activo: boolean;
}

/// Usado por el panel administrativo (`ChoferesTab`, `AutorizacionesTab`,
/// `ConcentradoTab` en el frontend) — a pesar del nombre histórico
/// (`/auth/choferes`), también incluye cuentas `administrativo` para que
/// la gestión de usuarios (activar/desactivar, resetear password) pueda
/// listarlas todas desde el mismo endpoint.
export async function listarChoferes(): Promise<ChoferOAdministrativo[]> {
  const { rows } = await pool.query<FilaUsuario>(
    "SELECT * FROM usuarios WHERE rol = 'chofer' ORDER BY nombre, apellido_paterno",
  );
  return rows.map((fila) => ({ ...aPerfil(fila), activo: fila.activo }));
}

/// Activa/desactiva una cuenta. La validación de "no desactivarte a ti
/// mismo" vive en la ruta (`usuarios.routes.ts`), que es quien conoce al
/// actor (`req.usuarioActual.sub`) — aquí solo se aplica el cambio y se
/// audita.
///
/// `actorRol` se valida aquí (no en la ruta) porque la regla depende del
/// rol del USUARIO OBJETIVO, que solo se conoce tras leerlo de BD: un
/// `administrativo` puede cambiar el estado de choferes, pero NO de otra
/// cuenta `administrativo` ni de un `superadmin` — eso queda exclusivo de
/// `superadmin`. Nunca confiar solo en que el frontend oculte el botón.
export async function actualizarEstadoUsuario(
  usuarioId: string,
  activo: boolean,
  actorId: string,
  actorRol: RolUsuario,
): Promise<void> {
  const { rows: filaActual } = await pool.query<FilaUsuario>(
    'SELECT * FROM usuarios WHERE id = $1',
    [usuarioId],
  );
  const objetivo = filaActual[0];
  if (!objetivo) throw new ApiError(404, 'Usuario no encontrado.');

  if (objetivo.rol !== 'chofer' && actorRol !== 'superadmin') {
    throw new ApiError(403, 'Solo un superadmin puede cambiar el estado de esta cuenta.');
  }

  const { rows } = await pool.query<FilaUsuario>(
    'UPDATE usuarios SET activo = $1 WHERE id = $2 RETURNING *',
    [activo, usuarioId],
  );
  if (!rows[0]) throw new ApiError(404, 'Usuario no encontrado.');

  if (!activo) {
    // Una cuenta desactivada tampoco debe poder seguir usando sesiones ya
    // abiertas — revoca sus refresh tokens (el access token, de vida
    // corta, expira solo unos minutos después).
    await refreshTokenService.revocarTodosLosRefreshTokensDe(usuarioId);
  }

  await registrarAuditoria({
    usuarioId: actorId,
    accion: activo ? 'activar_usuario' : 'desactivar_usuario',
    entidad: 'usuario',
    entidadId: usuarioId,
  });
}

/// Reseteo administrativo de contraseña — a diferencia de
/// `cambiarPassword` (el propio usuario, con su contraseña actual), este
/// lo dispara un administrativo sobre la cuenta de otro usuario.
export async function resetearPassword(
  usuarioId: string,
  passwordNueva: string,
  actorId: string,
): Promise<void> {
  const nuevoHash = await bcrypt.hash(passwordNueva, SALT_ROUNDS);
  const { rows } = await pool.query(
    'UPDATE usuarios SET password_hash = $1, token_version = token_version + 1 WHERE id = $2 RETURNING id',
    [nuevoHash, usuarioId],
  );
  if (!rows[0]) throw new ApiError(404, 'Usuario no encontrado.');

  await refreshTokenService.revocarTodosLosRefreshTokensDe(usuarioId);

  await registrarAuditoria({
    usuarioId: actorId,
    accion: 'resetear_password_usuario',
    entidad: 'usuario',
    entidadId: usuarioId,
  });
}

/// Alta de una cuenta administrativa por un superadmin (ver
/// `requireRole('superadmin')` en `usuarios.routes.ts`) — no devuelve
/// token/refreshToken porque no es un login, es la creación de la cuenta
/// de alguien más. A diferencia de `registrarChofer`, no pide fecha de
/// nacimiento (no aplica validación de edad mínima a una cuenta de
/// escritorio) — esa columna queda NULL (ver migración
/// `0004_usuarios_activo`, que la relaja a NULLABLE). Apellidos sí son
/// obligatorios, igual que en `registrarChofer`.
export async function crearAdministrativo(
  datos: {
    nombre: string;
    apellidoPaterno: string;
    apellidoMaterno: string;
    correo: string;
    usuario: string;
    password: string;
  },
  actorId: string,
): Promise<Perfil> {
  const fila = await crearUsuario({ ...datos, rol: 'administrativo' });

  await registrarAuditoria({
    usuarioId: actorId,
    accion: 'crear_administrativo',
    entidad: 'usuario',
    entidadId: fila.id,
  });

  return aPerfil(fila);
}

/// Crea la cuenta de un supervisor (opera la marimba en campo) — misma
/// forma que `crearAdministrativo`, solo cambia el rol. La crea un
/// administrativo desde el panel, igual que cualquier otra cuenta de
/// tercero (el supervisor no tiene un flujo de auto-registro, a
/// diferencia del chofer).
export async function crearSupervisor(
  datos: {
    nombre: string;
    apellidoPaterno: string;
    apellidoMaterno: string;
    correo: string;
    usuario: string;
    password: string;
  },
  actorId: string,
): Promise<Perfil> {
  const fila = await crearUsuario({ ...datos, rol: 'supervisor' });

  await registrarAuditoria({
    usuarioId: actorId,
    accion: 'crear_supervisor',
    entidad: 'usuario',
    entidadId: fila.id,
  });

  return aPerfil(fila);
}

/// Renueva la sesión a partir de un refresh token válido: lo rota
/// (revoca el usado, emite uno nuevo) y firma un access token nuevo con
/// el `token_version` ACTUAL en BD — si la contraseña cambió después de
/// emitir este refresh token, ya habría sido revocado por
/// `cambiarPassword`/`resetearPassword`/`actualizarEstadoUsuario`, así
/// que llegar aquí con un token todavía válido implica que el usuario
/// sigue vigente.
export async function refrescarToken(
  tokenCrudo: string,
): Promise<{ token: string; refreshToken: string }> {
  const rotado = await refreshTokenService.rotarRefreshToken(tokenCrudo);
  if (!rotado) {
    throw new ApiError(401, 'Refresh token inválido o expirado.');
  }

  const { rows } = await pool.query<FilaUsuario>('SELECT * FROM usuarios WHERE id = $1', [
    rotado.usuarioId,
  ]);
  const fila = rows[0];
  if (!fila || !fila.activo) {
    throw new ApiError(401, 'Refresh token inválido o expirado.');
  }

  const token = firmarToken({
    sub: fila.id,
    usuario: fila.usuario,
    rol: fila.rol,
    tokenVersion: fila.token_version,
  });
  return { token, refreshToken: rotado.nuevoRefreshToken };
}

export async function cerrarSesion(tokenCrudo: string): Promise<void> {
  await refreshTokenService.revocarRefreshToken(tokenCrudo);
}
