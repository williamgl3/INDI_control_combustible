import Decimal from 'decimal.js';
import { pool } from '../db/pool';
import { ApiError } from '../utils/asyncHandler';
import { estaEnSemanaDe, finDeSemana, inicioDeSemana } from '../utils/semana';
import { precioDeDecimal, presupuestoSemanalTotalDecimal } from './preciosService';
import { buscarVehiculoPorId } from './vehiculosService';
import { registrarAuditoria } from './auditoriaService';
import type {
  EstadoSolicitud,
  RolUsuario,
  SolicitudAutorizacion,
  Vehiculo,
} from '../types';

/// Réplica EXACTA de las reglas de negocio de
/// `frontend/lib/data/mock_operaciones_repository.dart`
/// (`MockOperacionesRepository`) — no reinventar, solo traducir a SQL.
const HISTORIAL_MINIMO = 4;
const MARGEN_PATRON = 1.15;

interface FilaSolicitud {
  id: string;
  chofer_id: string;
  vehiculo_id: string;
  litros_solicitados: string;
  litros_autorizados: string | null;
  // Nullable desde la migración 0029 — ver comentario en `enviarSolicitud`.
  costo_estimado: string | null;
  es_urgente: boolean;
  motivo_chofer: string | null;
  actividad: string;
  fecha_programada: Date;
  estado: EstadoSolicitud;
  aprobada_por: string | null;
  folio_autorizacion: string | null;
  comentario: string | null;
  creada_en: Date;
  foto_tablero_path: string | null;
  partidas_json?: SolicitudAutorizacion['partidas'];
}

function aSolicitud(fila: FilaSolicitud): SolicitudAutorizacion {
  const solicitud: SolicitudAutorizacion = {
    id: fila.id,
    choferId: fila.chofer_id,
    vehiculoId: fila.vehiculo_id,
    litrosSolicitados: Number(fila.litros_solicitados),
    litrosAutorizados: fila.litros_autorizados === null ? null : Number(fila.litros_autorizados),
    costoEstimado: fila.costo_estimado === null ? null : Number(fila.costo_estimado),
    esUrgente: fila.es_urgente,
    motivoChofer: fila.motivo_chofer,
    actividad: fila.actividad,
    fechaProgramada: fila.fecha_programada.toISOString(),
    estado: fila.estado,
    aprobadaPor: fila.aprobada_por,
    folioAutorizacion: fila.folio_autorizacion,
    comentario: fila.comentario,
    creadaEn: fila.creada_en.toISOString(),
    fotoTableroPath: fila.foto_tablero_path,
  };
  if (fila.partidas_json?.length) solicitud.partidas = fila.partidas_json;
  return solicitud;
}

const seleccionarSolicitudes = `SELECT s.*,
  COALESCE((SELECT json_agg(json_build_object(
    'id',sp.id,'solicitudId',sp.solicitud_id,'tipo',sp.tipo,
    'litrosSolicitados',sp.litros_solicitados,'litrosAutorizados',sp.litros_autorizados,
    'litrosCargados',COALESCE((SELECT SUM(cp.litros_cargados) FROM carga_partidas cp
      WHERE cp.solicitud_partida_id=sp.id),0),
    'tipoCombustible',sp.tipo_combustible,'estado',sp.estado,'observaciones',sp.observaciones)
    ORDER BY sp.tipo) FROM solicitud_partidas sp WHERE sp.solicitud_id=s.id),'[]'::json) partidas_json
  FROM solicitudes_autorizacion s`;

