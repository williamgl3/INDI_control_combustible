import 'package:flutter/foundation.dart';

/// Registro 1 del día: se llena justo después de cargar combustible en la
/// gasolinera, referenciando el folio de una [SolicitudAutorizacion]
/// previamente aprobada.
///
/// El vehículo se elige/confirma en este momento (no es fijo del
/// chofer — ver `Vehiculo`), por si en el camino le tocó una unidad
/// distinta a la que eligió al solicitar. [creadaEn] la pone el
/// dispositivo automáticamente al momento de enviar — el chofer no puede
/// editarla, para que sirva como registro de auditoría.
/// Dato que vendrá del backend; hoy solo existe vía mocks.
@immutable
class Carga {
  const Carga({
    required this.id,
    required this.choferId,
    required this.vehiculoId,
    required this.folioAutorizacion,
    this.foliosAdicionales = const [],
    required this.litrosCargados,
    required this.kmAlCargar,
    required this.gasolinera,
    required this.creadaEn,
    this.fotoTicketPath,
    this.fotoTableroPath,
    this.litrosDetectadosOcr,
    this.pendienteDeSincronizar = false,
    this.precioReferenciaPorLitro,
    this.costoReferencia,
  });

  final String id;
  final String choferId;

  /// El vehículo confirmado al momento de cargar — puede diferir del que
  /// se eligió al solicitar, si en el camino le tocó otra unidad.
  final String vehiculoId;

  final String folioAutorizacion;

  /// Folios extra de la misma visita a la estación — ej. la carga a
  /// granel de la marimba, pagada con varios folios de una sola vez.
  /// Vacío en el caso normal de 1 chofer / 1 folio.
  final List<String> foliosAdicionales;

  final double litrosCargados;

  /// Kilometraje que marca el tablero al momento de cargar combustible.
  /// Es el punto de referencia para calcular el rendimiento del día
  /// (ver [CierreDia.kmRecorridos]).
  final double kmAlCargar;

  final String gasolinera;

  final DateTime creadaEn;

  /// Ruta local de la foto del ticket de la gasolinera.
  final String? fotoTicketPath;

  /// Ruta local de la foto del tablero mostrando [kmAlCargar].
  final String? fotoTableroPath;

  /// Litros que el OCR del ticket logró reconocer (si acaso), para
  /// comparar contra [litrosCargados] como apoyo visual al admin — nunca
  /// bloquea el envío del chofer.
  final double? litrosDetectadosOcr;

  final bool pendienteDeSincronizar;

  /// Snapshot del precio de REFERENCIA (no el real pagado) al momento de
  /// registrar la carga — mismo patrón que
  /// `SolicitudAutorizacion.costoEstimado`. `null` si el vehículo no
  /// tenía `tipoCombustible` confirmado en ese momento (unidad de
  /// maquinaria/pipa sin dato del catálogo todavía) — nunca 0.
  final double? precioReferenciaPorLitro;
  final double? costoReferencia;

  /// `true` si lo que el chofer escribió coincide razonablemente con lo
  /// que el OCR leyó del ticket. `null` si el OCR no detectó nada.
  bool? get ocrCoincide {
    if (litrosDetectadosOcr == null) return null;
    return (litrosDetectadosOcr! - litrosCargados).abs() <= 1.5;
  }

  Carga copyWith({
    String? id,
    String? choferId,
    String? vehiculoId,
    String? folioAutorizacion,
    List<String>? foliosAdicionales,
    double? litrosCargados,
    double? kmAlCargar,
    String? gasolinera,
    DateTime? creadaEn,
    String? fotoTicketPath,
    String? fotoTableroPath,
    double? litrosDetectadosOcr,
    bool? pendienteDeSincronizar,
    double? precioReferenciaPorLitro,
    double? costoReferencia,
  }) {
    return Carga(
      id: id ?? this.id,
      choferId: choferId ?? this.choferId,
      vehiculoId: vehiculoId ?? this.vehiculoId,
      folioAutorizacion: folioAutorizacion ?? this.folioAutorizacion,
      foliosAdicionales: foliosAdicionales ?? this.foliosAdicionales,
      litrosCargados: litrosCargados ?? this.litrosCargados,
      kmAlCargar: kmAlCargar ?? this.kmAlCargar,
      gasolinera: gasolinera ?? this.gasolinera,
      creadaEn: creadaEn ?? this.creadaEn,
      fotoTicketPath: fotoTicketPath ?? this.fotoTicketPath,
      fotoTableroPath: fotoTableroPath ?? this.fotoTableroPath,
      litrosDetectadosOcr: litrosDetectadosOcr ?? this.litrosDetectadosOcr,
      pendienteDeSincronizar:
          pendienteDeSincronizar ?? this.pendienteDeSincronizar,
      precioReferenciaPorLitro:
          precioReferenciaPorLitro ?? this.precioReferenciaPorLitro,
      costoReferencia: costoReferencia ?? this.costoReferencia,
    );
  }

  factory Carga.fromJson(Map<String, dynamic> json) {
    return Carga(
      id: json['id'] as String,
      choferId: json['choferId'] as String,
      vehiculoId: json['vehiculoId'] as String,
      folioAutorizacion: json['folioAutorizacion'] as String,
      foliosAdicionales:
          (json['foliosAdicionales'] as List<dynamic>?)?.cast<String>() ??
          const [],
      litrosCargados: (json['litrosCargados'] as num).toDouble(),
      kmAlCargar: (json['kmAlCargar'] as num).toDouble(),
      gasolinera: json['gasolinera'] as String,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      fotoTicketPath: json['fotoTicketPath'] as String?,
      fotoTableroPath: json['fotoTableroPath'] as String?,
      litrosDetectadosOcr: (json['litrosDetectadosOcr'] as num?)?.toDouble(),
      pendienteDeSincronizar: json['pendienteDeSincronizar'] as bool? ?? false,
      precioReferenciaPorLitro: (json['precioReferenciaPorLitro'] as num?)
          ?.toDouble(),
      costoReferencia: (json['costoReferencia'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'choferId': choferId,
      'vehiculoId': vehiculoId,
      'folioAutorizacion': folioAutorizacion,
      'foliosAdicionales': foliosAdicionales,
      'litrosCargados': litrosCargados,
      'kmAlCargar': kmAlCargar,
      'gasolinera': gasolinera,
      'creadaEn': creadaEn.toIso8601String(),
      'fotoTicketPath': fotoTicketPath,
      'fotoTableroPath': fotoTableroPath,
      'litrosDetectadosOcr': litrosDetectadosOcr,
      'pendienteDeSincronizar': pendienteDeSincronizar,
      'precioReferenciaPorLitro': precioReferenciaPorLitro,
      'costoReferencia': costoReferencia,
    };
  }
}
