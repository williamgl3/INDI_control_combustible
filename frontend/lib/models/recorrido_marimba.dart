import 'package:flutter/foundation.dart';

enum EstadoRecorridoMarimba { abierto, cerrado }

/// Una jornada de despacho de la marimba: agrupa N [DespachoMarimba] bajo
/// un encabezado con litros iniciales, ubicación/frente y conciliación al
/// cierre (litros iniciales − suma de despachos). Ver diseño acordado:
/// resuelve la fricción de registrar despachos uno por uno sin ningún
/// contexto de jornada ni control de merma.
@immutable
class RecorridoMarimba {
  const RecorridoMarimba({
    required this.id,
    required this.marimbaId,
    required this.operadorId,
    required this.frente,
    this.cargaId,
    required this.litrosIniciales,
    this.kmInicio,
    this.kmCierre,
    this.horasEquipoMenorInicio,
    this.horasEquipoMenorCierre,
    this.estado = EstadoRecorridoMarimba.abierto,
    this.litrosDespachadosTotal,
    this.existenciaCalculada,
    this.diferenciaConciliacion,
    this.toleranciaUsada,
    this.requiereRevision = false,
    this.fotoCierrePath,
    required this.iniciadoEn,
    this.cerradoEn,
  });

  final String id;
  final String marimbaId;
  final String operadorId;

  /// Ubicación/frente donde opera este recorrido (ej. "BANCO EL
  /// HUIZACHITO") — también filtra el catálogo de máquinas destino en el
  /// selector de despacho (`vehiculo.ubicacion == frente`).
  final String frente;

  /// De qué carga (gasolinera/pipa) salió el combustible con el que
  /// arrancó este recorrido — trazabilidad hacia `Carga`, informativo.
  final String? cargaId;

  final double litrosIniciales;
  final double? kmInicio;
  final double? kmCierre;
  final double? horasEquipoMenorInicio;
  final double? horasEquipoMenorCierre;
  final EstadoRecorridoMarimba estado;

  /// Snapshot de conciliación — todos `null` mientras el recorrido sigue
  /// `abierto`; se llenan de una sola vez al cerrar y no se recalculan
  /// después (ver `recorridosMarimbaService.cerrarRecorrido` en backend).
  final double? litrosDespachadosTotal;
  final double? existenciaCalculada;
  final double? diferenciaConciliacion;
  final double? toleranciaUsada;

  /// `true` si [diferenciaConciliacion] excedió la tolerancia vigente al
  /// cerrar — señal para el panel admin, no bloquea el cierre.
  final bool requiereRevision;

  final String? fotoCierrePath;
  final DateTime iniciadoEn;
  final DateTime? cerradoEn;

  factory RecorridoMarimba.fromJson(Map<String, dynamic> json) {
    return RecorridoMarimba(
      id: json['id'] as String,
      marimbaId: json['marimbaId'] as String,
      operadorId: json['operadorId'] as String,
      frente: json['frente'] as String,
      cargaId: json['cargaId'] as String?,
      litrosIniciales: (json['litrosIniciales'] as num).toDouble(),
      kmInicio: (json['kmInicio'] as num?)?.toDouble(),
      kmCierre: (json['kmCierre'] as num?)?.toDouble(),
      horasEquipoMenorInicio: (json['horasEquipoMenorInicio'] as num?)
          ?.toDouble(),
      horasEquipoMenorCierre: (json['horasEquipoMenorCierre'] as num?)
          ?.toDouble(),
      estado: json['estado'] == 'cerrado'
          ? EstadoRecorridoMarimba.cerrado
          : EstadoRecorridoMarimba.abierto,
      litrosDespachadosTotal: (json['litrosDespachadosTotal'] as num?)
          ?.toDouble(),
      existenciaCalculada: (json['existenciaCalculada'] as num?)?.toDouble(),
      diferenciaConciliacion: (json['diferenciaConciliacion'] as num?)
          ?.toDouble(),
      toleranciaUsada: (json['toleranciaUsada'] as num?)?.toDouble(),
      requiereRevision: json['requiereRevision'] as bool? ?? false,
      fotoCierrePath: json['fotoCierrePath'] as String?,
      iniciadoEn: DateTime.parse(json['iniciadoEn'] as String),
      cerradoEn: json['cerradoEn'] == null
          ? null
          : DateTime.parse(json['cerradoEn'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marimbaId': marimbaId,
      'operadorId': operadorId,
      'frente': frente,
      'cargaId': cargaId,
      'litrosIniciales': litrosIniciales,
      'kmInicio': kmInicio,
      'kmCierre': kmCierre,
      'horasEquipoMenorInicio': horasEquipoMenorInicio,
      'horasEquipoMenorCierre': horasEquipoMenorCierre,
      'estado': estado.name,
      'litrosDespachadosTotal': litrosDespachadosTotal,
      'existenciaCalculada': existenciaCalculada,
      'diferenciaConciliacion': diferenciaConciliacion,
      'toleranciaUsada': toleranciaUsada,
      'requiereRevision': requiereRevision,
      'fotoCierrePath': fotoCierrePath,
      'iniciadoEn': iniciadoEn.toIso8601String(),
      'cerradoEn': cerradoEn?.toIso8601String(),
    };
  }
}