/// Filtros opcionales para el panel administrativo (Autorizaciones/
/// Concentrado) — todos por defecto `undefined`, así que sin argumentos
/// el comportamiento es idéntico al de antes (trae todo, sin límite);
/// el frontend hoy sigue sin usarlos, pero ya queda listo para no traer
/// el histórico completo en cada carga de pantalla cuando se conecte
/// (mismo patrón de cursor que `auditoriaService.listarAuditoria`).
export async function listarTodasLasSolicitudes(opciones?: {
  estado?: EstadoSolicitud | undefined;
  desde?: string | undefined;
  hasta?: string | undefined;
  limit?: number | undefined;
  before?: string | undefined;
}): Promise<SolicitudAutorizacion[]> {
  const condiciones: string[] = [];
  const params: unknown[] = [];

  if (opciones?.estado) {
    params.push(opciones.estado);
    condiciones.push(`estado = $${params.length}`);
  }
  if (opciones?.desde) {
    params.push(opciones.desde);
    condiciones.push(`creada_en >= $${params.length}`);
  }
  if (opciones?.hasta) {
    params.push(opciones.hasta);
    condiciones.push(`creada_en <= $${params.length}`);
  }
  if (opciones?.before) {
    params.push(opciones.before);
    condiciones.push(`creada_en < $${params.length}`);
  }

  const where = condiciones.length > 0 ? `WHERE ${condiciones.join(' AND ')}` : '';
  let limitSql = '';
  if (opciones?.limit) {
    params.push(opciones.limit);
    limitSql = `LIMIT $${params.length}`;
  }

  const { rows } = await pool.query<FilaSolicitud>(
    `${seleccionarSolicitudes} ${where} ORDER BY s.creada_en DESC ${limitSql}`,
    params,
  );
  return rows.map(aSolicitud);
}

export async function listarSolicitudesDeChofer(choferId: string): Promise<SolicitudAutorizacion[]> {
  const { rows } = await pool.query<FilaSolicitud>(
    `${seleccionarSolicitudes} WHERE s.chofer_id = $1 ORDER BY s.creada_en DESC`,
    [choferId],
  );
  return rows.map(aSolicitud);
}

export async function buscarSolicitudPorFolio(folio: string): Promise<SolicitudAutorizacion | null> {
  const { rows } = await pool.query<FilaSolicitud>(
    'SELECT * FROM solicitudes_autorizacion WHERE folio_autorizacion = $1',
    [folio],
  );
  return rows[0] ? aSolicitud(rows[0]) : null;
}

export async function buscarSolicitudPorId(id: string): Promise<SolicitudAutorizacion | null> {
  const { rows } = await pool.query<FilaSolicitud>(
    'SELECT * FROM solicitudes_autorizacion WHERE id = $1',
    [id],
  );
  return rows[0] ? aSolicitud(rows[0]) : null;
}

async function solicitudesAprobadasDeVehiculo(vehiculoId: string): Promise<FilaSolicitud[]> {
  const { rows } = await pool.query<FilaSolicitud>(
    "SELECT * FROM solicitudes_autorizacion WHERE vehiculo_id = $1 AND estado = 'aprobada'",
    [vehiculoId],
  );
  return rows;
}

async function tieneHistorialSuficiente(vehiculoId: string): Promise<boolean> {
  const historial = await solicitudesAprobadasDeVehiculo(vehiculoId);
  return historial.length >= HISTORIAL_MINIMO;
}

async function consumoHabitualDe(vehiculoId: string): Promise<number> {
  const historial = await solicitudesAprobadasDeVehiculo(vehiculoId);
  if (historial.length === 0) return 0;
  return Math.max(
    ...historial.map((s) => Number(s.litros_autorizados ?? s.litros_solicitados)),
  );
}

async function seSaleDePatron(vehiculoId: string, litrosPedidos: number): Promise<boolean> {
  if (!(await tieneHistorialSuficiente(vehiculoId))) return true;
  return litrosPedidos > (await consumoHabitualDe(vehiculoId)) * MARGEN_PATRON;
}

