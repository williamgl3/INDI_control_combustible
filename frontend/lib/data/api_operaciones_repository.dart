import 'dart:convert';

import '../models/carga.dart';
import '../models/cierre_dia.dart';
import '../models/perfil.dart';
import '../models/precio_combustible.dart';
import '../models/solicitud_autorizacion.dart';
import '../models/vehiculo.dart';
import '../core/semana_util.dart';
import 'api_client.dart';
import 'operaciones_repository.dart';

/// Implementación real de [OperacionesRepository]: habla por HTTP con el
/// backend (ver `backend/src/routes/{solicitudes,cargas,cierresDia,
/// precios}.routes.ts`).
///
/// Mantiene un caché en memoria idéntico al de
/// [MockOperacionesRepository] para que las pantallas (que leen listas y
/// agregados de forma síncrona) no necesiten cambios. El caché se llena
/// una vez tras iniciar sesión ([cargarDatosIniciales]) y se actualiza
/// localmente tras cada mutación — igual que hacía el mock con sus
/// listas en memoria.
class ApiOperacionesRepository implements OperacionesRepository {
  ApiOperacionesRepository(this._client);

  final ApiClient _client;

  List<SolicitudAutorizacion> _solicitudes = [];
  List<Carga> _cargas = [];
  List<CierreDia> _cierres = [];
  List<PrecioCombustible> _precios = [];
  Carga? _cargaAbiertaDeHoy;
  final Map<String, double> _acumuladoPorVehiculo = {};
  final Map<String, List<({DateTime fecha, double lectura})>>
  _historialPorVehiculo = {};

  @override
  double presupuestoSemanalTotal = 0;

  @override
  String get etiquetaSemanaActual => etiquetaRangoSemana(DateTime.now());

  @override
  List<PrecioCombustible> get precios => List.unmodifiable(_precios);

  /// Trae, según el rol de [perfil]: precios (todos), y solicitudes/
  /// cargas — propias si es chofer, de todos si es administrativo (más
  /// el resumen de presupuesto y la lista de choferes, solo admin).
  @override
  Future<void> cargarDatosIniciales({required Perfil perfil}) async {
    final preciosData = await _client.get('/precios') as List;
    _precios = preciosData
        .map((j) => PrecioCombustible.fromJson(j as Map<String, dynamic>))
        .toList();

    if (perfil.esAdministrativo) {
      final resumen =
          await _client.get('/solicitudes/resumen-presupuesto')
              as Map<String, dynamic>;
      presupuestoSemanalTotal = (resumen['presupuestoSemanalTotal'] as num)
          .toDouble();

      final solicitudesData = await _client.get('/solicitudes') as List;
      _solicitudes = solicitudesData
          .map((j) => SolicitudAutorizacion.fromJson(j as Map<String, dynamic>))
          .toList();

      final cargasData = await _client.get('/cargas') as List;
      _cargas = cargasData
          .map((j) => Carga.fromJson(j as Map<String, dynamic>))
          .toList();

      final cierresData = await _client.get('/cierres-dia') as List;
      _cierres = cierresData
          .map((j) => CierreDia.fromJson(j as Map<String, dynamic>))
          .toList();
    } else {
      final solicitudesData = await _client.get('/solicitudes/mias') as List;
      _solicitudes = solicitudesData
          .map((j) => SolicitudAutorizacion.fromJson(j as Map<String, dynamic>))
          .toList();

      final cargasData = await _client.get('/cargas/mias') as List;
      _cargas = cargasData
          .map((j) => Carga.fromJson(j as Map<String, dynamic>))
          .toList();

      final cierresData = await _client.get('/cierres-dia/mias') as List;
      _cierres = cierresData
          .map((j) => CierreDia.fromJson(j as Map<String, dynamic>))
          .toList();

      final abiertaData = await _client.get('/cargas/abierta-hoy');
      _cargaAbiertaDeHoy = abiertaData == null
          ? null
          : Carga.fromJson(abiertaData as Map<String, dynamic>);
      if (_cargaAbiertaDeHoy != null) {
        await cargarAcumuladoDeVehiculo(_cargaAbiertaDeHoy!.vehiculoId);
      }
    }
  }

  @override
  List<SolicitudAutorizacion> solicitudesDeChofer(String choferId) {
    final propias = _solicitudes.where((s) => s.choferId == choferId).toList();
    propias.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    return propias;
  }

  @override
  List<SolicitudAutorizacion> get todasLasSolicitudes {
    final todas = List<SolicitudAutorizacion>.from(_solicitudes);
    todas.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    return todas;
  }

  @override
  List<Carga> cargasDeChofer(String choferId) {
    final propias = _cargas.where((c) => c.choferId == choferId).toList();
    propias.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    return propias;
  }

