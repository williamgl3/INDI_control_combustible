import bcrypt from 'bcrypt';
import { pool } from './pool';
import { logger } from '../utils/logger';

/// Crea la cuenta SuperAdmin inicial de un despliegue nuevo, directo en
/// BD, sin pasar por la app — hoy no hay ninguna pantalla que dé de alta
/// un `superadmin` (`POST /usuarios/administrativos` es exclusivo para
/// crear cuentas `administrativo`, y requiere ya estar logueado como
/// superadmin). Pensado para el primer arranque en un servidor nuevo
/// (ej. al desplegar para un cliente), donde todavía no existe ninguna
/// cuenta con la que entrar.
///
/// Uso (usuario y contraseña SIEMPRE por variable de entorno, nunca
/// hardcodeados en este archivo):
///
///   SUPERADMIN_USERNAME=admin SUPERADMIN_PASSWORD=cambia-esto npm run seed:superadmin
///
/// Variables opcionales (si no se dan, usan un valor por defecto —
/// `nombre`/`correo` son NOT NULL en la tabla pero no se usan para nada
/// crítico de un superadmin, solo se muestran en la UI):
///   SUPERADMIN_NOMBRE (default "Super Admin")
///   SUPERADMIN_CORREO (default "<usuario>@indicombustible.local")
///
/// Idempotente: si YA existe cualquier cuenta con rol `superadmin`, no
/// crea otra — seguro correrlo más de una vez por error. La contraseña
/// se hashea con el mismo método que el resto del sistema
/// (`bcrypt`, `SALT_ROUNDS = 12`, igual que `authService.ts`).
async function seedSuperadmin() {
  const usuario = process.env.SUPERADMIN_USERNAME;
  const password = process.env.SUPERADMIN_PASSWORD;

  if (!usuario || !password) {
    throw new Error(
      'Faltan variables de entorno. Uso: SUPERADMIN_USERNAME=... SUPERADMIN_PASSWORD=... npm run seed:superadmin',
    );
  }
  if (password.length < 8) {
    throw new Error('SUPERADMIN_PASSWORD debe tener al menos 8 caracteres.');
  }

  const nombre = process.env.SUPERADMIN_NOMBRE || 'Super Admin';
  const correo = process.env.SUPERADMIN_CORREO || `${usuario}@indicombustible.local`;

  const yaExiste = await pool.query<{ id: string }>(
    "SELECT id FROM usuarios WHERE rol = 'superadmin' LIMIT 1",
  );
  if (yaExiste.rows.length > 0) {
    logger.info('Ya existe una cuenta superadmin en esta base de datos — no se crea otra.');
    await pool.end();
    return;
  }

  const passwordHash = await bcrypt.hash(password, 12);
  const { rowCount } = await pool.query(
    `INSERT INTO usuarios (usuario, password_hash, nombre, correo, rol)
     VALUES ($1, $2, $3, $4, 'superadmin')
     ON CONFLICT (usuario) DO NOTHING`,
    [usuario, passwordHash, nombre, correo],
  );

  if (rowCount === 0) {
    // No había ningún superadmin, pero SÍ ya existía ese nombre de
    // usuario con otro rol — no se pisa una cuenta existente.
    throw new Error(
      `Ya existe una cuenta con el usuario "${usuario}" (de otro rol). Elige otro SUPERADMIN_USERNAME.`,
    );
  }

  logger.info({ usuario }, 'Cuenta superadmin creada correctamente.');
  await pool.end();
}

seedSuperadmin().catch(async (err) => {
  logger.error({ err }, 'Error creando la cuenta superadmin');
  await pool.end();
  process.exit(1);
});
