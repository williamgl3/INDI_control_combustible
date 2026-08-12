import 'package:flutter/foundation.dart';

enum EstadoDespacho { activo, inactivo }

/// Un despacho de combustible de la marimba hacia una unidad de
/// maquinaria en campo — la SALIDA del libro mayor de saldo de la
/// marimba (ver `saldoActual` en `DespachosMarimbaRepository`). La
/// ENTRADA sigue siendo una [Carga] normal de un [Vehiculo] con
/// `tipoUnidad == 'Marimba'`.
@immutable
class DespachoMarimba {
  const DespachoMarimba({
    required this.id,
    required this.marimbaId,
    this.vehiculoDestinoId,
    this.destinoTexto,
    required this.operadorTexto,
    this.residenteTexto,
    this.sitio,
    this.litrosSolicitados,
    required this.litrosSuministrados,
    this.lecturaMedidor,
    this.precioReferenciaUsado,
    this.estado = EstadoDespacho.activo,
    this.fotoEvidenciaPath,
    required this.registradoPor,
    required this.creadoEn,
    this.recorridoId,
    this.responsableId,
    this.horometro,
    this.fotoHorometroPath,
    this.medidorInicial,
    this.medidorFinal,
    this.fotoMedidorPath,
    this.cantidadDeclarada,
    this.tipoCombustible,
    this.ubicacion,
    this.observaciones,
  });

  final String id;
  final String marimbaId;

  /// Unidad destino del catálogo de vehículos, si ya está formalizada.
  final String? vehiculoDestinoId;

  /// Respaldo en texto libre cuando la unidad aún no está en el catálogo
  /// (o para no bloquear la captura en campo por eso).
  final String? destinoTexto;

  /// Quién recibe el combustible — texto libre, sin cuenta en la app.
  final String operadorTexto;

  /// Segundo responsable del formato en papel — también texto libre.
  final String? residenteTexto;

  /// `null` cuando el despacho pertenece a un recorrido (se hereda del
  /// frente del recorrido, ver [recorridoId]) — obligatorio solo en un
  /// despacho suelto, sin recorrido.
  final String? sitio;

  /// Lo que se pidió vs. lo realmente entregado — la diferencia es
  /// información real (falta de saldo, ajuste del repartidor).
  final double? litrosSolicitados;
  final double litrosSuministrados;

  /// Horómetro/km de la unidad destino al momento del despacho — sin
  /// formato ni rango forzado (varía mucho entre tipos de maquinaria).
  final double? lecturaMedidor;

  /// Snapshot del precio de referencia de Finanzas al momento del
  /// despacho — puramente informativo (atribución de costo), nunca se
  /// suma al gasto real (que vive solo en la carga de la marimba).
  final double? precioReferenciaUsado;

  /// `inactivo` cubre el caso real de una unidad considerada ese día
  /// pero sin despacho (0 L) — se registra igual, sin mover el saldo.
  final EstadoDespacho estado;

  final String? fotoEvidenciaPath;
  final String registradoPor;
  final DateTime creadoEn;

  /// Recorrido (jornada) al que pertenece este despacho — `null` en un
  /// despacho suelto, sin pasar por el flujo de recorrido.
  final String? recorridoId;
  final String? responsableId;
  final double? horometro;
  final String? fotoHorometroPath;
  final double? medidorInicial;
  final double? medidorFinal;
  final String? fotoMedidorPath;
  final bool? cantidadDeclarada;
  final String? tipoCombustible;
  final String? ubicacion;
  final String? observaciones;

  /// Diferencia entre lo pedido y lo suministrado — `null` si no se
  /// capturó lo solicitado.
  double? get diferenciaLitros => litrosSolicitados == null
      ? null
      : litrosSolicitados! - litrosSuministrados;

  factory DespachoMarimba.fromJson(Map<String, dynamic> json) {
    return DespachoMarimba(
      id: json['id'] as String,
      marimbaId: json['marimbaId'] as String,
      vehiculoDestinoId: json['vehiculoDestinoId'] as String?,
      destinoTexto: json['destinoTexto'] as String?,
      operadorTexto: json['operadorTexto'] as String,
      residenteTexto: json['residenteTexto'] as String?,
      sitio: json['sitio'] as String?,
      litrosSolicitados: (json['litrosSolicitados'] as num?)?.toDouble(),
      litrosSuministrados: _decimalDespacho(json['litrosSuministrados']),
      lecturaMedidor: (json['lecturaMedidor'] as num?)?.toDouble(),
      precioReferenciaUsado: (json['precioReferenciaUsado'] as num?)
          ?.toDouble(),
      estado: json['estado'] == 'inactivo'
          ? EstadoDespacho.inactivo
          : EstadoDespacho.activo,
      fotoEvidenciaPath: json['fotoEvidenciaPath'] as String?,
      registradoPor: json['registradoPor'] as String,
      creadoEn: DateTime.parse(json['creadoEn'] as String),
      recorridoId: json['recorridoId'] as String?,
      responsableId: json['responsableId'] as String?,
      horometro: (json['horometro'] as num?)?.toDouble(),
      fotoHorometroPath: json['fotoHorometroPath'] as String?,
      medidorInicial: (json['medidorInicial'] as num?)?.toDouble(),
      medidorFinal: (json['medidorFinal'] as num?)?.toDouble(),
      fotoMedidorPath: json['fotoMedidorPath'] as String?,
      cantidadDeclarada: json['cantidadDeclarada'] as bool?,
      tipoCombustible: json['tipoCombustible'] as String?,
      ubicacion: json['ubicacion'] as String?,
      observaciones: json['observaciones'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'marimbaId': marimbaId,
      'vehiculoDestinoId': vehiculoDestinoId,
      'destinoTexto': destinoTexto,
      'operadorTexto': operadorTexto,
      'residenteTexto': residenteTexto,
      'sitio': sitio,
      'litrosSolicitados': litrosSolicitados,
      'litrosSuministrados': litrosSuministrados,
      'lecturaMedidor': lecturaMedidor,
      'precioReferenciaUsado': precioReferenciaUsado,
      'estado': estado.name,
      'fotoEvidenciaPath': fotoEvidenciaPath,
      'registradoPor': registradoPor,
      'creadoEn': creadoEn.toIso8601String(),
      'recorridoId': recorridoId,
      'responsableId': responsableId,
      'horometro': horometro,
      'fotoHorometroPath': fotoHorometroPath,
      'medidorInicial': medidorInicial,
      'medidorFinal': medidorFinal,
      'fotoMedidorPath': fotoMedidorPath,
      'cantidadDeclarada': cantidadDeclarada,
      'tipoCombustible': tipoCombustible,
      'ubicacion': ubicacion,
      'observaciones': observaciones,
    };
  }
}

double _decimalDespacho(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw const FormatException('Litros suministrados inválidos.');
}
