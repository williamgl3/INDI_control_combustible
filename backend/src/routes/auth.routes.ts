import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { authLimiter, authRefreshLimiter, authStrictLimiter } from '../middleware/rateLimit';
import * as authService from '../services/authService';
import * as choferesService from '../services/choferesService';

export const authRouter = Router();

// Mismas reglas que `frontend/lib/core/validators.dart` (Validators) —
// no reinventar los límites, solo replicarlos.
const usuarioSchema = z
  .string()
  .trim()
  .regex(/^[a-zA-Z0-9._]{3,30}$/, 'El usuario debe tener 3-30 caracteres: letras, números, "." o "_".');

const passwordSchema = z.string().min(8, 'La contraseña debe tener al menos 8 caracteres.');

const loginSchema = z.object({
  usuario: z.string().trim().min(1, 'El usuario es obligatorio.'),
  password: z.string().min(1, 'La contraseña es obligatoria.'),
});

authRouter.post(
  '/login',
  authStrictLimiter,
  asyncHandler(async (req, res) => {
    const { usuario, password } = loginSchema.parse(req.body);
    const resultado = await authService.login(usuario, password);
    res.json(resultado);
  }),
);

// Misma regla que `Validators.edadMin`/`edadMax` en el frontend (18-75
// años), pero calculada desde la fecha de nacimiento en vez de un número
// que el usuario escriba directamente.
const EDAD_MIN = 18;
const EDAD_MAX = 75;

function edadDesde(fechaNacimiento: string): number {
  const nacimiento = new Date(fechaNacimiento);
  const hoy = new Date();
  let edad = hoy.getFullYear() - nacimiento.getFullYear();
  const aunNoCumple =
    hoy.getMonth() < nacimiento.getMonth() ||
    (hoy.getMonth() === nacimiento.getMonth() && hoy.getDate() < nacimiento.getDate());
  if (aunNoCumple) edad--;
  return edad;
}

// Mismo criterio que `Validators.apellido` del frontend: obligatorio, sin
// dígitos.
const apellidoRegex = /^[a-zA-ZÀ-ÿñÑ\s]+$/;

const registroChoferSchema = z.object({
  nombre: z.string().trim().min(2, 'El nombre debe tener al menos 2 caracteres.'),
  apellidoPaterno: z
    .string()
    .trim()
    .min(2, 'El apellido paterno debe tener al menos 2 caracteres.')
    .regex(apellidoRegex, 'El apellido paterno no debe contener números.'),
  apellidoMaterno: z
    .string()
    .trim()
    .min(2, 'El apellido materno debe tener al menos 2 caracteres.')
    .regex(apellidoRegex, 'El apellido materno no debe contener números.'),
  // Autoreportada por el chofer al registrarse, sin verificación real
  // detrás — se quitó como requisito (daba una falsa sensación de
  // cumplimiento de edad mínima sin cumplir nada de verdad). Si de
  // verdad se necesita, debe capturarla un administrativo con la
  // identificación ya verificada por RH, no el propio registro.
  fechaNacimiento: z
    .string()
    .refine((v) => !Number.isNaN(new Date(v).getTime()), 'Ingresa una fecha de nacimiento válida.')
    .refine(
      (v) => edadDesde(v) >= EDAD_MIN && edadDesde(v) <= EDAD_MAX,
      `La edad debe estar entre ${EDAD_MIN} y ${EDAD_MAX} años.`,
    )
    .nullish(),
  correo: z.string().trim().email('Ingresa un correo válido.'),
  usuario: usuarioSchema,
  password: passwordSchema,
});

authRouter.post(
  '/registro-chofer',
  authLimiter,
  asyncHandler(async (req, res) => {
    const datos = registroChoferSchema.parse(req.body);
    const resultado = await authService.registrarChofer(datos);
    res.status(201).json(resultado);
  }),
);

const recuperarPasswordSchema = z.object({
  usuarioOCorreo: z.string().trim().min(1, 'Este campo es obligatorio.'),
});

authRouter.post(
  '/recuperar-password',
  authStrictLimiter,
  asyncHandler(async (req, res) => {
    const { usuarioOCorreo } = recuperarPasswordSchema.parse(req.body);
    await authService.recuperarPassword(usuarioOCorreo);
    // Respuesta genérica siempre igual, exista o no la cuenta — ver
    // `authService.recuperarPassword` (TODO-SECURITY resuelto: sin
    // enumeración de usuarios/correos).
    res.status(200).json({
      mensaje: 'Si la cuenta existe, se enviaron instrucciones para recuperar tu contraseña.',
    });
  }),
);

/// Lista de choferes registrados — panel administrativo (`ChoferesTab`,
/// `AutorizacionesTab`, `ConcentradoTab`).
authRouter.get(
  '/choferes',
  requireAuth as never,
  requireRole('administrativo', 'superadmin') as never,
  asyncHandler(async (req, res) => {
    const opciones = z.object({
      buscar: z.string().trim().max(100).optional(),
      estado: z.enum(['todos', 'activo', 'inactivo']).default('todos'),
      pagina: z.coerce.number().int().min(1).default(1),
      limite: z.coerce.number().int().min(1).max(100).default(25),
    }).parse(req.query);
    res.json(await choferesService.listar(opciones));
  }),
);

const cambiarPasswordSchema = z.object({
  passwordActual: z.string().min(1, 'Ingresa tu contraseña actual.'),
  passwordNueva: passwordSchema,
});

/// Cambiar contraseña estando ya logueado — distinto de
/// /recuperar-password (para cuando el usuario la olvidó). Usada por
/// "Mi perfil" en el frontend.
authRouter.post(
  '/cambiar-password',
  authLimiter,
  requireAuth as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const { passwordActual, passwordNueva } = cambiarPasswordSchema.parse(req.body);
    await authService.cambiarPassword(req.usuarioActual!.sub, passwordActual, passwordNueva);
    res.status(204).send();
  }),
);

const refreshTokenSchema = z.object({
  refreshToken: z.string().trim().min(1, 'Falta el refresh token.'),
});

/// Renueva el access token (de vida corta, ver `ACCESS_TOKEN_EXPIRES_IN`)
/// sin volver a pedir credenciales — público (sin `requireAuth`, el
/// propio refresh token es la credencial), pero rate-limitado igual que
/// el resto de auth. Rota el refresh token en cada uso (ver
/// `refreshTokenService.rotarRefreshToken`): la respuesta trae uno nuevo,
/// el usado queda revocado.
authRouter.post(
  '/refresh',
  authRefreshLimiter,
  asyncHandler(async (req, res) => {
    const { refreshToken } = refreshTokenSchema.parse(req.body);
    const resultado = await authService.refrescarToken(refreshToken);
    res.json(resultado);
  }),
);

/// Cierra la sesión actual — revoca SOLO el refresh token indicado (no
/// todas las sesiones del usuario; para eso ver `cambiarPassword`/
/// `resetearPassword`/`actualizarEstadoUsuario`, que revocan todos).
authRouter.post(
  '/logout',
  requireAuth as never,
  asyncHandler(async (req, res) => {
    const { refreshToken } = refreshTokenSchema.parse(req.body);
    await authService.cerrarSesion(refreshToken);
    res.status(204).send();
  }),
);
