import 'package:uuid/uuid.dart';

enum EstadoOperacionOffline {
  pendiente,
  sincronizando,
  errorTransitorio,
  conflicto,
  errorPermanente,
  sincronizada,
  requiereRevision,
}

final _uuidV4 = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);

bool esUuidV4(String? valor) => valor != null && _uuidV4.hasMatch(valor.trim());

String nuevaIdempotencyKeyOffline() => const Uuid().v4();

/// Duración del lease por operación en sincronización.
/// Si el lease venció, la operación se puede recuperar.
const Duration duracionLease = Duration(minutes: 5);

class MetadataOperacionOffline {
  MetadataOperacionOffline({
    required this.idempotencyKey,
    this.estado = EstadoOperacionOffline.pendiente,
    this.intentos = 0,
    this.ultimoIntento,
    this.proximoIntento,
    this.ultimoError,
    this.ultimoStatus,
    this.ultimoCodigo,
    this.requiereLogin = false,
    this.leaseHasta,
    this.leaseSincronizador,
  });

  factory MetadataOperacionOffline.nueva({String? idempotencyKey}) =>
      MetadataOperacionOffline(
        idempotencyKey: esUuidV4(idempotencyKey)
            ? idempotencyKey!.toLowerCase()
            : nuevaIdempotencyKeyOffline(),
      );

  factory MetadataOperacionOffline.fromJson(
    Map<String, dynamic> json, {
    EstadoOperacionOffline estadoPredeterminado =
        EstadoOperacionOffline.pendiente,
  }) {
    final key = json['idempotencyKey'] as String?;
    final estadoCrudo = json['estadoOffline'] as String?;
    return MetadataOperacionOffline(
      idempotencyKey: esUuidV4(key)
          ? key!.toLowerCase()
          : nuevaIdempotencyKeyOffline(),
      estado: estadoCrudo == null
          ? estadoPredeterminado
          : EstadoOperacionOffline.values.firstWhere(
              (valor) => valor.name == estadoCrudo,
              orElse: () => estadoPredeterminado,
            ),
      intentos: json['intentos'] as int? ?? 0,
      ultimoIntento: _fecha(json['ultimoIntento']),
      proximoIntento: _fecha(json['proximoIntento']),
      ultimoError: json['ultimoError'] as String?,
      ultimoStatus: json['ultimoStatus'] as int?,
      ultimoCodigo: json['ultimoCodigo'] as String?,
      requiereLogin: json['requiereLogin'] as bool? ?? false,
      leaseHasta: _fecha(json['leaseHasta']),
      leaseSincronizador: json['leaseSincronizador'] as String?,
    );
  }

  final String idempotencyKey;
  final EstadoOperacionOffline estado;
  final int intentos;
  final DateTime? ultimoIntento;
  final DateTime? proximoIntento;
  final String? ultimoError;
  final int? ultimoStatus;
  final String? ultimoCodigo;
  final bool requiereLogin;
  final DateTime? leaseHasta;
  final String? leaseSincronizador;

  /// El lease está vigente si la operación está sincronizando y
  /// el timestamp de expiración aún no pasó.
  bool get leaseVigente =>
      estado == EstadoOperacionOffline.sincronizando &&
      leaseHasta != null &&
      leaseHasta!.isAfter(DateTime.now());

  MetadataOperacionOffline copiar({
    EstadoOperacionOffline? estado,
    int? intentos,
    DateTime? ultimoIntento,
    DateTime? proximoIntento,
    bool limpiarProximoIntento = false,
    String? ultimoError,
    bool limpiarUltimoError = false,
    int? ultimoStatus,
    bool limpiarUltimoStatus = false,
    String? ultimoCodigo,
    bool limpiarUltimoCodigo = false,
    bool? requiereLogin,
    DateTime? leaseHasta,
    bool limpiarLease = false,
    String? leaseSincronizador,
  }) => MetadataOperacionOffline(
    idempotencyKey: idempotencyKey,
    estado: estado ?? this.estado,
    intentos: intentos ?? this.intentos,
    ultimoIntento: ultimoIntento ?? this.ultimoIntento,
    proximoIntento: limpiarProximoIntento
        ? null
        : proximoIntento ?? this.proximoIntento,
    ultimoError: limpiarUltimoError ? null : ultimoError ?? this.ultimoError,
    ultimoStatus: limpiarUltimoStatus
        ? null
        : ultimoStatus ?? this.ultimoStatus,
    ultimoCodigo: limpiarUltimoCodigo
        ? null
        : ultimoCodigo ?? this.ultimoCodigo,
    requiereLogin: requiereLogin ?? this.requiereLogin,
    leaseHasta: limpiarLease ? null : leaseHasta ?? this.leaseHasta,
    leaseSincronizador: limpiarLease
        ? null
        : leaseSincronizador ?? this.leaseSincronizador,
  );

  Map<String, dynamic> toJson() => {
    'idempotencyKey': idempotencyKey,
    'estadoOffline': estado.name,
    'intentos': intentos,
    'ultimoIntento': ultimoIntento?.toIso8601String(),
    'proximoIntento': proximoIntento?.toIso8601String(),
    'ultimoError': ultimoError,
    'ultimoStatus': ultimoStatus,
    'ultimoCodigo': ultimoCodigo,
    'requiereLogin': requiereLogin,
    if (leaseHasta != null) 'leaseHasta': leaseHasta!.toIso8601String(),
    if (leaseSincronizador != null) 'leaseSincronizador': leaseSincronizador,
  };

  static bool requiereMigracion(Map<String, dynamic> json) =>
      !esUuidV4(json['idempotencyKey'] as String?) ||
      !json.containsKey('estadoOffline') ||
      !json.containsKey('requiereLogin');

  static DateTime? _fecha(Object? valor) =>
      valor is String ? DateTime.tryParse(valor) : null;
}
