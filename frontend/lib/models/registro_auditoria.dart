import 'package:flutter/foundation.dart';

/// Un registro de actividad administrativa (auditoría): quién hizo qué,
/// sobre qué entidad, y cuándo. Alimenta la pestaña "Auditoría" del panel
/// administrativo — ver `backend GET /auditoria`.
@immutable
class RegistroAuditoria {
  const RegistroAuditoria({
    required this.id,
    required this.usuarioId,
    required this.usuarioNombre,
    required this.accion,
    required this.entidad,
    required this.entidadId,
    this.detalle,
    required this.creadoEn,
  });

  final String id;
  final String usuarioId;
  final String usuarioNombre;

  /// Ej. "aprobó", "rechazó", "editó", "resolvió", "activó", "desactivó".
  final String accion;

  /// Ej. "solicitud", "vehiculo", "incidencia", "usuario".
  final String entidad;
  final String entidadId;

  /// Texto libre adicional (ej. motivo, campos cambiados).
  final String? detalle;
  final DateTime creadoEn;

  factory RegistroAuditoria.fromJson(Map<String, dynamic> json) {
    return RegistroAuditoria(
      id: json['id'] as String,
      usuarioId: json['usuarioId'] as String,
      usuarioNombre: json['usuarioNombre'] as String,
      accion: json['accion'] as String,
      entidad: json['entidad'] as String,
      entidadId: json['entidadId'] as String,
      detalle: json['detalle'] as String?,
      creadoEn: DateTime.parse(json['creadoEn'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'usuarioId': usuarioId,
      'usuarioNombre': usuarioNombre,
      'accion': accion,
      'entidad': entidad,
      'entidadId': entidadId,
      'detalle': detalle,
      'creadoEn': creadoEn.toIso8601String(),
    };
  }
}
