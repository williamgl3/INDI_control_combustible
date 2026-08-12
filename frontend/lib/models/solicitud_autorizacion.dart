import 'package:flutter/foundation.dart';

/// Estado de una [SolicitudAutorizacion].
///
/// [pendiente] significa que espera revisión manual de un administrativo
/// (no tiene historial suficiente, se sale de su patrón habitual, o
/// excede el presupuesto semanal) — ver
/// `MockOperacionesRepository.enviarSolicitud`.
enum EstadoSolicitud { pendiente, aprobada, rechazada }

/// Estado que de verdad le importa al chofer — a diferencia de
/// [EstadoSolicitud] (el enum de 3 valores que espeja la columna real de
/// la base de datos, no se toca aquí para no romper el contrato con el
/// backend), este distingue "me dieron todo lo que pedí" de "me dieron
/// menos" dentro del mismo valor `aprobada`. Se deriva de los litros, no
/// se guarda aparte — ver [SolicitudAutorizacion.estadoVisual] — así el
/// estado nunca puede desincronizarse de las cantidades reales.
enum EstadoVisualSolicitud { pendiente, autorizada, ajustada, rechazada }

enum TipoPartidaSolicitud { consumoPropio, cargaGranel }

enum EstadoPartidaSolicitud { pendiente, aprobada, rechazada }

double _decimalApi(Object? value, String campo) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Decimal inválido en $campo.');
}

double? _decimalApiNullable(Object? value, String campo) =>
    value == null ? null : _decimalApi(value, campo);

@immutable
class SolicitudPartida {
  const SolicitudPartida({
    this.id,
    required this.tipo,
    required this.litrosSolicitados,
    required this.tipoCombustible,
    this.litrosAutorizados,
    this.litrosCargados = 0,
    this.estado = EstadoPartidaSolicitud.pendiente,
    this.observaciones,
  });

  final String? id;
  final TipoPartidaSolicitud tipo;
  final double litrosSolicitados;
  final double? litrosAutorizados;
  final double litrosCargados;
  final String tipoCombustible;
  final EstadoPartidaSolicitud estado;
  final String? observaciones;

  String get tipoApi => switch (tipo) {
    TipoPartidaSolicitud.consumoPropio => 'consumo_propio',
    TipoPartidaSolicitud.cargaGranel => 'carga_granel',
  };

  String get etiqueta => switch (tipo) {
    TipoPartidaSolicitud.consumoPropio => 'Consumo propio',
    TipoPartidaSolicitud.cargaGranel => 'Carga a granel',
  };