  @override
  double litrosAutorizadosAcumulados(String vehiculoId) {
    return _acumuladoPorVehiculo[vehiculoId] ?? 0;
  }

  @override
  Future<void> cargarAcumuladoDeVehiculo(String vehiculoId) async {
    final data =
        await _client.get('/solicitudes/vehiculo/$vehiculoId/acumulado-semana')
            as Map<String, dynamic>;
    _acumuladoPorVehiculo[vehiculoId] = (data['litros'] as num).toDouble();
  }

  @override
  double get presupuestoEjercido {
    final hoy = DateTime.now();
    return _solicitudes
        .where(
          (s) =>
              s.estado == EstadoSolicitud.aprobada &&
              estaEnSemanaDe(s.creadaEn, hoy),
        )
        .fold(0.0, (suma, s) => suma + (s.costoEstimado ?? 0));
  }

  @override
  double get presupuestoRestante =>
      presupuestoSemanalTotal - presupuestoEjercido;

  @override
  Future<PrecioCombustible> actualizarPrecio({
    required String tipoCombustible,
    required double nuevoPrecio,
  }) async {
    final data = await _client.patch(
      '/precios/$tipoCombustible',
      body: {'nuevoPrecio': nuevoPrecio},
    );
    final precio = PrecioCombustible.fromJson(data as Map<String, dynamic>);
    final indice = _precios.indexWhere(
      (p) => p.tipoCombustible == precio.tipoCombustible,
    );
    if (indice == -1) {
      _precios = [..._precios, precio];
    } else {
      _precios = [..._precios]..[indice] = precio;
    }
    return precio;
  }

  @override
  Future<void> actualizarPresupuestoSemanalTotal(double nuevoValor) async {
    final data =
        await _client.patch(
              '/precios/presupuesto-semanal',
              body: {'nuevoValor': nuevoValor},
            )
            as Map<String, dynamic>;
    presupuestoSemanalTotal = (data['presupuestoSemanalTotal'] as num)
        .toDouble();
  }

  @override
  Future<Carga> editarCarga({
    required String cargaId,
    double? litrosCargados,
    double? kmAlCargar,
  }) async {
    final data = await _client.patch(
      '/cargas/$cargaId',
      body: {'litrosCargados': ?litrosCargados, 'kmAlCargar': ?kmAlCargar},
    );
    final carga = Carga.fromJson(data as Map<String, dynamic>);
    final indice = _cargas.indexWhere((c) => c.id == carga.id);
    if (indice != -1) {
      _cargas = [..._cargas]..[indice] = carga;
    }
    return carga;
  }

  @override
  Future<SolicitudAutorizacion> enviarSolicitud({
    required String choferId,
    required Vehiculo vehiculo,
    required double litrosSolicitados,
    bool esUrgente = false,
    String? motivoChofer,
    required String actividad,
    required DateTime fechaProgramada,
    String? fotoTableroPath,
    List<SolicitudPartida>? partidas,
  }) async {
    final data = await _client.postMultipart(
      '/solicitudes',
      campos: {
        'vehiculoId': vehiculo.id,
        if (partidas == null) 'litrosSolicitados': '$litrosSolicitados',
        if (partidas != null)
          'partidas': jsonEncode(
            partidas.map((partida) => partida.toRequestJson()).toList(),
          ),
        'esUrgente': '$esUrgente',
        'motivoChofer': ?motivoChofer,
        'actividad': actividad,
        'fechaProgramada': fechaProgramada.toIso8601String(),
      },
      archivos: {'fotoTablero': fotoTableroPath},
    );
    final solicitud = SolicitudAutorizacion.fromJson(
      data as Map<String, dynamic>,
    );
    _solicitudes = [..._solicitudes, solicitud];
    return solicitud;
  }

