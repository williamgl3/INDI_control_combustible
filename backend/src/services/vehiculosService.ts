import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import { registrarAuditoria } from './auditoriaService';
import type { Vehiculo } from '../types';

interface FilaVehiculo {
  id: string;
  tipo_unidad: string;
  // Nullable desde la migración 0020 — maquinaria pesada no tiene.
  placas: string | null;
  // Nullable desde la migración 0020 — NULL en vehículo ligero puro.
  numero_economico: string | null;
  // Nullable desde la migración 0022 — sin confirmar con el cliente
  // (ej. maquinaria pesada recién importada).
  tipo_combustible: string | null;
  // NOT NULL desde la migración 0019.
  modelo: string;
  intervalo_servicio: string;
  lectura_ultimo_servicio: string | null;
  fecha_ultimo_servicio: Date | null;
  activo: boolean;
  // Nullable desde la migración 0025 — NULL en toda unidad "normal", solo
  // presente en accesorios/sub-unidades (ver `Vehiculo.unidadPadreId`).
  unidad_padre_id: string | null;
  // Nullable desde la migración 0028.
  ubicacion: string | null;
}

/// `numeroEconomico` si existe, si no `placas` — `chk_identificador` en
/// la base de datos garantiza que al menos uno de los dos esté presente,
/// así que este `!` es seguro (nunca ambos NULL a la vez).
function etiquetaUnidad(placas: string | null, numeroEconomico: string | null): string {
  return numeroEconomico ?? placas!;
}

function aVehiculo(fila: FilaVehiculo): Vehiculo {
  return {
    id: fila.id,
    tipoUnidad: fila.tipo_unidad,
    identificador: fila.placas ?? fila.numero_economico!,
    placas: fila.placas,
    numeroEconomico: fila.numero_economico,
    etiquetaUnidad: etiquetaUnidad(fila.placas, fila.numero_economico),
    tipoCombustible: fila.tipo_combustible,
    modelo: fila.modelo,
    intervaloServicio: Number(fila.intervalo_servicio),
    lecturaUltimoServicio:
      fila.lectura_ultimo_servicio === null ? null : Number(fila.lectura_ultimo_servicio),
    fechaUltimoServicio: fila.fecha_ultimo_servicio?.toISOString() ?? null,
    activo: fila.activo,
    unidadPadreId: fila.unidad_padre_id,
    ubicacion: fila.ubicacion,
  };
}

/// Mayúsculas + sin espacios al inicio/fin — misma forma que ya trae el
/// catálogo importado. Evita que 'pl-0762-c' y 'PL-0762-C' se traten
/// como identificadores distintos ante la constraint UNIQUE. Cadena
/// vacía o solo-espacios se normaliza a `null` — "no aplica", no un
/// valor real que pueda chocar con otra unidad vacía (ver `chk_placas_no_vacia`
/// y el índice único funcional en la migración 0020).
function normalizar(valor: string | null | undefined): string | null {
  const limpio = valor?.trim().toUpperCase() ?? '';
  return limpio === '' ? null : limpio;
}

/// Igual que `normalizar` pero sin forzar mayúsculas — para campos con
/// forma canónica propia (ej. "Diésel", no "DIÉSEL").
function normalizarTextoLibre(valor: string | null | undefined): string | null {
  const limpio = valor?.trim() ?? '';
  return limpio === '' ? null : limpio;
}

/// Cada tipo de unidad exige un subconjunto distinto de identificadores
/// físicos — ver migración 0021 y el inventario real de 96 unidades:
/// Vehículo (placa), Maquinaria (económico, no circula por carretera) o
/// Marimba (ambos, circula por carretera y además lleva económico
/// interno de GAMI). Se valida aquí, no solo en el formulario del panel
/// admin, para que ningún cliente de la API pueda saltarse la regla.
function validarIdentificadoresRequeridos(
  tipoUnidad: string,
  placas: string | null,
  numeroEconomico: string | null,
): void {
  if (tipoUnidad === 'Vehículo' && !placas) {
    throw new ApiError(400, 'Las placas son obligatorias para un vehículo ligero.');
  }
  if ((tipoUnidad === 'Maquinaria' || tipoUnidad === 'Equipo menor') && !numeroEconomico) {
    throw new ApiError(
      400,
      tipoUnidad === 'Maquinaria'
        ? 'El número económico es obligatorio para maquinaria pesada.'
        : 'El número económico es obligatorio para un equipo menor.',
    );
  }
  if (tipoUnidad === 'Marimba' && (!placas || !numeroEconomico)) {
    throw new ApiError(400, 'La marimba necesita placas y número económico, ambos.');
  }
  if (!placas && !numeroEconomico) {
    throw new ApiError(400, 'Indica placas o número económico (al menos uno).');
  }
}

