import 'package:flutter/foundation.dart';

/// Datos del vehículo/maquinaria de UN chofer, capturados una sola vez
/// durante /registro-chofer y embebidos permanentemente en su [Perfil].
///
/// No existe catálogo de vehículos para asignar: cada chofer registra
/// los datos de su propio vehículo, no se elige de una lista.
///
/// Dato que vendrá del backend en el futuro (hoy solo existe vía mocks
/// o lo que capture el formulario de registro).
@immutable
class Vehiculo {
  const Vehiculo({
    required this.tipoUnidad,
    required this.modelo,
    required this.placaONumeroEconomico,
    required this.tipoCombustible,
    required this.topeSemanal,
  });

  /// Ej. "camión", "maquinaria", "camioneta". TODO-SPEC: valores exactos
  /// permitidos pendientes de confirmar contra SPEC.md.
  final String tipoUnidad;

  final String modelo;

  final String placaONumeroEconomico;

  /// Ej. "diésel", "gasolina". TODO-SPEC: enum exacto pendiente de SPEC.md.
  final String tipoCombustible;

  /// Tope semanal de combustible/litros asignado a este vehículo.
  final double topeSemanal;

  Vehiculo copyWith({
    String? tipoUnidad,
    String? modelo,
    String? placaONumeroEconomico,
    String? tipoCombustible,
    double? topeSemanal,
  }) {
    return Vehiculo(
      tipoUnidad: tipoUnidad ?? this.tipoUnidad,
      modelo: modelo ?? this.modelo,
      placaONumeroEconomico: placaONumeroEconomico ?? this.placaONumeroEconomico,
      tipoCombustible: tipoCombustible ?? this.tipoCombustible,
      topeSemanal: topeSemanal ?? this.topeSemanal,
    );
  }

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      tipoUnidad: json['tipoUnidad'] as String,
      modelo: json['modelo'] as String,
      placaONumeroEconomico: json['placaONumeroEconomico'] as String,
      tipoCombustible: json['tipoCombustible'] as String,
      topeSemanal: (json['topeSemanal'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipoUnidad': tipoUnidad,
      'modelo': modelo,
      'placaONumeroEconomico': placaONumeroEconomico,
      'tipoCombustible': tipoCombustible,
      'topeSemanal': topeSemanal,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Vehiculo &&
        other.tipoUnidad == tipoUnidad &&
        other.modelo == modelo &&
        other.placaONumeroEconomico == placaONumeroEconomico &&
        other.tipoCombustible == tipoCombustible &&
        other.topeSemanal == topeSemanal;
  }

  @override
  int get hashCode => Object.hash(
        tipoUnidad,
        modelo,
        placaONumeroEconomico,
        tipoCombustible,
        topeSemanal,
      );
}