  @override
  SolicitudAutorizacion? solicitudPorFolio(String folio) {
    try {
      return _solicitudes.firstWhere((s) => s.folioAutorizacion == folio);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<SolicitudAutorizacion> cancelarSolicitud(String solicitudId) async {
    final data = await _client.patch('/solicitudes/$solicitudId/cancelar');
    final solicitud = SolicitudAutorizacion.fromJson(
      data as Map<String, dynamic>,
    );
    final indice = _solicitudes.indexWhere((s) => s.id == solicitud.id);
    if (indice != -1) {
      _solicitudes = [..._solicitudes]..[indice] = solicitud;
    }
    return solicitud;
  }

  @override
  Future<SolicitudAutorizacion> resolverSolicitud({
    required String solicitudId,
    required bool aprobar,
    required String resueltaPor,
    double? litrosAutorizados,
    String? motivo,
    List<ResolucionPartida>? partidas,
  }) async {
    final data = await _client.patch(
      '/solicitudes/$solicitudId/resolver',
      body: {
        if (partidas == null) 'aprobar': aprobar,
        'litrosAutorizados': litrosAutorizados,
        'motivo': motivo,
        if (partidas != null)
          'partidas': partidas.map((partida) => partida.toJson()).toList(),
      },
    );
    final solicitud = SolicitudAutorizacion.fromJson(
      data as Map<String, dynamic>,
    );
    final indice = _solicitudes.indexWhere((s) => s.id == solicitud.id);
    if (indice != -1) {
      _solicitudes = [..._solicitudes]..[indice] = solicitud;
    }
    return solicitud;
  }

  @override
  Future<Carga> registrarCarga({
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
  }) async {
    final data = await _client.postMultipart(
      '/cargas',
      campos: {
        'vehiculoId': vehiculoId,
        'folioAutorizacion': folioAutorizacion,
        // Multipart no soporta arrays anidados — se manda como string
        // JSON, el backend lo parsea (ver `cargas.routes.ts`).
        if (foliosAdicionales != null && foliosAdicionales.isNotEmpty)
          'foliosAdicionales': jsonEncode(foliosAdicionales),
        if (partidas == null) 'litrosCargados': '$litrosCargados',
        if (partidas != null)
          'partidas': jsonEncode(
            partidas.map((partida) => partida.toRequestJson()).toList(),
          ),
        if (comprobantes != null)
          'comprobantes': jsonEncode(
            comprobantes.map((comprobante) => comprobante.toJson()).toList(),
          ),
        'kmAlCargar': '$kmAlCargar',
        'gasolinera': gasolinera,
        if (litrosDetectadosOcr != null)
          'litrosDetectadosOcr': '$litrosDetectadosOcr',
      },
      archivos: {'fotoTicket': fotoTicketPath, 'fotoTablero': fotoTableroPath},
    );
    final respuesta = data as Map<String, dynamic>;
    final carga = Carga.fromJson(
      (partidas == null ? respuesta : respuesta['carga'])
          as Map<String, dynamic>,
    );
    _cargas = [..._cargas, carga];
    _cargaAbiertaDeHoy = carga;
    return carga;
  }

  @override
  Carga? cargaAbiertaDeHoy(String choferId) => _cargaAbiertaDeHoy;

  @override
  Future<CierreDia> cerrarDia({
    required String choferId,
    required String cargaId,
    required double kmFinal,
    required String fotoTableroPath,
  }) async {
    final data = await _client.postMultipart(
      '/cierres-dia',
      campos: {'cargaId': cargaId, 'kmFinal': '$kmFinal'},
      archivos: {'fotoTablero': fotoTableroPath},
    );
    final cierre = CierreDia.fromJson(data as Map<String, dynamic>);
    _cierres = [..._cierres, cierre];
    if (_cargaAbiertaDeHoy?.id == cargaId) {
      _cargaAbiertaDeHoy = null;
    }
    return cierre;
  }

  @override
  List<CierreDia> cierresDeChofer(String choferId) {
    final propios = _cierres.where((c) => c.choferId == choferId).toList();
    propios.sort((a, b) => b.registradaEn.compareTo(a.registradaEn));
    return propios;
  }

  @override
  List<Carga> get todasLasCargas {
    final todas = List<Carga>.from(_cargas);
    todas.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    return todas;
  }

  @override
  Carga? cargaDe(CierreDia cierre) {
    try {
      return _cargas.firstWhere((c) => c.id == cierre.cargaId);
    } catch (_) {
      return null;
    }
  }

  @override
  CierreDia? cierreDe(Carga carga) {
    try {
      return _cierres.firstWhere((c) => c.cargaId == carga.id);
    } catch (_) {
      return null;
    }
  }

  @override
  RendimientoDia? rendimientoDe(CierreDia cierre) {
    final carga = cargaDe(cierre);
    if (carga == null) return null;
    final kmRecorridos = cierre.kmFinal - carga.kmAlCargar;
    if (kmRecorridos <= 0) {
      return const RendimientoDia(kmRecorridos: 0, rendimiento: null);
    }
    return RendimientoDia(
      kmRecorridos: kmRecorridos,
      rendimiento: kmRecorridos / carga.litrosCargados,
    );
  }

  @override
  List<({DateTime fecha, double lectura})> historialLecturas(
    String vehiculoId,
  ) {
    return _historialPorVehiculo[vehiculoId] ?? const [];
  }

  @override
  Future<void> cargarHistorialLecturas(String vehiculoId) async {
    final data =
        await _client.get('/vehiculos/$vehiculoId/historial-lecturas') as List;
    _historialPorVehiculo[vehiculoId] = data
        .map(
          (j) => (
            fecha: DateTime.parse(j['fecha'] as String),
            lectura: (j['lectura'] as num).toDouble(),
          ),
        )
        .toList();
  }
}