/// Réplica de `intervaloServicioPorDefecto`/`esUnidadPorHorometro` en
/// `frontend/lib/core/catalogos_vehiculo.dart` — 250h para unidades por
/// horómetro (maquinaria, equipo menor), 5000km para el resto.
/// TODO-SPEC: valores PLACEHOLDER, igual que en el frontend.
function intervaloServicioPorDefecto(tipoUnidad: string): number {
  return tipoUnidad === 'Maquinaria' || tipoUnidad === 'Equipo menor' ? 250 : 5000;
}

export async function listarVehiculos(): Promise<Vehiculo[]> {
  const { rows } = await pool.query<FilaVehiculo>('SELECT * FROM vehiculos ORDER BY creado_en');
  return rows.map(aVehiculo);
}

export async function buscarVehiculoPorId(id: string): Promise<Vehiculo | null> {
  const { rows } = await pool.query<FilaVehiculo>('SELECT * FROM vehiculos WHERE id = $1', [id]);
  return rows[0] ? aVehiculo(rows[0]) : null;
}

/// Código de error de Postgres para violación de constraint UNIQUE.
const PG_UNIQUE_VIOLATION = '23505';

/// Distingue CUÁL de los dos índices únicos violó el insert/update
/// (`vehiculos_placas_normalizada_key` o
/// `vehiculos_numero_economico_normalizado_key`, migración 0020) para
/// devolver un mensaje específico — el usuario del panel admin necesita
/// saber si chocó la placa o el económico, no un "ya existe" genérico.
function nombreDeConstraintViolada(err: unknown): string | null {
  if (
    typeof err === 'object' &&
    err !== null &&
    'code' in err &&
    (err as { code?: string }).code === PG_UNIQUE_VIOLATION &&
    'constraint' in err
  ) {
    return (err as { constraint?: string }).constraint ?? null;
  }
  return null;
}

function errorDeIdentificadorDuplicado(
  err: unknown,
  placas: string | null,
  numeroEconomico: string | null,
): ApiError | null {
  const constraint = nombreDeConstraintViolada(err);
  if (constraint === 'vehiculos_placas_normalizada_key') {
    return new ApiError(409, `Ya existe una unidad con la placa "${placas}".`);
  }
  if (constraint === 'vehiculos_numero_economico_normalizado_key') {
    return new ApiError(409, `Ya existe una unidad con el número económico "${numeroEconomico}".`);
  }
  return null;
}

/// Un accesorio/sub-unidad no puede a su vez tener hijos propios (solo 2
/// niveles, ver migración 0025) — se valida aquí porque Postgres no puede
/// expresar "la fila referida no debe tener padre" como un CHECK simple.
async function validarUnidadPadre(unidadPadreId: string | null): Promise<void> {
  if (!unidadPadreId) return;
  const padre = await buscarVehiculoPorId(unidadPadreId);
  if (!padre) throw new ApiError(400, 'La unidad padre indicada no existe.');
  if (padre.unidadPadreId) {
    throw new ApiError(400, 'Esa unidad ya es un accesorio de otra — no puede tener sub-unidades propias.');
  }
}

