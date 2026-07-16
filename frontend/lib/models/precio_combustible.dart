import 'package:flutter/foundation.dart';

/// Precio vigente de un tipo de combustible, consultado por el panel
/// administrativo y usado como referencia al autorizar solicitudes.
///
/// Dato que vendrá del backend en el futuro; hoy solo existe vía mocks.
@immutable
class PrecioCombustible {
  const PrecioCombustible({
    required this.tipoCombustible,
    required this.precioPorLitro,
    required this.actualizadoEn,
  });

  final String tipoCombustible;
  final double precioPorLitro;
  final DateTime actualizadoEn;

  PrecioCombustible copyWith({
    String? tipoCombustible,
    double? precioPorLitro,
    DateTime? actualizadoEn,
  }) {
    return PrecioCombustible(
      tipoCombustible: tipoCombustible ?? this.tipoCombustible,
      precioPorLitro: precioPorLitro ?? this.precioPorLitro,
      actualizadoEn: actualizadoEn ?? this.actualizadoEn,
    );
  }

  factory PrecioCombustible.fromJson(Map<String, dynamic> json) {
    return PrecioCombustible(
      tipoCombustible: json['tipoCombustible'] as String,
      precioPorLitro: (json['precioPorLitro'] as num).toDouble(),
      actualizadoEn: DateTime.parse(json['actualizadoEn'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipoCombustible': tipoCombustible,
      'precioPorLitro': precioPorLitro,
      'actualizadoEn': actualizadoEn.toIso8601String(),
    };
  }
}