  factory SolicitudPartida.fromJson(Map<String, dynamic> json) {
    final tipo = switch (json['tipo']) {
      'consumo_propio' => TipoPartidaSolicitud.consumoPropio,
      'carga_granel' => TipoPartidaSolicitud.cargaGranel,
      _ => throw const FormatException('Tipo de partida no reconocido.'),
    };
    return SolicitudPartida(
      id: json['id'] as String?,
      tipo: tipo,
      litrosSolicitados: _decimalApi(
        json['litrosSolicitados'],
        'litrosSolicitados',
      ),
      litrosAutorizados: _decimalApiNullable(
        json['litrosAutorizados'],
        'litrosAutorizados',
      ),
      litrosCargados:
          _decimalApiNullable(json['litrosCargados'], 'litrosCargados') ?? 0,
      tipoCombustible: json['tipoCombustible'] as String,
      estado: EstadoPartidaSolicitud.values.byName(json['estado'] as String),
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toRequestJson() => {
    'tipo': tipoApi,
    'litros': litrosSolicitados,
    'tipoCombustible': tipoCombustible,
    if (observaciones != null) 'observaciones': observaciones,
  };
}

@immutable
class ResolucionPartida {
  const ResolucionPartida({
    required this.tipo,
    required this.aprobar,
    this.litrosAutorizados,
    this.observaciones,
  });

  final TipoPartidaSolicitud tipo;
  final bool aprobar;
  final double? litrosAutorizados;
  final String? observaciones;

  Map<String, dynamic> toJson() => {
    'tipo': tipo == TipoPartidaSolicitud.consumoPropio
        ? 'consumo_propio'
        : 'carga_granel',
    'aprobar': aprobar,
    'litrosAutorizados': litrosAutorizados,
    'observaciones': observaciones,
  };
}

/// Solicitud de autorización de carga de combustible hecha por un chofer
/// desde /chofer/solicitar, cuya respuesta se muestra en /chofer/respuesta.
///
/// Es parte del flujo offline-first: si no hay conexión, se encola
/// localmente (el mecanismo de sincronización se define en una tanda
/// futura). Dato que vendrá del backend; hoy solo existe vía mocks.
@immutable
class SolicitudAutorizacion {
  const SolicitudAutorizacion({
    required this.id,
    required this.choferId,
    required this.vehiculoId,
    required this.litrosSolicitados,
    required this.estado,
    required this.creadaEn,
    this.costoEstimado,
    this.esUrgente = false,
    this.motivoChofer,
    required this.actividad,
    required this.fechaProgramada,
    this.litrosAutorizados,
    this.aprobadaPor,
    this.folioAutorizacion,
    this.comentario,
    this.pendienteDeSincronizar = false,
    this.fotoTableroPath,
    this.partidas = const [],
  });

  final String id;
  final String choferId;

  /// El vehículo elegido para esta solicitud — se elige cada vez, no es
  /// fijo del chofer (ver `Vehiculo`).
  final String vehiculoId;

  final double litrosSolicitados;
  final EstadoSolicitud estado;
  final DateTime creadaEn;

  /// Litros solicitados × precio de referencia vigente del combustible
  /// del vehículo al momento de pedir — es la base contra la que se
  /// descuenta el presupuesto semanal (ver
  /// `MockOperacionesRepository.presupuestoRestante`). `null` cuando el
  /// vehículo no tenía `tipoCombustible` confirmado en ese momento
  /// (unidad de maquinaria/pipa sin dato del catálogo todavía) — la
  /// solicitud se crea igual, pero nunca se auto-aprueba.
  final double? costoEstimado;

  /// `true` si se pidió para el mismo día (excepción), no "para mañana".
  final bool esUrgente;

  /// Motivo opcional que da el CHOFER al pedir (ej. "voy hasta el frente
  /// de obra"). Obligatorio en la UI cuando [esUrgente] es `true`.
  final String? motivoChofer;

  /// Descripción del trabajo/actividad para el que se necesita el
  /// combustible (ej. "Tramo 340+000 al 349+420, Realizar Trazos y
  /// Niveles..."). Siempre obligatorio.
  final String actividad;

  /// Fecha y hora en que el chofer necesita el combustible — informativo,
  /// no reemplaza a [esUrgente] (que sigue rigiendo la auto-aprobación).
  final DateTime fechaProgramada;

  /// Litros que finalmente se autorizaron — puede ser menor a
  /// [litrosSolicitados] si un administrativo decidió recortar la
  /// solicitud. `null` mientras [estado] sea [EstadoSolicitud.pendiente].
  final double? litrosAutorizados;

  /// Quién resolvió la solicitud: `"Automático (historial)"` si la
  /// aprobó el sistema, o el nombre del administrativo si fue manual.
  final String? aprobadaPor;

  /// Folio devuelto al aprobarse; usado luego en /chofer/comprobar.
  final String? folioAutorizacion;

  /// Motivo de la RESOLUCIÓN (por qué se rechazó, por qué se autorizó
  /// menos de lo pedido, o por qué quedó pendiente de revisión).
  final String? comentario;

  /// true si esta solicitud se creó sin conexión y aún no se ha enviado
  /// al backend.
  final bool pendienteDeSincronizar;

  /// Foto del tablero (km/horómetro actual) al momento de pedir — mismo
  /// respaldo visual que ya se manda por WhatsApp en el proceso real,
  /// antes de ir a cargar combustible. `null` en solicitudes anteriores a
  /// este campo.
  final String? fotoTableroPath;
  final List<SolicitudPartida> partidas;

  /// Ver [EstadoVisualSolicitud]. `aprobada` con 0 litros autorizados
  /// cuenta como rechazo real (unidad inactiva/sin actividad) — el admin
  /// puede llegar a ese resultado tanto pulsando "Rechazar" como
  /// autorizando 0 L desde el flujo normal (`RevisarSolicitudDialog`
  /// permite bajar el stepper hasta 0), así que se deriva del número, no
  /// del botón que se haya usado.
  EstadoVisualSolicitud get estadoVisual {
    switch (estado) {
      case EstadoSolicitud.pendiente:
        return EstadoVisualSolicitud.pendiente;
      case EstadoSolicitud.rechazada:
        return EstadoVisualSolicitud.rechazada;
      case EstadoSolicitud.aprobada:
        final autorizados = litrosAutorizados ?? litrosSolicitados;
        if (autorizados <= 0) return EstadoVisualSolicitud.rechazada;
        if (autorizados < litrosSolicitados) {
          return EstadoVisualSolicitud.ajustada;
        }
        return EstadoVisualSolicitud.autorizada;
    }
  }

  SolicitudAutorizacion copyWith({
    String? id,
    String? choferId,
    String? vehiculoId,
    double? litrosSolicitados,
    EstadoSolicitud? estado,
    DateTime? creadaEn,
    double? costoEstimado,
    bool? esUrgente,
    String? motivoChofer,
    String? actividad,
    DateTime? fechaProgramada,
    double? litrosAutorizados,
    String? aprobadaPor,
    String? folioAutorizacion,
    String? comentario,
    bool? pendienteDeSincronizar,
    String? fotoTableroPath,
    List<SolicitudPartida>? partidas,
  }) {
    return SolicitudAutorizacion(
      id: id ?? this.id,
      choferId: choferId ?? this.choferId,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      litrosSolicitados: litrosSolicitados ?? this.litrosSolicitados,
      estado: estado ?? this.estado,
      creadaEn: creadaEn ?? this.creadaEn,
      costoEstimado: costoEstimado ?? this.costoEstimado,
      esUrgente: esUrgente ?? this.esUrgente,
      motivoChofer: motivoChofer ?? this.motivoChofer,
      actividad: actividad ?? this.actividad,
      fechaProgramada: fechaProgramada ?? this.fechaProgramada,
      litrosAutorizados: litrosAutorizados ?? this.litrosAutorizados,
      aprobadaPor: aprobadaPor ?? this.aprobadaPor,
      folioAutorizacion: folioAutorizacion ?? this.folioAutorizacion,
      comentario: comentario ?? this.comentario,
      pendienteDeSincronizar:
          pendienteDeSincronizar ?? this.pendienteDeSincronizar,
      fotoTableroPath: fotoTableroPath ?? this.fotoTableroPath,
      partidas: partidas ?? this.partidas,
    );
  }

  factory SolicitudAutorizacion.fromJson(Map<String, dynamic> json) {
    return SolicitudAutorizacion(
      id: json['id'] as String,
      choferId: json['choferId'] as String,
      vehiculoId: json['vehiculoId'] as String,
      litrosSolicitados: (json['litrosSolicitados'] as num).toDouble(),
      estado: EstadoSolicitud.values.byName(json['estado'] as String),
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      costoEstimado: (json['costoEstimado'] as num?)?.toDouble(),
      esUrgente: json['esUrgente'] as bool? ?? false,
      motivoChofer: json['motivoChofer'] as String?,
      actividad: json['actividad'] as String,
      fechaProgramada: DateTime.parse(json['fechaProgramada'] as String),
      litrosAutorizados: (json['litrosAutorizados'] as num?)?.toDouble(),
      aprobadaPor: json['aprobadaPor'] as String?,
      folioAutorizacion: json['folioAutorizacion'] as String?,
      comentario: json['comentario'] as String?,
      pendienteDeSincronizar: json['pendienteDeSincronizar'] as bool? ?? false,
      fotoTableroPath: json['fotoTableroPath'] as String?,
      partidas: (json['partidas'] as List<dynamic>? ?? const [])
          .map(
            (item) => SolicitudPartida.fromJson(item as Map<String, dynamic>),
          )
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'choferId': choferId,
      'vehiculoId': vehiculoId,
      'litrosSolicitados': litrosSolicitados,
      'estado': estado.name,
      'creadaEn': creadaEn.toIso8601String(),
      'costoEstimado': costoEstimado,
      'esUrgente': esUrgente,
      'motivoChofer': motivoChofer,
      'actividad': actividad,
      'fechaProgramada': fechaProgramada.toIso8601String(),
      'litrosAutorizados': litrosAutorizados,
      'aprobadaPor': aprobadaPor,
      'folioAutorizacion': folioAutorizacion,
      'comentario': comentario,
      'pendienteDeSincronizar': pendienteDeSincronizar,
      'fotoTableroPath': fotoTableroPath,
      'partidas': partidas.map((partida) => partida.toRequestJson()).toList(),
    };
  }
}
