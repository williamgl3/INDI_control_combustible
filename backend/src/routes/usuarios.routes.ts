import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { ApiError } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { authLimiter } from '../middleware/rateLimit';
import * as authService from '../services/authService';

/// Gestión de usuarios — todo requiere rol `administrativo`. Separado de
/// `auth.routes.ts` porque no es "sobre mi propia cuenta" sino sobre
/// cuentas de terceros (activar/desactivar, resetear password, dar de
/// alta administrativos nuevos).
export const usuariosRouter = Router();

usuariosRouter.use(requireAuth as never);
// Base: cualquier `administrativo` o `superadmin` puede gestionar
// choferes (estado, reseteo de password) — la creación de cuentas
// `administrativo` tiene una restricción MÁS estricta abajo
// (`requireRole('superadmin')` solo, en esa ruta puntual).
usuariosRouter.use(requireRole('administrativo', 'superadmin') as never);

const estadoSchema = z.object({
  activo: z.boolean(),
});

usuariosRouter.patch(
  '/:id/estado',
  asyncHandler(async (req: AuthRequest, res) => {
    const { activo } = estadoSchema.parse(req.body);
    const id = req.params.id as string;
    // Un admin no puede desactivarse a sí mismo — evitaría que quede
    // alguien con permiso para revertirlo.
    if (req.usuarioActual!.sub === id) {
      throw new ApiError(400, 'No puedes cambiar el estado de tu propia cuenta.');
    }
    await authService.actualizarEstadoUsuario(
      id,
      activo,
      req.usuarioActual!.sub,
      req.usuarioActual!.rol,
    );
    res.status(204).send();
  }),
);

// Misma regla que `passwordSchema` en `auth.routes.ts` (y
// `Validators.password` del frontend) — no reinventar el límite.
const passwordSchema = z.string().min(8, 'La contraseña debe tener al menos 8 caracteres.');

const resetearPasswordSchema = z.object({
  passwordNueva: passwordSchema,
});

usuariosRouter.post(
  '/:id/resetear-password',
  authLimiter,
  asyncHandler(async (req: AuthRequest, res) => {
    const { passwordNueva } = resetearPasswordSchema.parse(req.body);
    await authService.resetearPassword(
      req.params.id as string,
      passwordNueva,
      req.usuarioActual!.sub,
    );
    res.status(204).send();
  }),
);

const usuarioSchema = z
  .string()
  .trim()
  .regex(/^[a-zA-Z0-9._]{3,30}$/, 'El usuario debe tener 3-30 caracteres: letras, números, "." o "_".');

// Mismo criterio que `registroChoferSchema` en `auth.routes.ts` —
// apellidos obligatorios, sin dígitos.
const apellidoRegex = /^[a-zA-ZÀ-ÿñÑ\s]+$/;

const crearAdministrativoSchema = z.object({
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
  correo: z.string().trim().email('Ingresa un correo válido.'),
  usuario: usuarioSchema,
  password: passwordSchema,
});

// SOLO `superadmin` — un `administrativo` normal no puede dar de alta
// otras cuentas `administrativo` (ver jerarquía de roles). El middleware
// de arriba (`requireRole('administrativo', 'superadmin')`) ya dejó pasar
// a ambos; este segundo `requireRole` en la ruta puntual vuelve a
// filtrar, quedándose solo con `superadmin`. Nunca confiar solo en que el
// frontend oculte el botón — esto es lo que de verdad lo bloquea.
usuariosRouter.post(
  '/administrativos',
  requireRole('superadmin') as never,
  authLimiter,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = crearAdministrativoSchema.parse(req.body);
    const perfil = await authService.crearAdministrativo(datos, req.usuarioActual!.sub);
    res.status(201).json(perfil);
  }),
);

// Mismos requisitos que un administrativo (sin fecha de nacimiento) —
// cualquier `administrativo`/`superadmin` puede darlo de alta, a
// diferencia de `/administrativos` que es exclusivo de `superadmin`.
usuariosRouter.post(
  '/supervisores',
  authLimiter,
  asyncHandler(async (req: AuthRequest, res) => {
    const datos = crearAdministrativoSchema.parse(req.body);
    const perfil = await authService.crearSupervisor(datos, req.usuarioActual!.sub);
    res.status(201).json(perfil);
  }),
);
