import { Router } from 'express';
import { z } from 'zod';
import { asyncHandler } from '../utils/asyncHandler';
import { ApiError } from '../utils/asyncHandler';
import { requireAuth, requireRole, type AuthRequest } from '../middleware/auth';
import { authLimiter } from '../middleware/rateLimit';
import * as authService from '../services/authService';
import * as choferesService from '../services/choferesService';

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

const idSchema = z.string().uuid('Identificador de chofer inválido.');
const motivoSchema = z.string().trim().min(5, 'El motivo debe tener al menos 5 caracteres.').max(500);

export const listarChoferesSchema = z.object({
  buscar: z.string().trim().max(100).optional(),
  estado: z.enum(['todos', 'activo', 'inactivo']).default('todos'),
  pagina: z.coerce.number().int().min(1).default(1),
  limite: z.coerce.number().int().min(1).max(100).default(25),
});

const estadoSchema = z.object({ activo: z.boolean(), motivo: motivoSchema }).strict();

usuariosRouter.patch(
  '/:id/estado',
  asyncHandler(async (req: AuthRequest, res) => {
    const { activo } = estadoSchema.parse(req.body);
    const id = idSchema.parse(req.params.id);
    // Un admin no puede desactivarse a sí mismo — evitaría que quede
    // alguien con permiso para revertirlo.
    if (req.usuarioActual!.sub === id) {
      throw new ApiError(400, 'No puedes cambiar el estado de tu propia cuenta.');
    }
    const actualizado = await choferesService.cambiarEstado(
      id, activo, req.body.motivo as string, req.usuarioActual!.sub,
    );
    res.json(actualizado);
  }),
);

// Misma regla que `passwordSchema` en `auth.routes.ts` (y
// `Validators.password` del frontend) — no reinventar el límite.
const passwordSchema = z.string().min(8, 'La contraseña debe tener al menos 8 caracteres.');

const resetearPasswordSchema = z.object({ motivo: motivoSchema }).strict();

usuariosRouter.post(
  '/:id/resetear-password',
  authLimiter,
  asyncHandler(async (req: AuthRequest, res) => {
    const { motivo } = resetearPasswordSchema.parse(req.body);
    await choferesService.solicitarReset(
      idSchema.parse(req.params.id), motivo, req.usuarioActual!.sub,
    );
    res.status(202).json({
      estado: 'pendiente_configuracion',
      mensaje: 'La solicitud quedó registrada. El envío seguro aún no está configurado; la contraseña no fue modificada.',
    });
  }),
);

const textoPersona = z.string().trim().min(2).max(100);
const editarChoferSchema = z.object({
  nombre: textoPersona.optional(),
  apellidoPaterno: textoPersona.optional(),
  apellidoMaterno: z.string().trim().max(100).nullable().optional(),
  correo: z.string().trim().email('Ingresa un correo válido.').max(150).optional(),
  usuario: z.string().trim().regex(/^[a-zA-Z0-9._]{3,30}$/, 'Usuario inválido.').optional(),
  version: z.string().regex(/^\d+$/, 'Versión inválida.'),
}).strict().refine((v) => Object.keys(v).some((k) => k !== 'version'), 'No hay cambios para guardar.');

usuariosRouter.get(
  '/choferes/:id',
  asyncHandler(async (req, res) => {
    res.json(await choferesService.obtener(idSchema.parse(req.params.id)));
  }),
);

usuariosRouter.patch(
  '/choferes/:id',
  asyncHandler(async (req: AuthRequest, res) => {
    const { version, ...cambios } = editarChoferSchema.parse(req.body);
    res.json(await choferesService.editar(idSchema.parse(req.params.id), cambios, version, req.usuarioActual!.sub));
  }),
);

usuariosRouter.post(
  '/choferes/:id/desactivar',
  asyncHandler(async (req: AuthRequest, res) => {
    const { motivo } = z.object({ motivo: motivoSchema }).strict().parse(req.body);
    res.json(await choferesService.cambiarEstado(idSchema.parse(req.params.id), false, motivo, req.usuarioActual!.sub));
  }),
);

usuariosRouter.post(
  '/choferes/:id/reactivar',
  asyncHandler(async (req: AuthRequest, res) => {
    const { motivo } = z.object({ motivo: motivoSchema }).strict().parse(req.body);
    res.json(await choferesService.cambiarEstado(idSchema.parse(req.params.id), true, motivo, req.usuarioActual!.sub));
  }),
);

usuariosRouter.get(
  '/choferes/:id/elegibilidad-eliminacion',
  requireRole('superadmin') as never,
  asyncHandler(async (req, res) => {
    res.json(await choferesService.elegibilidadEliminacion(idSchema.parse(req.params.id)));
  }),
);

usuariosRouter.delete(
  '/choferes/:id',
  requireRole('superadmin') as never,
  asyncHandler(async (req: AuthRequest, res) => {
    const id = idSchema.parse(req.params.id);
    if (id === req.usuarioActual!.sub) throw new ApiError(400, 'No puedes eliminar tu propia cuenta.');
    const datos = z.object({ usuarioConfirmado: z.string().trim(), motivo: motivoSchema }).strict().parse(req.body);
    await choferesService.eliminarDefinitivamente(id, datos.usuarioConfirmado, datos.motivo, req.usuarioActual!.sub);
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