/// Litros ya autorizados (solicitudes aprobadas) de un VEHÍCULO en la
/// semana actual (lunes-domingo) — no del chofer, varios pueden
/// compartirlo.
export async function litrosAutorizadosAcumulados(vehiculoId: string): Promise<number> {
  const historial = await solicitudesAprobadasDeVehiculo(vehiculoId);
  const ahora = new Date();
  // Suma con `Decimal` en vez de `+` sobre `Number(...)` — sumar varios
  // NUMERIC convertidos a float de JS acumula error (ej. 10.10 + 20.20 +
  // 0.70 = 30.999999999999996, no 31.00; ver auditoría de precisión).
  const total = historial
    .filter((s) => estaEnSemanaDe(s.creada_en, ahora))
    .reduce(
      (suma, s) => suma.plus(new Decimal(s.litros_autorizados ?? s.litros_solicitados)),
      new Decimal(0),
    );
  return total.toNumber();
}

/// Se llama en cada carga del dashboard/Finanzas (`GET
/// /solicitudes/resumen-presupuesto`) — antes traía TODO el histórico de
/// solicitudes aprobadas a memoria y filtraba la semana actual en JS; con
/// meses de operación esa tabla crece sin límite y este era el endpoint
/// que más rápido se degradaría. Ahora el filtro de semana va en el
/// `WHERE`, con el mismo límite lunes-domingo que `estaEnSemanaDe`.
export async function presupuestoEjercido(): Promise<number> {
  const ahora = new Date();
  const { rows } = await pool.query<{ total: string | null }>(
    `SELECT COALESCE(SUM(costo_estimado), 0) AS total
     FROM solicitudes_autorizacion
     WHERE estado = 'aprobada' AND creada_en >= $1 AND creada_en < $2`,
    [inicioDeSemana(ahora), finDeSemana(ahora)],
  );
  return Number(rows[0]!.total);
}

export async function presupuestoRestante(): Promise<number> {
  const total = await presupuestoSemanalTotalDecimal();
  const ejercido = await presupuestoEjercido();
  return total.minus(ejercido).toNumber();
}

async function siguienteFolio(): Promise<string> {
  const { rows } = await pool.query<{ nextval: string }>(
    "SELECT nextval('folio_autorizacion_seq')",
  );
  return `FA-${rows[0]!.nextval}`;
}

