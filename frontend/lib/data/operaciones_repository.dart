import '../models/carga.dart';
import '../models/cierre_dia.dart';
import '../models/perfil.dart';
import '../models/precio_combustible.dart';
import '../models/solicitud_autorizacion.dart';
import '../models/vehiculo.dart';

class ComprobanteEstacionCarga {
  const ComprobanteEstacionCarga({
    required this.folioEstacion,
    required this.concepto,
    this.litrosIndicados,
  });

  final String folioEstacion;
  final String concepto;
  final double? litrosIndicados;

  Map<String, dynamic> toJson() => {
    'folioEstacion': folioEstacion,
    'concepto': concepto,
    'litrosIndicados': litrosIndicados,
  };
}

/// Interfaz común de operaciones (solicitudes, cargas, cierres, precios) —
/// implementada por [MockOperacionesRepository] (datos en memoria) y por
/// la implementación real que habla con el backend.
abstract class OperacionesRepository {
  double get presupuestoSemanalTotal;
  String get etiquetaSemanaActual;
  List<PrecioCombustible> get precios;
  double get presupuestoEjercido;
  double get presupuestoRestante;
  List<SolicitudAutorizacion> get todasLasSolicitudes;
  List<Carga> get todasLasCargas;

  /// Trae/actualiza todo lo que necesita esta sesión desde el backend:
  /// para un chofer, sus propias solicitudes/cargas/cierres; para un
  /// administrativo, el listado completo. Se llama tras iniciar sesión
  /// (ver `AuthController._cargarDatosIniciales`).
  Future<void> cargarDatosIniciales({required Perfil perfil});

  List<SolicitudAutorizacion> solicitudesDeChofer(String choferId);
  List<Carga> cargasDeChofer(String choferId);
  List<CierreDia> cierresDeChofer(String choferId);

  /// Litros ya autorizados de [vehiculoId] en la semana actual — ver
  /// [cargarAcumuladoDeVehiculo]; `0` si todavía no se ha cargado.
  double litrosAutorizadosAcumulados(String vehiculoId);

  /// Trae del backend el acumulado semanal de litros de un vehículo
  /// específico (no se puede derivar en el cliente: un chofer solo ve
  /// sus propias solicitudes, y el tope es del vehículo, compartido
  /// entre varios choferes).
  Future<void> cargarAcumuladoDeVehiculo(String vehiculoId);

  Future<PrecioCombustible> actualizarPrecio({
    required String tipoCombustible,
    required double nuevoPrecio,
  });

  /// Cambia el presupuesto semanal total (en pesos) — antes no existía
  /// forma de editar esto, solo se leía. Queda en auditoría del lado del
  /// backend (ver `preciosService.actualizarPresupuestoSemanalTotal`).
  Future<void> actualizarPresupuestoSemanalTotal(double nuevoValor);

  /// Corrige litros/km de una carga YA registrada (ej. edición inline en
  /// el Concentrado, cuando el chofer capturó mal el dato). Distinto de
  /// [registrarCarga]: es una corrección administrativa posterior, y
  /// queda en auditoría del lado del backend en vez de sobrescribirse sin
  /// rastro.
  Future<Carga> editarCarga({
    required String cargaId,
    double? litrosCargados,
    double? kmAlCargar,
  });

  Future<SolicitudAutorizacion> enviarSolicitud({
    required String idempotencyKey,
    required String payloadFingerprint,
    required String choferId,
    required Vehiculo vehiculo,
    required double litrosSolicitados,
    bool esUrgente = false,
    String? motivoChofer,
    required String actividad,
    required DateTime fechaProgramada,
    // Foto del tablero (km/horómetro actual) al momento de pedir — mismo
    // respaldo visual que ya se manda por WhatsApp en el proceso real,
    // antes de que el chofer vaya a cargar combustible.
    String? fotoTableroPath,
    List<SolicitudPartida>? partidas,
  });

  SolicitudAutorizacion? solicitudPorFolio(String folio);

  /// El propio chofer cancela una solicitud suya que sigue pendiente —
  /// distinto de [resolverSolicitud] (solo administrativo). Lanza
  /// [ApiException] si ya no está pendiente o no le pertenece.
  Future<SolicitudAutorizacion> cancelarSolicitud(String solicitudId);

  Future<SolicitudAutorizacion> resolverSolicitud({
    required String solicitudId,
    required bool aprobar,
    required String resueltaPor,
    double? litrosAutorizados,
    String? motivo,
    List<ResolucionPartida>? partidas,
  });

  Future<Carga> registrarCarga({
    required String choferId,
    required String vehiculoId,
    required String folioAutorizacion,

    /// Folios extra de la misma visita — ej. la carga a granel de la
    /// marimba, pagada con varios folios de una sola vez.
    List<String>? foliosAdicionales,
    required double litrosCargados,
    required double kmAlCargar,
    required String gasolinera,
    String? fotoTicketPath,
    String? fotoTableroPath,
    double? litrosDetectadosOcr,
    List<SolicitudPartida>? partidas,
    List<ComprobanteEstacionCarga>? comprobantes,
  });

  Future<Carga> registrarCargaIdempotente({
    required String idempotencyKey,
    required String choferId,
    required String vehiculoId,
    required String folioAutorizacion,
    List<String>? foliosAdicionales,
    required double litrosCargados,
    required double kmAlCargar,
    required String gasolinera,
    String? fotoTicketPath,
    String? fotoTableroPath,
    double? litrosDetectadosOcr,
    List<SolicitudPartida>? partidas,
    List<ComprobanteEstacionCarga>? comprobantes,
  }) => registrarCarga(
    choferId: choferId,
    vehiculoId: vehiculoId,
    folioAutorizacion: folioAutorizacion,
    foliosAdicionales: foliosAdicionales,
    litrosCargados: litrosCargados,
    kmAlCargar: kmAlCargar,
    gasolinera: gasolinera,
    fotoTicketPath: fotoTicketPath,
    fotoTableroPath: fotoTableroPath,
    litrosDetectadosOcr: litrosDetectadosOcr,
    partidas: partidas,
    comprobantes: comprobantes,
  );

  Carga? cargaAbiertaDeHoy(String choferId);

  Future<CierreDia> cerrarDia({
    required String choferId,
    required String cargaId,
    required double kmFinal,
    required String fotoTableroPath,
  });

  Future<CierreDia> cerrarDiaIdempotente({
    required String idempotencyKey,
    required String choferId,
    required String cargaId,
    required double kmFinal,
    required String fotoTableroPath,
  }) => cerrarDia(
    choferId: choferId,
    cargaId: cargaId,
    kmFinal: kmFinal,
    fotoTableroPath: fotoTableroPath,
  );

  Carga? cargaDe(CierreDia cierre);
  CierreDia? cierreDe(Carga carga);
  RendimientoDia? rendimientoDe(CierreDia cierre);

  /// Historial de lecturas (km u horómetro) de un vehículo — ver
  /// [cargarHistorialLecturas]; vacío si todavía no se ha cargado.
  List<({DateTime fecha, double lectura})> historialLecturas(String vehiculoId);

  /// Trae del backend el historial de lecturas de un vehículo específico
  /// — usado por el módulo de Mantenimiento preventivo (solo admin).
  Future<void> cargarHistorialLecturas(String vehiculoId);
}
