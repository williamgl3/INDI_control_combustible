import 'package:flutter/foundation.dart';

/// Un vehículo o maquinaria del catálogo compartido de la obra —
/// administrado por el área administrativa, no por cada chofer.
///
/// Varios choferes pueden usar la misma unidad en días distintos (y un
/// mismo chofer puede usar unidades distintas), así que el vehículo ya
/// NO vive embebido en el [Perfil] del chofer: se elige en cada
/// solicitud/comprobación de carga. El tope semanal es del vehículo, no
/// de la persona que lo maneja ese día.
///
/// Dato que vendrá del backend en el futuro (hoy solo existe vía mocks).
@immutable
class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.tipoUnidad,
    required this.identificador,
    required this.tipoCombustible,
    required this.topeSemanal,
    this.modelo,
  });

  final String id;

  /// Ej. "Vehículo", "Pipa", "Maquinaria". TODO-SPEC: valores exactos
  /// permitidos pendientes de confirmar contra SPEC.md.
  final String tipoUnidad;

  /// Placa, número económico, o una descripción libre si la unidad no
  /// tiene ninguno de los dos (ej. maquinaria sin placas: "Retroexcavadora
  /// amarilla frente norte").
  final String identificador;

  /// Ej. "Diésel", "Gasolina". TODO-SPEC: enum exacto pendiente de SPEC.md.
  final String tipoCombustible;

  /// Tope semanal de litros asignado a esta unidad. `0` significa "sin
  /// asignar todavía" — normalmente porque el chofer la reportó como
  /// unidad nueva y el administrativo aún no la formaliza (ver
  /// `MockVehiculosRepository.reportarNuevo`).
  final double topeSemanal;

  /// Descripción/modelo opcional (ej. "Chevrolet NPR 2020").
  final String? modelo;

  /// `true` mientras el administrativo no le haya asignado tope — es la
  /// señal de "reportada por un chofer, falta formalizar".
  bool get esNuevaSinFormalizar => topeSemanal <= 0;

  Vehiculo copyWith({
    String? id,
    String? tipoUnidad,
    String? identificador,
    String? tipoCombustible,
    double? topeSemanal,
    String? modelo,
  }) {
    return Vehiculo(
      id: id ?? this.id,
      tipoUnidad: tipoUnidad ?? this.tipoUnidad,
      identificador: identificador ?? this.identificador,
      tipoCombustible: tipoCombustible ?? this.tipoCombustible,
      topeSemanal: topeSemanal ?? this.topeSemanal,
      modelo: modelo ?? this.modelo,
    );
  }

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    return Vehiculo(
      id: json['id'] as String,
      tipoUnidad: json['tipoUnidad'] as String,
      identificador: json['identificador'] as String,
      tipoCombustible: json['tipoCombustible'] as String,
      topeSemanal: (json['topeSemanal'] as num).toDouble(),
      modelo: json['modelo'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipoUnidad': tipoUnidad,
      'identificador': identificador,
      'tipoCombustible': tipoCombustible,
      'topeSemanal': topeSemanal,
      'modelo': modelo,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Vehiculo &&
        other.id == id &&
        other.tipoUnidad == tipoUnidad &&
        other.identificador == identificador &&
        other.tipoCombustible == tipoCombustible &&
        other.topeSemanal == topeSemanal &&
        other.modelo == modelo;
  }

  @override
  int get hashCode =>
      Object.hash(id, tipoUnidad, identificador, tipoCombustible, topeSemanal, modelo);
}
