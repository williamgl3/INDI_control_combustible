import bcrypt from 'bcrypt';
import { pool } from './pool';
import { logger } from '../utils/logger';

/// Siembra los mismos usuarios de prueba que `MockAuthRepository` en el
/// frontend, para poder probar la app contra el backend real sin tener
/// que registrar todo a mano. Idempotente — no duplica si ya existen.
///
/// Ya NO siembra ningún vehículo de prueba — antes creaba un
/// "Chevrolet NPR 2020 / ABC-123" mock, pero el catálogo real de
/// unidades se importa aparte (ver `importarVehiculos.ts`). Sembrar un
/// vehículo falso junto al catálogo real solo mezclaría datos de
/// prueba con datos reales del cliente (exactamente el problema que ya
/// se limpió una vez en esta base de datos), sin aportar nada — un
/// chofer de prueba puede elegir cualquier unidad real del catálogo ya
/// importado.
async function seed() {
  const passwordChofer = await bcrypt.hash('chofer123', 12);
  const passwordAdmin = await bcrypt.hash('admin1234', 12);

  await pool.query(
    `INSERT INTO usuarios
       (usuario, password_hash, nombre, apellido_paterno, correo, fecha_nacimiento, rol)
     VALUES
       ('chofer1', $1, 'Juan', 'Pérez', 'chofer1@example.com', '1996-03-10', 'chofer'),
       ('admin1', $2, 'Ana', 'Torres', 'admin1@example.com', '1991-08-22', 'administrativo')
     ON CONFLICT (usuario) DO NOTHING`,
    [passwordChofer, passwordAdmin],
  );

  logger.info('Seed aplicado (chofer1/chofer123, admin1/admin1234).');
  await pool.end();
}

seed().catch((err) => {
  logger.error({ err }, 'Error en el seed');
  process.exit(1);
});