export async function enviarSolicitud(datos: {
  choferId: string;
  rol: RolUsuario;
  vehiculoId: string;
  litrosSolicitados: number;
  esUrgente: boolean;
  motivoChofer?: string | null | undefined;
  actividad: string;
  fechaProgramada: string;
  fotoTableroPath?: string | null | undefined;
}): Promise<SolicitudAutorizacion> {
  const vehiculo = await validarUnidadParaSolicitud(datos.vehiculoId, datos.rol);

  // Bifurcación (ver migración 0029): "sin tipoCombustible confirmado"
  // (A) y "tipoCombustible definido pero sin precio vigente" (B) son dos
  // situaciones distintas que antes colapsaban en el mismo bloqueo.
  //   (A) 55 de 96 unidades del catálogo real (maquinaria/pipa) no
  //       tienen combustible confirmado — es un dato pendiente de
  //       captura del admin, NO un error del chofer. Antes esto
  //       bloqueaba la solicitud entera; ahora se crea con
  //       `costoEstimado = null` y nunca se auto-aprueba (va a revisión
  //       manual, donde el admin puede completar el dato o aprobar a
  //       ojo) — mucho mejor que dejar a más de la mitad de la flota sin
  //       poder pedir combustible.
  //   (B) El tipo SÍ está confirmado (ej. "Premium") pero nadie ha
  //       registrado un precio vigente para él — aquí sí es una
  //       configuración faltante que alguien debe capturar antes de
  //       continuar, así que `precioDeDecimal` lanza 409 y se propaga.
  //
  // `Decimal` de punta a punta hasta el redondeo final — antes
  // `litros * precio` con floats de JS podía dar algo como
  // `301.34999999999997` en vez de `301.35`, y la comparación de abajo
  // ocurría sobre ese valor imperfecto ANTES de que tocara la columna
  // `NUMERIC` que lo habría corregido (ver auditoría de precisión).
  let costoEstimadoDecimal: Decimal | null = null;
  if (vehiculo.tipoCombustible) {
    const precio = await precioDeDecimal(vehiculo.tipoCombustible, new Date());
    costoEstimadoDecimal = new Decimal(datos.litrosSolicitados).times(precio).toDecimalPlaces(2);
  }
  const costoEstimado = costoEstimadoDecimal?.toNumber() ?? null;
  const tieneHistorial = await tieneHistorialSuficiente(vehiculo.id);
  const salePatron = await seSaleDePatron(vehiculo.id, datos.litrosSolicitados);
  // Sin costo estimado no se puede verificar presupuesto — nunca
  // autoaprueba a ciegas, fuerza revisión manual (caso A de arriba).
  const presupuestoOk =
    costoEstimadoDecimal !== null &&
    costoEstimadoDecimal.lessThanOrEqualTo(await presupuestoRestante());

  const seAutoAprueba = tieneHistorial && !salePatron && presupuestoOk;

  let comentario: string | null = null;
  if (!seAutoAprueba) {
    if (!vehiculo.tipoCombustible) {
      comentario =
        'Esta unidad no tiene combustible confirmado en el catálogo — un administrativo revisará y completará el dato.';
    } else if (!tieneHistorial) {
      comentario =
        'Este vehículo aún no tiene historial suficiente — un administrativo revisará esta solicitud.';
    } else if (salePatron) {
      comentario =
        'Se pidió más de lo habitual para este vehículo — un administrativo revisará esta solicitud.';
    } else {
      comentario = 'Se excede el presupuesto semanal disponible — un administrativo revisará esta solicitud.';
    }
  }

  const folio = seAutoAprueba ? await siguienteFolio() : null;

  const { rows } = await pool.query<FilaSolicitud>(
    `INSERT INTO solicitudes_autorizacion
       (chofer_id, vehiculo_id, litros_solicitados, litros_autorizados, costo_estimado,
        es_urgente, motivo_chofer, actividad, fecha_programada, estado, aprobada_por,
        folio_autorizacion, comentario, foto_tablero_path)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
     RETURNING *`,
    [
      datos.choferId,
      vehiculo.id,
      datos.litrosSolicitados,
      seAutoAprueba ? datos.litrosSolicitados : null,
      costoEstimado,
      datos.esUrgente,
      datos.motivoChofer ?? null,
      datos.actividad,
      datos.fechaProgramada,
      seAutoAprueba ? 'aprobada' : 'pendiente',
      seAutoAprueba ? 'Automático (historial)' : null,
      folio,
      comentario,
      datos.fotoTableroPath ?? null,
    ],
  );
  return aSolicitud(rows[0]!);
}

export async function validarUnidadParaSolicitud(
  vehiculoId: string,
  rol: RolUsuario,
): Promise<Vehiculo> {
  const vehiculo = await buscarVehiculoPorId(vehiculoId);
  if (!vehiculo) throw new ApiError(404, 'Unidad no encontrada.');
  if (!vehiculo.activo) {
    throw new ApiError(409, 'La unidad no está disponible para operar.');
  }

  const permitida =
    vehiculo.tipoUnidad === 'Vehículo' ||
    vehiculo.tipoUnidad === 'Maquinaria' ||
    (rol === 'supervisor' &&
      (vehiculo.tipoUnidad === 'Marimba' || vehiculo.tipoUnidad === 'Pipa'));
  if (!permitida) {
    throw new ApiError(403, 'La categoría de unidad no está permitida para este rol.');
  }
  return vehiculo;
}

