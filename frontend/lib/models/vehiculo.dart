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
    required this.intervaloServicio,
    this.modelo,
    this.lecturaUltimoServicio,
    this.fechaUltimoServicio,
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

  /// Cada cuántos km (o cuántas horas de horómetro, si
  /// `esUnidadPorHorometro(tipoUnidad)`) toca un servicio general
  /// mecánico. Trae un default por tipo de unidad (ver
  /// `intervaloServicioPorDefecto`) pero es editable por unidad.
  final double intervaloServicio;

  /// Lectura del medidor (km u horas) registrada en el último servicio.
  /// `null` si nunca se le ha registrado un servicio a esta unidad.
  final double? lecturaUltimoServicio;

  /// Fecha del último servicio registrado. `null` si nunca se le ha
  /// registrado uno.
  final DateTime? fechaUltimoServicio;

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
    double? intervaloServicio,
    double? lecturaUltimoServicio,
    DateTime? fechaUltimoServicio,
  }) {
    return Vehiculo(
      id: id ?? this.id,
      tipoUnidad: tipoUnidad ?? this.tipoUnidad,
      identificador: identificador ?? this.identificador,
      tipoCombustible: tipoCombustible ?? this.tipoCombustible,
      topeSemanal: topeSemanal ?? this.topeSemanal,
      modelo: modelo ?? this.modelo,
      intervaloServicio: intervaloServicio ?? this.intervaloServicio,
      lecturaUltimoServicio:
          lecturaUltimoServicio ?? this.lecturaUltimoServicio,
      fechaUltimoServicio: fechaUltimoServicio ?? this.fechaUltimoServicio,
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
      intervaloServicio: (json['intervaloServicio'] as num).toDouble(),
      lecturaUltimoServicio: (json['lecturaUltimoServicio'] as num?)
          ?.toDouble(),
      fechaUltimoServicio: json['fechaUltimoServicio'] == null
          ? null
          : DateTime.parse(json['fechaUltimoServicio'] as String),
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
      'intervaloServicio': intervaloServicio,
      'lecturaUltimoServicio': lecturaUltimoServicio,
      'fechaUltimoServicio': fechaUltimoServicio?.toIso8601String(),
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
        other.modelo == modelo &&
        other.intervaloServicio == intervaloServicio &&
        other.lecturaUltimoServicio == lecturaUltimoServicio &&
        other.fechaUltimoServicio == fechaUltimoServicio;
  }

  @override
  int get hashCode => Object.hash(
    id,
    tipoUnidad,
    identificador,
    tipoCombustible,
    topeSemanal,
    modelo,
    intervaloServicio,
    lecturaUltimoServicio,
    fechaUltimoServicio,
  );
}
