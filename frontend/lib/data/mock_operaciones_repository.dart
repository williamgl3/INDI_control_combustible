import '../models/carga.dart';
import '../models/cierre_dia.dart';
import '../models/precio_combustible.dart';
import '../models/solicitud_autorizacion.dart';
import '../models/vehiculo.dart';
import '../core/semana_util.dart';

/// Repositorio MOCK de operaciones (solicitudes de autorización y cargas
/// de combustible), en memoria.
///
/// La aprobación de una solicitud combina dos señales — ver
/// [enviarSolicitud] — y solo se auto-resuelve cuando ambas son
/// favorables; el resto queda [EstadoSolicitud.pendiente] para que un
/// administrativo la revise y decida manualmente (ver [resolverSolicitud]),
/// pudiendo autorizar menos de lo pedido con un motivo.
///
/// TODO-BACKEND: reemplazar por un repositorio real con la misma
/// interfaz cuando el backend esté listo.
class MockOperacionesRepository {
  final List<SolicitudAutorizacion> _solicitudes = [];
  final List<Carga> _cargas = [];
  final List<CierreDia> _cierres = [];
  int _folioSeq = 1000;
  int _idSeq = 1;

  /// Mínimo de solicitudes aprobadas previas que debe tener un chofer
  /// antes de que su historial se considere "confiable" para auto-aprobar.
  /// TODO-SPEC: valor PLACEHOLDER.
  static const _historialMinimo = 4;

  /// Margen sobre el máximo histórico que todavía se considera "dentro
  /// de su patrón habitual" (15%). TODO-SPEC: valor PLACEHOLDER.
  static const _margenPatron = 1.15;

  /// Presupuesto semanal total de la obra, en pesos.
  /// TODO-SPEC: valor PLACEHOLDER.
  double presupuestoSemanalTotal = 50000;

  /// Ej. "15 al 21 jul" — a qué semana corresponden
  /// [presupuestoEjercido]/[litrosAutorizadosAcumulados].
  String get etiquetaSemanaActual => etiquetaRangoSemana(DateTime.now());

  final List<PrecioCombustible> _precios = [
    PrecioCombustible(
      tipoCombustible: 'Diésel',
      precioPorLitro: 24.50,
      actualizadoEn: DateTime(2026, 7, 1),
    ),
    PrecioCombustible(
      tipoCombustible: 'Gasolina',
      precioPorLitro: 23.80,
      actualizadoEn: DateTime(2026, 7, 1),
    ),
  ];

  List<PrecioCombustible> get precios => List.unmodifiable(_precios);

  double _precioDe(String tipoCombustible) {
    final precio = _precios.firstWhere(
      (p) => p.tipoCombustible == tipoCombustible,
      orElse: () => _precios.first,
    );
    return precio.precioPorLitro;
  }