export async function resolverSolicitud(
  solicitudId: string,
  datos: {
    aprobar: boolean;
    resueltaPor: string;
    resueltaPorId?: string | null | undefined;
    litrosAutorizados?: number | null | undefined;
    motivo?: string | null | undefined;
  },
): Promise<SolicitudAutorizacion> {
  const { rows: existentes } = await pool.query<FilaSolicitud>(
    'SELECT * FROM solicitudes_autorizacion WHERE id = $1',
    [solicitudId],
  );
  const original = existentes[0];
  if (!original) throw new ApiError(404, 'Solicitud no encontrada.');

  const folio = datos.aprobar ? await siguienteFolio() : null;
  const litrosAutorizados = datos.aprobar
    ? (datos.litrosAutorizados ?? Number(original.litros_solicitados))
    : 0;

  // Misma validación que `RevisarSolicitudDialog` en el frontend — se
  // repite aquí porque nunca hay que confiar solo en la validación del
  // cliente, sobre todo en un flujo antifraude como este.
  const motivoVacio = !datos.motivo || datos.motivo.trim().length === 0;
  const autorizaMenos = datos.aprobar && litrosAutorizados < Number(original.litros_solicitados);
  if (!datos.aprobar && motivoVacio) {
    throw new ApiError(400, 'Explica por qué se rechaza.');
  }
  if (datos.aprobar && autorizaMenos && motivoVacio) {
    throw new ApiError(400, 'Autorizaste menos de lo pedido — explica por qué.');
  }

  const { rows } = await pool.query<FilaSolicitud>(
    `UPDATE solicitudes_autorizacion
     SET estado = $1, litros_autorizados = $2, aprobada_por = $3,
         folio_autorizacion = $4, comentario = $5
     WHERE id = $6
     RETURNING *`,
    [
      datos.aprobar ? 'aprobada' : 'rechazada',
      litrosAutorizados,
      datos.resueltaPor,
      folio,
      datos.motivo ?? null,
      solicitudId,
    ],
  );
  const solicitud = aSolicitud(rows[0]!);

  // Fire-and-forget: no bloquea ni puede tirar la resolución de la
  // solicitud si el insert de auditoría falla (ver `auditoriaService`).
  void registrarAuditoria({
    usuarioId: datos.resueltaPorId,
    accion: datos.aprobar ? 'aprobar_solicitud' : 'rechazar_solicitud',
    entidad: 'solicitud_autorizacion',
    entidadId: solicitudId,
    detalle: { litrosAutorizados, motivo: datos.motivo ?? null, folio },
  });

  return solicitud;
}

/// El propio chofer cancela una solicitud SUYA que sigue pendiente — se
/// reutiliza el estado 'rechazada' (no hay un estado 'cancelada' aparte)
/// con un comentario fijo que la distingue de un rechazo del admin, para
/// no ampliar el enum `estado_solicitud` por un caso que en la práctica
/// se comporta igual (ya no cuenta contra el presupuesto ni aparece como
/// pendiente).
export async function cancelarSolicitud(
  solicitudId: string,
  choferId: string,
): Promise<SolicitudAutorizacion> {
  const { rows: existentes } = await pool.query<FilaSolicitud>(
    'SELECT * FROM solicitudes_autorizacion WHERE id = $1',
    [solicitudId],
  );
  const original = existentes[0];
  if (!original) throw new ApiError(404, 'Solicitud no encontrada.');
  if (original.chofer_id !== choferId) {
    throw new ApiError(403, 'No puedes cancelar la solicitud de otro chofer.');
  }
  if (original.estado !== 'pendiente') {
    throw new ApiError(400, 'Solo se puede cancelar una solicitud que sigue pendiente.');
  }

  const { rows } = await pool.query<FilaSolicitud>(
    `UPDATE solicitudes_autorizacion
     SET estado = 'rechazada', comentario = $1
     WHERE id = $2
     RETURNING *`,
    ['Cancelada por el chofer.', solicitudId],
  );
  const solicitud = aSolicitud(rows[0]!);

  void registrarAuditoria({
    usuarioId: choferId,
    accion: 'cancelar_solicitud',
    entidad: 'solicitud_autorizacion',
    entidadId: solicitudId,
  });

  return solicitud;
}
