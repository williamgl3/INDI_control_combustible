/// Tipos compartidos — reflejan 1:1 los modelos Flutter del frontend
/// (`frontend/lib/models/`), con nombres de campo camelCase en la capa de
/// API (se traducen desde/hacia snake_case en la capa de DB).

// `superadmin` puede todo lo que un `administrativo` (ver los
// `requireRole('administrativo', 'superadmin')` en `src/routes/`), más
// crear/gestionar cuentas `administrativo` — ver `usuarios.routes.ts`.
// `supervisor` opera la marimba en campo: solicita/comprueba la carga a
// granel (mismo flujo que un chofer, ver `requireRole` en
// `solicitudes.routes.ts`/`cargas.routes.ts`) y registra despachos hacia
// maquinaria (`despachosMarimbaService`).
export type RolUsuario = 'chofer' | 'administrativo' | 'superadmin' | 'supervisor';

export interface Perfil {
  id: string;
  usuario: string;
  nombre: string;
  // Nullable en la columna (cuentas creadas antes de exigir estos campos
  // en `POST /usuarios/administrativos` pueden tener NULL aquí), pero
  // tanto `registro-chofer` como la creación de administrativos ya los
  // piden y validan como obligatorios de aquí en adelante.
  apellidoPaterno: string | null;
  apellidoMaterno: string | null;
  correo: string;
  fechaNacimiento: string | null;
  rol: RolUsuario;
}

export interface Vehiculo {
  id: string;
  tipoUnidad: string;
  /// @deprecated Campo plano heredado de cuando solo existía un
  /// identificador por unidad (`placas` si existe, si no
  /// `numeroEconomico`) — se retira cuando el formulario de alta/edición
  /// (panel admin) pase a mandar `placas`/`numeroEconomico` por
  /// separado. Para mostrar al usuario, usa `etiquetaUnidad` (prioriza
  /// al revés: económico primero), no este campo.
  identificador: string;
  /// Placa física — NULL en maquinaria pesada (no circula por
  /// carretera, se identifica solo por `numeroEconomico`).
  placas: string | null;
  /// Número económico interno (GAMI) — NULL en vehículo ligero puro.
  /// La marimba tiene AMBOS (circula por carretera y además lleva
  /// económico de control interno).
  numeroEconomico: string | null;
  /// Identificador único a mostrar al usuario: `numeroEconomico` si
  /// existe, si no `placas`. Toda unidad tiene al menos uno
  /// (`chk_identificador` en la base de datos lo garantiza).
  etiquetaUnidad: string;
  /// NULL cuando aún no se confirma con el cliente (ej. maquinaria
  /// pesada recién importada) — ver migración 0022.
  tipoCombustible: string | null;
  modelo: string | null;
  intervaloServicio: number;
  lecturaUltimoServicio: number | null;
  fechaUltimoServicio: string | null;
  activo: boolean;
  /// Unidad de la que esta fila es accesorio/sub-unidad (ej. el equipo
  /// menor de gasolina de una marimba) — NULL en toda unidad "normal".
  /// Ver migración 0025: se modela como otra fila de `vehiculos` en vez
  /// de agregar un segundo combustible/métrica a esta misma fila, para no
  /// romper el resto del código que asume "1 vehículo = 1 combustible +
  /// 1 métrica".
  unidadPadreId: string | null;
  /// Frente/banco donde opera hoy (ej. "BANCO EL HUIZACHITO") — filtra el
  /// catálogo de máquinas destino al capturar despachos de marimba por
  /// recorrido. Nullable — ver migración 0028.
  ubicacion: string | null;
}

export type EstadoSolicitud = 'pendiente' | 'aprobada' | 'rechazada';

export interface SolicitudAutorizacion {
  id: string;
  choferId: string;
  vehiculoId: string;
  litrosSolicitados: number;
  litrosAutorizados: number | null;
  /// NULL cuando el vehículo no tiene `tipoCombustible` confirmado — la
  /// solicitud se crea igual, pero nunca se auto-aprueba (ver migración
  /// 0029 y `solicitudesService.enviarSolicitud`).
  costoEstimado: number | null;
  esUrgente: boolean;
  motivoChofer: string | null;
  actividad: string;
  fechaProgramada: string;
  estado: EstadoSolicitud;
  aprobadaPor: string | null;
  folioAutorizacion: string | null;
  comentario: string | null;
  creadaEn: string;
  fotoTableroPath: string | null;
}

