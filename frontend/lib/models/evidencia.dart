import 'package:flutter/foundation.dart';

/// Tipo de evidencia que un chofer puede subir.
///
/// `ticket` ya no existe como valor separado — se unificó con
/// [comprobante] (ambos representaban el mismo documento de la
/// gasolinera: folio, litros, precio, IVA y total).
enum TipoEvidencia { tablero, comprobante }

/// Evidencia fotográfica subida por un chofer, vinculada opcionalmente
/// a una solicitud de carga.
@immutable
class Evidencia {
  const Evidencia({
    required this.id,
    required this.usuarioId,
    required this.tipo,
    required this.fotoUrls,
    this.km,
    this.folioId,
    this.cargaId,
    this.pendienteVincular = false,
    this.notas,
    required this.creadaEn,
    this.tipoCombustibleCargado,
    this.litros,
    this.precioPorLitro,
    this.montoPagado,
    this.requiereRevision = false,
    this.desviacionPrecioPorcentaje,
    this.precioReferenciaComparado,
  });

  final String id;
  final String usuarioId;
  final TipoEvidencia tipo;

  /// Hasta 5 fotos por registro (comprobante + tablero subidos juntos al
  /// cierre del día son casos válidos). Siempre tiene al menos un
  /// elemento.
  final List<String> fotoUrls;

  /// Primera foto — conveniencia para UI que solo necesita una miniatura.
  String get fotoUrl => fotoUrls.first;

  /// Kilometraje capturado como dato estructurado cuando `tipo` es
  /// [TipoEvidencia.tablero] — además de la foto, no en su lugar.
  final double? km;

  /// FK a `solicitudes_autorizacion` — `null` si la evidencia es "suelta"
  /// (no asociada a ninguna solicitud), ya sea porque el tipo no lo
  /// requiere o porque el chofer eligió "vincular después".
  final String? folioId;

  /// FK opcional directa a la carga puntual que este comprobante respalda
  /// — distinto de [folioId] (que apunta a la SOLICITUD, que puede tener
  /// varias cargas). `null` hasta que exista el flujo de UI para
  /// capturarlo — hoy nada lo llena todavía.
  final String? cargaId;

  /// `true` cuando el chofer explícitamente pospuso vincular esta
  /// evidencia a una solicitud (ver [folioId] == null); permite que el
  /// admin o el propio chofer la encuentren luego como pendiente.
  final bool pendienteVincular;
  final String? notas;
  final DateTime creadaEn;

  /// Datos estructurados del comprobante — solo presentes cuando `tipo`
  /// es [TipoEvidencia.comprobante]. Se capturan además de la foto (no en
  /// su lugar) porque Finanzas necesita el monto/litros REALES pagados,
  /// no un estimado calculado en `solicitudes_autorizacion`.
  final String? tipoCombustibleCargado;
  final double? litros;
  final double? precioPorLitro;
  final double? montoPagado;

  /// `true` si [precioPorLitro] se desvió más del umbral configurado
  /// respecto al precio de referencia vigente al momento de subir esta
  /// evidencia — no bloqueante, solo la marca para revisión posterior del
  /// admin (el precio sí varía legítimamente por estación y por día).
  final bool requiereRevision;

  /// El número, no solo el booleano — permite ajustar el umbral después
  /// sin recalcular contra precios que ya cambiaron.
  final double? desviacionPrecioPorcentaje;

  /// El precio de referencia contra el que se comparó al momento de
  /// subir la evidencia.
  final double? precioReferenciaComparado;

  Evidencia copyWith({
    String? id,
    String? usuarioId,
    TipoEvidencia? tipo,
    List<String>? fotoUrls,
    double? km,
    String? folioId,
    String? cargaId,
    bool? pendienteVincular,
    String? notas,
    DateTime? creadaEn,
    String? tipoCombustibleCargado,
    double? litros,
    double? precioPorLitro,
    double? montoPagado,
    bool? requiereRevision,
    double? desviacionPrecioPorcentaje,
    double? precioReferenciaComparado,
  }) {
    return Evidencia(
      id: id ?? this.id,
      usuarioId: usuarioId ?? this.usuarioId,
      tipo: tipo ?? this.tipo,
      fotoUrls: fotoUrls ?? this.fotoUrls,
      km: km ?? this.km,
      folioId: folioId ?? this.folioId,
      cargaId: cargaId ?? this.cargaId,
      pendienteVincular: pendienteVincular ?? this.pendienteVincular,
      notas: notas ?? this.notas,
      creadaEn: creadaEn ?? this.creadaEn,
      tipoCombustibleCargado: tipoCombustibleCargado ?? this.tipoCombustibleCargado,
      litros: litros ?? this.litros,
      precioPorLitro: precioPorLitro ?? this.precioPorLitro,
      montoPagado: montoPagado ?? this.montoPagado,
      requiereRevision: requiereRevision ?? this.requiereRevision,
      desviacionPrecioPorcentaje:
          desviacionPrecioPorcentaje ?? this.desviacionPrecioPorcentaje,
      precioReferenciaComparado:
          precioReferenciaComparado ?? this.precioReferenciaComparado,
    );
  }

  factory Evidencia.fromJson(Map<String, dynamic> json) {
    final fotoUrls = (json['fotoUrls'] as List?)?.cast<String>();
    return Evidencia(
      id: json['id'] as String,
      usuarioId: json['usuarioId'] as String,
      tipo: TipoEvidencia.values.byName(json['tipo'] as String),
      fotoUrls: fotoUrls != null && fotoUrls.isNotEmpty
          ? fotoUrls
          : [json['fotoUrl'] as String],
      km: (json['km'] as num?)?.toDouble(),
      folioId: json['folioId'] as String?,
      cargaId: json['cargaId'] as String?,
      pendienteVincular: json['pendienteVincular'] as bool? ?? false,
      notas: json['notas'] as String?,
      creadaEn: DateTime.parse(json['creadoEn'] as String),
      tipoCombustibleCargado: json['tipoCombustibleCargado'] as String?,
      litros: (json['litros'] as num?)?.toDouble(),
      precioPorLitro: (json['precioPorLitro'] as num?)?.toDouble(),
      montoPagado: (json['montoPagado'] as num?)?.toDouble(),
      requiereRevision: json['requiereRevision'] as bool? ?? false,
      desviacionPrecioPorcentaje:
          (json['desviacionPrecioPorcentaje'] as num?)?.toDouble(),
      precioReferenciaComparado:
          (json['precioReferenciaComparado'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'tipo': tipo.name,
      'fotoUrl': fotoUrl,
      'fotoUrls': fotoUrls,
      'km': km,
      'folioId': folioId,
      'cargaId': cargaId,
      'pendienteVincular': pendienteVincular,
      'notas': notas,
      'creadoEn': creadaEn.toIso8601String(),
      'tipoCombustibleCargado': tipoCombustibleCargado,
      'litros': litros,
      'precioPorLitro': precioPorLitro,
      'montoPagado': montoPagado,
      'requiereRevision': requiereRevision,
      'desviacionPrecioPorcentaje': desviacionPrecioPorcentaje,
      'precioReferenciaComparado': precioReferenciaComparado,
    };
  }
}