  /// Actualiza el precio por litro de un tipo de combustible ya existente
  /// en el catálogo (panel administrativo).
  Future<PrecioCombustible> actualizarPrecio({
    required String tipoCombustible,
    required double nuevoPrecio,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _precios.indexWhere((p) => p.tipoCombustible == tipoCombustible);
    final actualizado = PrecioCombustible(
      tipoCombustible: tipoCombustible,
      precioPorLitro: nuevoPrecio,
      actualizadoEn: DateTime.now(),
    );
    _precios[indice] = actualizado;
    return actualizado;
  }

  List<SolicitudAutorizacion> solicitudesDeChofer(String choferId) {
    final propias = _solicitudes.where((s) => s.choferId == choferId).toList();
    propias.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    return propias;
  }

  List<SolicitudAutorizacion> get todasLasSolicitudes {
    final todas = List<SolicitudAutorizacion>.from(_solicitudes);
    todas.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    return todas;
  }

  List<Carga> cargasDeChofer(String choferId) {
    final propias = _cargas.where((c) => c.choferId == choferId).toList();
    propias.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    return propias;
  }

  /// Suma de litros ya autorizados (solicitudes aprobadas) para un
  /// VEHÍCULO (no un chofer — varios choferes pueden compartirlo) EN LA
  /// SEMANA ACTUAL (lunes-domingo) — ver [inicioDeSemana].
  double litrosAutorizadosAcumulados(String vehiculoId) {
    final hoy = DateTime.now();
    return _solicitudesAprobadasDeVehiculo(vehiculoId)
        .where((s) => estaEnSemanaDe(s.creadaEn, hoy))
        .fold(0.0, (suma, s) => suma + (s.litrosAutorizados ?? s.litrosSolicitados));
  }

  /// Dinero ya comprometido de [presupuestoSemanalTotal] EN LA SEMANA
  /// ACTUAL.
  /// TODO-SPEC: usa el costo estimado al momento de pedir aunque un
  /// admin haya autorizado menos después — simplificación de mock, no
  /// vuelve a prorratear el costo real.
  double get presupuestoEjercido {
    final hoy = DateTime.now();
    return _solicitudes
        .where((s) => s.estado == EstadoSolicitud.aprobada && estaEnSemanaDe(s.creadaEn, hoy))
        .fold(0.0, (suma, s) => suma + s.costoEstimado);
  }

  double get presupuestoRestante => presupuestoSemanalTotal - presupuestoEjercido;

  List<SolicitudAutorizacion> _solicitudesAprobadasDeVehiculo(String vehiculoId) {
    return _solicitudes
        .where((s) => s.vehiculoId == vehiculoId && s.estado == EstadoSolicitud.aprobada)
        .toList();
  }

  bool _tieneHistorialSuficiente(String vehiculoId) {
    return _solicitudesAprobadasDeVehiculo(vehiculoId).length >= _historialMinimo;
  }

  /// Máximo autorizado históricamente — el "patrón habitual" de consumo
  /// de este VEHÍCULO (no del chofer que lo maneje ese día).
  double _consumoHabitualDe(String vehiculoId) {
    final historial = _solicitudesAprobadasDeVehiculo(vehiculoId);
    if (historial.isEmpty) return 0;
    return historial
        .map((s) => s.litrosAutorizados ?? s.litrosSolicitados)
        .reduce((a, b) => a > b ? a : b);
  }

  bool _seSaleDePatron(String vehiculoId, double litrosPedidos) {
    if (!_tieneHistorialSuficiente(vehiculoId)) return true;
    return litrosPedidos > _consumoHabitualDe(vehiculoId) * _margenPatron;
  }

  /// Crea una solicitud para un [vehiculo] elegido en el momento (no es
  /// fijo del chofer). Se auto-aprueba SOLO si ESE VEHÍCULO ya tiene
  /// historial confiable (≥4 solicitudes aprobadas), lo pedido no se sale
  /// de su patrón habitual de consumo, y no rebasa el presupuesto semanal
  /// en pesos disponible — cualquier otro caso queda pendiente de
  /// revisión manual (ver [resolverSolicitud]). El tope semanal en
  /// litros del vehículo NO bloquea aquí: queda como referencia visible
  /// para el admin al revisar.
  Future<SolicitudAutorizacion> enviarSolicitud({
    required String choferId,
    required Vehiculo vehiculo,
    required double litrosSolicitados,
    bool esUrgente = false,
    String? motivoChofer,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));

    final costoEstimado = litrosSolicitados * _precioDe(vehiculo.tipoCombustible);
    final tieneHistorial = _tieneHistorialSuficiente(vehiculo.id);
    final seSalePatron = _seSaleDePatron(vehiculo.id, litrosSolicitados);
    final presupuestoOk = costoEstimado <= presupuestoRestante;

    final seAutoAprueba = tieneHistorial && !seSalePatron && presupuestoOk;

    String? comentario;
    if (!seAutoAprueba) {
      if (!tieneHistorial) {
        comentario = 'Este vehículo aún no tiene historial suficiente — un '
            'administrativo revisará esta solicitud.';
      } else if (seSalePatron) {
        comentario = 'Se pidió más de lo habitual para este vehículo — un '
            'administrativo revisará esta solicitud.';
      } else {
        comentario = 'Se excede el presupuesto semanal disponible — un '
            'administrativo revisará esta solicitud.';
      }
    }

    final solicitud = SolicitudAutorizacion(
      id: 'sol-${_idSeq++}',
      choferId: choferId,
      vehiculoId: vehiculo.id,
      litrosSolicitados: litrosSolicitados,
      costoEstimado: costoEstimado,
      estado: seAutoAprueba ? EstadoSolicitud.aprobada : EstadoSolicitud.pendiente,
      creadaEn: DateTime.now(),
      esUrgente: esUrgente,
      motivoChofer: motivoChofer,
      litrosAutorizados: seAutoAprueba ? litrosSolicitados : null,
      aprobadaPor: seAutoAprueba ? 'Automático (historial)' : null,
      folioAutorizacion: seAutoAprueba ? 'FA-${_folioSeq++}' : null,
      comentario: comentario,
    );

    _solicitudes.add(solicitud);
    return solicitud;
  }

  /// Busca una solicitud por su folio (ej. para precargar el vehículo
  /// elegido al momento de comprobar la carga). `null` si no existe.
  SolicitudAutorizacion? solicitudPorFolio(String folio) {
    try {
      return _solicitudes.firstWhere((s) => s.folioAutorizacion == folio);
    } catch (_) {
      return null;
    }
  }

