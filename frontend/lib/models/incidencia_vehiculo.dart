import 'package:flutter/foundation.dart';

/// Estado de una [IncidenciaVehiculo].
enum EstadoIncidencia { abierta, resuelta }

/// Falla o incidencia reportada por un chofer sobre un vehículo (ej. "se
/// ponchó una llanta") — distinto del mantenimiento preventivo por km/
/// horómetro (`Vehiculo.intervaloServicio`), que es programado, no
/// reactivo a un problema real detectado en campo.
@immutable
class IncidenciaVehiculo {
  const IncidenciaVehiculo({
    required this.id,
    required this.vehiculoId,
    required this.choferId,
    required this.descripcion,
    required this.estado,
    required this.creadaEn,
    this.resueltaPor,
    this.comentarioResolucion,
    this.resueltaEn,
    this.fotoPath,
  });

  final String id;
  final String vehiculoId;
  final String choferId;
  final String descripcion;
  final EstadoIncidencia estado;
  final DateTime creadaEn;
  final String? resueltaPor;
  final String? comentarioResolucion;
  final DateTime? resueltaEn;

  /// Foto del daño/falla — opcional (no toda incidencia es fotografiable,
  /// ej. "ruido raro en el motor"), a diferencia de las fotos de
  /// carga/cierre que sí son obligatorias.
  final String? fotoPath;

  factory IncidenciaVehiculo.fromJson(Map<String, dynamic> json) {
    return IncidenciaVehiculo(
      id: json['id'] as String,
      vehiculoId: json['vehiculoId'] as String,
      choferId: json['choferId'] as String,
      descripcion: json['descripcion'] as String,
      estado: EstadoIncidencia.values.byName(json['estado'] as String),
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      resueltaPor: json['resueltaPor'] as String?,
      comentarioResolucion: json['comentarioResolucion'] as String?,
      resueltaEn: json['resueltaEn'] == null
          ? null
          : DateTime.parse(json['resueltaEn'] as String),
      fotoPath: json['fotoPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehiculoId': vehiculoId,
      'choferId': choferId,
      'descripcion': descripcion,
      'estado': estado.name,
      'creadaEn': creadaEn.toIso8601String(),
      'resueltaPor': resueltaPor,
      'comentarioResolucion': comentarioResolucion,
      'resueltaEn': resueltaEn?.toIso8601String(),
      'fotoPath': fotoPath,
    };
  }
}
