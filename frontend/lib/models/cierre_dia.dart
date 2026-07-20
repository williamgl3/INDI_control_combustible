import 'package:flutter/foundation.dart';

/// Registro 2 del día: se llena cuando el chofer termina de trabajar,
/// referenciando la [Carga] (registro 1) de ese mismo día para calcular
/// el kilometraje recorrido y el rendimiento.
///
/// [registradaEn] la pone el dispositivo automáticamente, igual que en
/// [Carga.creadaEn] — es el cierre de un registro de auditoría, no un
/// dato que el chofer pueda editar.
@immutable
class CierreDia {
  const CierreDia({
    required this.id,
    required this.choferId,
    required this.cargaId,
    required this.kmFinal,
    required this.fotoTableroPath,
    required this.registradaEn,
  });

  final String id;
  final String choferId;

  /// La [Carga] (registro 1) de ese mismo día contra la que se calcula
  /// el recorrido.
  final String cargaId;

  final double kmFinal;
  final String fotoTableroPath;
  final DateTime registradaEn;

  factory CierreDia.fromJson(Map<String, dynamic> json) {
    return CierreDia(
      id: json['id'] as String,
      choferId: json['choferId'] as String,
      cargaId: json['cargaId'] as String,
      kmFinal: (json['kmFinal'] as num).toDouble(),
      fotoTableroPath: json['fotoTableroPath'] as String,
      registradaEn: DateTime.parse(json['registradaEn'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'choferId': choferId,
      'cargaId': cargaId,
      'kmFinal': kmFinal,
      'fotoTableroPath': fotoTableroPath,
      'registradaEn': registradaEn.toIso8601String(),
    };
  }
}

/// Cálculos derivados de un cierre de día contra su [Carga] de
/// referencia. Se agrupan aquí (en vez de método en cada clase) porque
/// requieren ambos objetos a la vez.
class RendimientoDia {
  const RendimientoDia({required this.kmRecorridos, required this.rendimiento});

  final double kmRecorridos;

  /// Km recorridos ÷ litros cargados (km/L). `null` si [kmRecorridos] es
  /// 0 o negativo (dato inconsistente, no se puede calcular).
  final double? rendimiento;

  /// TODO-SPEC: umbrales de anomalía PLACEHOLDER — ajustar con datos
  /// reales de las unidades de la obra.
  bool get esAnomalo =>
      rendimiento != null && (rendimiento! < 2 || rendimiento! > 15);
}
