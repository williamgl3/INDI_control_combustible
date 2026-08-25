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

  /// Puede ser nulo para eventos de sistema o cuando la cuenta autora ya
  /// no existe. La bitácora debe seguir siendo legible en ambos casos.
  final String? usuarioId;
  final String? usuarioNombre;

  /// Ej. "aprobó", "rechazó", "editó", "resolvió", "activó", "desactivó".
  final String accion;

  /// Ej. "solicitud", "vehiculo", "incidencia", "usuario".
  final String entidad;
  final String? entidadId;

  /// Detalle adicional del cambio. En los datos de ejemplo (mocks) es un
  /// texto ya redactado ("Autorizó 40 L de los 45 L solicitados."); del
  /// backend real llega como el objeto JSON crudo que se guardó al
  /// momento de auditar (ej. `{nuevoPrecio: 26.9}`,
  /// `{anterior: {...}, nuevo: {...}}`) — ver [detalleLegible] para
  /// convertirlo a texto mostrable sin que la UI tenga que conocer la
  /// forma de cada acción.
  final Object? detalle;
  final DateTime creadoEn;

  factory RegistroAuditoria.fromJson(Map<String, dynamic> json) {
    return RegistroAuditoria(
      id: json['id'] as String,
      usuarioId: json['usuarioId'] as String?,
      usuarioNombre: json['usuarioNombre'] as String?,
      accion: json['accion'] as String,
      entidad: json['entidad'] as String,
      entidadId: json['entidadId'] as String?,
      detalle: json['detalle'],
      creadoEn: DateTime.parse(json['creadoEn'] as String),
    );
  }

  String get usuarioNombreLegible => usuarioNombre?.trim().isNotEmpty == true
      ? usuarioNombre!.trim()
      : 'Usuario eliminado o sistema';

  /// Versión mostrable de [detalle] — si ya es texto (mocks), se muestra
  /// tal cual; si es el objeto JSON del backend real, se arma una frase
  /// según [accion] (valor anterior/nuevo cuando aplica). `null`/vacío si
  /// no hay nada que mostrar.
  String get detalleLegible {
    final d = detalle;
    if (d == null) return '';
    if (d is String) return d;
    if (d is! Map) return d.toString();
    final mapa = Map<String, dynamic>.from(d);

    switch (accion) {
      case 'editar_carga':
        final anterior = mapa['anterior'] as Map?;
        final nuevo = mapa['nuevo'] as Map?;
        if (anterior == null || nuevo == null) return '';
        final partes = <String>[];
        if (anterior['litrosCargados'] != nuevo['litrosCargados']) {
          partes.add(
            'Litros: ${anterior['litrosCargados']} → ${nuevo['litrosCargados']}',
          );
        }
        if (anterior['kmAlCargar'] != nuevo['kmAlCargar']) {
          partes.add('Km: ${anterior['kmAlCargar']} → ${nuevo['kmAlCargar']}');
        }
        return partes.join(', ');
      case 'editar_precio':
        return 'Nuevo precio: \$${mapa['nuevoPrecio']} / L';
      case 'editar_presupuesto_semanal':
        return 'Nuevo presupuesto semanal: \$${mapa['nuevoValor']}';
      case 'aprobar_solicitud':
      case 'rechazar_solicitud':
        final litros = mapa['litrosAutorizados'];
        final motivo = mapa['motivo'];
        final folio = mapa['folio'];
        final partes = <String>[
          if (litros != null) 'Autorizó $litros L',
          if (folio != null) 'Folio $folio',
          if (motivo != null) '$motivo',
        ];
        return partes.join(' · ');
      case 'resolver_incidencia':
        return (mapa['comentario'] as String?) ?? '';
      case 'editar_vehiculo':
        final cambios = mapa['cambios'] as Map?;
        if (cambios == null || cambios.isEmpty) return '';
        return cambios.entries.map((e) => '${e.key}: ${e.value}').join(', ');
      case 'registrar_servicio_mantenimiento':
        return 'Lectura registrada: ${mapa['lectura']}';
      default:
        return mapa.entries.map((e) => '${e.key}: ${e.value}').join(', ');
    }
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