  /// Resolución MANUAL de una solicitud pendiente por un administrativo:
  /// puede autorizar menos litros de los pedidos (con [motivo]) o
  /// rechazarla (también con [motivo]).
  Future<SolicitudAutorizacion> resolverSolicitud({
    required String solicitudId,
    required bool aprobar,
    required String resueltaPor,
    double? litrosAutorizados,
    String? motivo,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final indice = _solicitudes.indexWhere((s) => s.id == solicitudId);
    final original = _solicitudes[indice];

    final resuelta = original.copyWith(
      estado: aprobar ? EstadoSolicitud.aprobada : EstadoSolicitud.rechazada,
      litrosAutorizados: aprobar ? (litrosAutorizados ?? original.litrosSolicitados) : 0,
      aprobadaPor: resueltaPor,
      folioAutorizacion: aprobar ? 'FA-${_folioSeq++}' : null,
      comentario: motivo,
    );
    _solicitudes[indice] = resuelta;
    return resuelta;
  }

  /// Registro 1 del día: se llena justo después de cargar combustible.
  /// [creadaEn] la pone el dispositivo (no el chofer) para que sirva de
  /// registro de auditoría.
  Future<Carga> registrarCarga({
    required String choferId,
    required String vehiculoId,
    required String folioAutorizacion,
    required double litrosCargados,
    required double kmAlCargar,
    required String gasolinera,
    String? fotoTicketPath,
    String? fotoTableroPath,
    double? litrosDetectadosOcr,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final carga = Carga(
      id: 'carga-${_idSeq++}',
      choferId: choferId,
      vehiculoId: vehiculoId,
      folioAutorizacion: folioAutorizacion,
      litrosCargados: litrosCargados,
      kmAlCargar: kmAlCargar,
      gasolinera: gasolinera,
      creadaEn: DateTime.now(),
      fotoTicketPath: fotoTicketPath,
      fotoTableroPath: fotoTableroPath,
      litrosDetectadosOcr: litrosDetectadosOcr,
    );
    _cargas.add(carga);
    return carga;
  }

  /// La [Carga] (registro 1) de hoy que todavía no tiene su [CierreDia]
  /// (registro 2), si existe. `null` si no ha cargado hoy o si su carga
  /// de hoy ya quedó cerrada.
  Carga? cargaAbiertaDeHoy(String choferId) {
    final hoy = DateTime.now();
    final cerradas = _cierres.map((c) => c.cargaId).toSet();
    final cargasDeHoy = _cargas.where(
      (c) =>
          c.choferId == choferId &&
          !cerradas.contains(c.id) &&
          c.creadaEn.year == hoy.year &&
          c.creadaEn.month == hoy.month &&
          c.creadaEn.day == hoy.day,
    );
    return cargasDeHoy.isEmpty ? null : cargasDeHoy.first;
  }

  /// Registro 2 del día: se llena cuando el chofer termina de trabajar.
  /// [registradaEn] la pone el dispositivo, igual que [Carga.creadaEn].
  Future<CierreDia> cerrarDia({
    required String choferId,
    required String cargaId,
    required double kmFinal,
    required String fotoTableroPath,
  }) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final cierre = CierreDia(
      id: 'cierre-${_idSeq++}',
      choferId: choferId,
      cargaId: cargaId,
      kmFinal: kmFinal,
      fotoTableroPath: fotoTableroPath,
      registradaEn: DateTime.now(),
    );
    _cierres.add(cierre);
    return cierre;
  }

  List<CierreDia> cierresDeChofer(String choferId) {
    final propios = _cierres.where((c) => c.choferId == choferId).toList();
    propios.sort((a, b) => b.registradaEn.compareTo(a.registradaEn));
    return propios;
  }

  /// Todas las cargas (registro 1) de todos los choferes — para el
  /// concentrado del panel administrativo.
  List<Carga> get todasLasCargas {
    final todas = List<Carga>.from(_cargas);
    todas.sort((a, b) => b.creadaEn.compareTo(a.creadaEn));
    return todas;
  }

  /// Busca la [Carga] de referencia de un [CierreDia] para calcular su
  /// rendimiento. `null` si por alguna razón la carga ya no existe.
  Carga? cargaDe(CierreDia cierre) {
    try {
      return _cargas.firstWhere((c) => c.id == cierre.cargaId);
    } catch (_) {
      return null;
    }
  }

  /// Busca el [CierreDia] (registro 2) de una [Carga], si ya se cerró el
  /// día. `null` mientras siga abierta.
  CierreDia? cierreDe(Carga carga) {
    try {
      return _cierres.firstWhere((c) => c.cargaId == carga.id);
    } catch (_) {
      return null;
    }
  }

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
}