export async function crearVehiculo(datos: {
  tipoUnidad: string;
  placas?: string | null | undefined;
  numeroEconomico?: string | null | undefined;
  tipoCombustible?: string | null | undefined;
  modelo?: string | null | undefined;
  intervaloServicio?: number | null | undefined;
  unidadPadreId?: string | null | undefined;
  ubicacion?: string | null | undefined;
}): Promise<Vehiculo> {
  const placas = normalizar(datos.placas);
  const numeroEconomico = normalizar(datos.numeroEconomico);
  validarIdentificadoresRequeridos(datos.tipoUnidad, placas, numeroEconomico);
  await validarUnidadPadre(datos.unidadPadreId ?? null);

  const intervalo = datos.intervaloServicio ?? intervaloServicioPorDefecto(datos.tipoUnidad);
  try {
    const { rows } = await pool.query<FilaVehiculo>(
      `INSERT INTO vehiculos
         (tipo_unidad, placas, numero_economico, tipo_combustible, modelo, intervalo_servicio, unidad_padre_id, ubicacion)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [
        datos.tipoUnidad,
        placas,
        numeroEconomico,
        normalizarTextoLibre(datos.tipoCombustible),
        datos.modelo ?? null,
        intervalo,
        datos.unidadPadreId ?? null,
        normalizarTextoLibre(datos.ubicacion),
      ],
    );
    return aVehiculo(rows[0]!);
  } catch (err) {
    throw errorDeIdentificadorDuplicado(err, placas, numeroEconomico) ?? err;
  }
}

/// Un chofer reporta sobre la marcha una unidad que no está en el
/// catálogo — el administrativo la formaliza después (modelo,
/// combustible si hace falta corregirlo, etc.).
export async function reportarVehiculoNuevo(datos: {
  tipoUnidad: string;
  placas?: string | null | undefined;
  numeroEconomico?: string | null | undefined;
  tipoCombustible: string;
  modelo: string;
}): Promise<Vehiculo> {
  return crearVehiculo(datos);
}

export async function actualizarVehiculo(
  id: string,
  cambios: {
    tipoUnidad?: string | undefined;
    placas?: string | null | undefined;
    numeroEconomico?: string | null | undefined;
    tipoCombustible?: string | null | undefined;
    modelo?: string | null | undefined;
    intervaloServicio?: number | undefined;
    unidadPadreId?: string | null | undefined;
    ubicacion?: string | null | undefined;
  },
  actorId?: string | null | undefined,
): Promise<Vehiculo> {
  const actual = await buscarVehiculoPorId(id);
  if (!actual) throw new ApiError(404, 'Vehículo no encontrado.');

  const tipoUnidad = cambios.tipoUnidad ?? actual.tipoUnidad;
  const placas = cambios.placas === undefined ? actual.placas : normalizar(cambios.placas);
  const numeroEconomico =
    cambios.numeroEconomico === undefined
      ? actual.numeroEconomico
      : normalizar(cambios.numeroEconomico);
  const unidadPadreId =
    cambios.unidadPadreId === undefined ? actual.unidadPadreId : cambios.unidadPadreId;
  validarIdentificadoresRequeridos(tipoUnidad, placas, numeroEconomico);
  if (unidadPadreId !== actual.unidadPadreId) {
    await validarUnidadPadre(unidadPadreId);
  }

  let rows: FilaVehiculo[];
  try {
    ({ rows } = await pool.query<FilaVehiculo>(
      `UPDATE vehiculos
       SET tipo_unidad = $1, placas = $2, numero_economico = $3, tipo_combustible = $4,
           modelo = $5, intervalo_servicio = $6, unidad_padre_id = $7, ubicacion = $8
       WHERE id = $9
       RETURNING *`,
      [
        tipoUnidad,
        placas,
        numeroEconomico,
        cambios.tipoCombustible === undefined
          ? actual.tipoCombustible
          : normalizarTextoLibre(cambios.tipoCombustible),
        cambios.modelo === undefined ? actual.modelo : cambios.modelo,
        cambios.intervaloServicio ?? actual.intervaloServicio,
        unidadPadreId,
        cambios.ubicacion === undefined
          ? actual.ubicacion
          : normalizarTextoLibre(cambios.ubicacion),
        id,
      ],
    ));
  } catch (err) {
    throw errorDeIdentificadorDuplicado(err, placas, numeroEconomico) ?? err;
  }
  const vehiculo = aVehiculo(rows[0]!);

  void registrarAuditoria({
    usuarioId: actorId,
    accion: 'editar_vehiculo',
    entidad: 'vehiculo',
    entidadId: id,
    detalle: { cambios },
  });

  return vehiculo;
}

/// Activa/desactiva un vehículo del catálogo (soft-delete). Un vehículo
/// desactivado deja de ofrecerse en `SelectorVehiculo` (chofer) pero
/// conserva su historial de solicitudes/cargas — nunca se borra la fila.
export async function actualizarEstadoVehiculo(
  id: string,
  activo: boolean,
  actorId?: string | null | undefined,
): Promise<Vehiculo> {
  const { rows } = await pool.query<FilaVehiculo>(
    `UPDATE vehiculos SET activo = $1 WHERE id = $2 RETURNING *`,
    [activo, id],
  );
  if (!rows[0]) throw new ApiError(404, 'Vehículo no encontrado.');
  const vehiculo = aVehiculo(rows[0]);

  void registrarAuditoria({
    usuarioId: actorId,
    accion: activo ? 'reactivar_vehiculo' : 'desactivar_vehiculo',
    entidad: 'vehiculo',
    entidadId: id,
    detalle: { activo },
  });

  return vehiculo;
}

export async function registrarServicio(
  id: string,
  lectura: number,
  fecha: Date,
  actorId?: string | null | undefined,
): Promise<Vehiculo> {
  const { rows } = await pool.query<FilaVehiculo>(
    `UPDATE vehiculos
     SET lectura_ultimo_servicio = $1, fecha_ultimo_servicio = $2
     WHERE id = $3
     RETURNING *`,
    [lectura, fecha, id],
  );
  if (!rows[0]) throw new ApiError(404, 'Vehículo no encontrado.');
  const vehiculo = aVehiculo(rows[0]);

  void registrarAuditoria({
    usuarioId: actorId,
    accion: 'registrar_servicio_mantenimiento',
    entidad: 'vehiculo',
    entidadId: id,
    detalle: { lectura, fecha: fecha.toISOString() },
  });

  return vehiculo;
}
