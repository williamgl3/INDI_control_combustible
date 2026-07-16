import 'package:flutter/foundation.dart';

/// Registro 1 del día: se llena justo después de cargar combustible en la
/// gasolinera, referenciando el folio de una [SolicitudAutorizacion]
/// previamente aprobada.
///
/// Usa el modelo/placa embebidos en el [Perfil] del chofer (precargados
/// tras el login) en lugar de volver a capturarlos. [creadaEn] la pone el
/// dispositivo automáticamente al momento de enviar — el chofer no puede
/// editarla, para que sirva como registro de auditoría.
/// Dato que vendrá del backend; hoy solo existe vía mocks.
@immutable
class Carga {
  const Carga({
    required this.id,
    required this.choferId,
    required this.folioAutorizacion,
    required this.litrosCargados,
    required this.kmAlCargar,
    required this.gasolinera,
    required this.creadaEn,
    this.fotoTicketPath,
    this.fotoTableroPath,
    this.litrosDetectadosOcr,
    this.pendienteDeSincronizar = false,
  });

  final String id;
  final String choferId;
  final String folioAutorizacion;
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

  /// `true` si lo que el chofer escribió coincide razonablemente con lo
  /// que el OCR leyó del ticket. `null` si el OCR no detectó nada.
  bool? get ocrCoincide {
    if (litrosDetectadosOcr == null) return null;
    return (litrosDetectadosOcr! - litrosCargados).abs() <= 1.5;
  }

  Carga copyWith({
    String? id,
    String? choferId,
    String? folioAutorizacion,
    double? litrosCargados,
    double? kmAlCargar,
    String? gasolinera,
    DateTime? creadaEn,
    String? fotoTicketPath,
    String? fotoTableroPath,
    double? litrosDetectadosOcr,
    bool? pendienteDeSincronizar,
  }) {
    return Carga(
      id: id ?? this.id,
      choferId: choferId ?? this.choferId,
      folioAutorizacion: folioAutorizacion ?? this.folioAutorizacion,
      litrosCargados: litrosCargados ?? this.litrosCargados,
      kmAlCargar: kmAlCargar ?? this.kmAlCargar,
      gasolinera: gasolinera ?? this.gasolinera,
      creadaEn: creadaEn ?? this.creadaEn,
      fotoTicketPath: fotoTicketPath ?? this.fotoTicketPath,
      fotoTableroPath: fotoTableroPath ?? this.fotoTableroPath,
      litrosDetectadosOcr: litrosDetectadosOcr ?? this.litrosDetectadosOcr,
      pendienteDeSincronizar:
          pendienteDeSincronizar ?? this.pendienteDeSincronizar,
    );
  }

  factory Carga.fromJson(Map<String, dynamic> json) {
    return Carga(
      id: json['id'] as String,
      choferId: json['choferId'] as String,
      folioAutorizacion: json['folioAutorizacion'] as String,
      litrosCargados: (json['litrosCargados'] as num).toDouble(),
      kmAlCargar: (json['kmAlCargar'] as num).toDouble(),
      gasolinera: json['gasolinera'] as String,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      fotoTicketPath: json['fotoTicketPath'] as String?,
      fotoTableroPath: json['fotoTableroPath'] as String?,
      litrosDetectadosOcr: (json['litrosDetectadosOcr'] as num?)?.toDouble(),
      pendienteDeSincronizar: json['pendienteDeSincronizar'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'choferId': choferId,
      'folioAutorizacion': folioAutorizacion,
      'litrosCargados': litrosCargados,
      'kmAlCargar': kmAlCargar,
      'gasolinera': gasolinera,
      'creadaEn': creadaEn.toIso8601String(),
      'fotoTicketPath': fotoTicketPath,
      'fotoTableroPath': fotoTableroPath,
      'litrosDetectadosOcr': litrosDetectadosOcr,
      'pendienteDeSincronizar': pendienteDeSincronizar,
    };
  }
}