export interface Carga {
  id: string;
  choferId: string;
  vehiculoId: string;
  folioAutorizacion: string;
  /// Folios adicionales de la misma carga (ej. la carga a granel de la
  /// marimba, pagada con 8 folios de una sola visita) — vacío en el caso
  /// normal de 1 chofer / 1 folio. Ver migración `0015`.
  foliosAdicionales: string[];
  litrosCargados: number;
  kmAlCargar: number;
  gasolinera: string;
  fotoTicketPath: string | null;
  fotoTableroPath: string | null;
  litrosDetectadosOcr: number | null;
  pendienteDeSincronizar: boolean;
  creadaEn: string;
  /// Snapshot del precio de referencia (no el real pagado) al momento de
  /// registrar la carga — mismo patrón que `SolicitudAutorizacion.
  /// costoEstimado` y `DespachoMarimba.precioReferenciaUsado`. NULL si el
  /// vehículo no tenía `tipoCombustible` confirmado en ese momento. Ver
  /// migración 0029.
  precioReferenciaPorLitro: number | null;
  costoReferencia: number | null;
}

export interface CierreDia {
  id: string;
  choferId: string;
  cargaId: string;
  kmFinal: number;
  fotoTableroPath: string;
  registradaEn: string;
}

export type EstadoIncidencia = 'abierta' | 'resuelta';

export interface IncidenciaVehiculo {
  id: string;
  vehiculoId: string;
  choferId: string;
  descripcion: string;
  estado: EstadoIncidencia;
  resueltaPor: string | null;
  comentarioResolucion: string | null;
  creadaEn: string;
  resueltaEn: string | null;
  fotoPath: string | null;
}

export interface PrecioCombustible {
  tipoCombustible: string;
  precioPorLitro: number;
  actualizadoEn: string;
}

export type TipoEvidencia = 'ticket' | 'tablero' | 'comprobante';

export interface Evidencia {
  id: string;
  usuarioId: string;
  tipo: TipoEvidencia;
  fotoUrl: string;
  fotoUrls: string[];
  km: number | null;
  folioId: string | null;
  pendienteVincular: boolean;
  notas: string | null;
  creadoEn: string;
}

export interface Suministro {
  id: string;
  choferId: string;
  gasolinera: string;
  litros: number;
  fotoTicketPath: string | null;
  pipaId: string | null;
  pipaNombre: string | null;
  pipaModelo: string | null;
  pipaNumeroEconomico: string | null;
  creadoEn: string;
}

export type EstadoDespacho = 'activo' | 'inactivo';

export interface DespachoMarimba {
  id: string;
  marimbaId: string;
  vehiculoDestinoId: string | null;
  destinoTexto: string | null;
  operadorTexto: string;
  residenteTexto: string | null;
  // Nullable desde la migración 0027 — se hereda de
  // `RecorridoMarimba.frente` cuando `recorridoId` no es null.
  sitio: string | null;
  litrosSolicitados: number | null;
  litrosSuministrados: number;
  lecturaMedidor: number | null;
  precioReferenciaUsado: number | null;
  estado: EstadoDespacho;
  fotoEvidenciaPath: string | null;
  registradoPor: string;
  creadoEn: string;
  recorridoId: string | null;
}

export interface SaldoMarimba {
  marimbaId: string;
  saldoActual: number;
}

export type EstadoRecorridoMarimba = 'abierto' | 'cerrado';

export interface RecorridoMarimba {
  id: string;
  marimbaId: string;
  operadorId: string;
  frente: string;
  cargaId: string | null;
  litrosIniciales: number;
  kmInicio: number | null;
  kmCierre: number | null;
  horasEquipoMenorInicio: number | null;
  horasEquipoMenorCierre: number | null;
  estado: EstadoRecorridoMarimba;
  litrosDespachadosTotal: number | null;
  existenciaCalculada: number | null;
  diferenciaConciliacion: number | null;
  toleranciaUsada: number | null;
  requiereRevision: boolean;
  fotoCierrePath: string | null;
  iniciadoEn: string;
  cerradoEn: string | null;
}

/// Payload embebido en el JWT. `tokenVersion` habilita revocación: se
/// compara contra `usuarios.token_version` en `requireAuth` — si no
/// coincide, el token se rechaza aunque su firma/expiración sean válidas
/// (ver `src/middleware/auth.ts` y la migración `0002_add_token_version`).
export interface TokenPayload {
  sub: string;
  usuario: string;
  rol: RolUsuario;
  tokenVersion: number;
}
