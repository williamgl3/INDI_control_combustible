import 'package:flutter/foundation.dart';

/// Sentinel de `Vehiculo.copyWith` — distingue "parámetro omitido" de
/// "`null` explícito" para los campos donde `??` no alcanza.
const Object _sinTocar = Object();

/// Un vehículo o maquinaria del catálogo compartido de la obra —
/// administrado por el área administrativa, no por cada chofer.
///
/// Varios choferes pueden usar la misma unidad en días distintos (y un
/// mismo chofer puede usar unidades distintas), así que el vehículo ya
/// NO vive embebido en el [Perfil] del chofer: se elige en cada
/// solicitud/comprobación de carga.
@immutable
class Vehiculo {
  const Vehiculo({
    required this.id,
    required this.tipoUnidad,
    required this.placas,
    required this.numeroEconomico,
    required this.tipoCombustible,
    required this.intervaloServicio,
    this.modelo,
    this.lecturaUltimoServicio,
    this.fechaUltimoServicio,
    this.activo = true,
    this.unidadPadreId,
    this.ubicacion,
  }) : assert(
         placas != null || numeroEconomico != null,
         'Toda unidad necesita placas o número económico (o ambos).',
       );

  final String id;

  /// Ej. "Vehículo", "Marimba", "Maquinaria".
  final String tipoUnidad;

  /// Placa física — `null` en maquinaria pesada (no circula por
  /// carretera, se identifica solo por [numeroEconomico]).
  final String? placas;

  /// Número económico interno (GAMI) — `null` en vehículo ligero puro.
  /// La marimba tiene AMBOS (circula por carretera y además lleva
  /// económico de control interno).
  final String? numeroEconomico;

  /// Identificador único para mostrar al usuario: [numeroEconomico] si
  /// existe, si no [placas]. Toda unidad tiene al menos uno (ver el
  /// `assert` del constructor y `chk_identificador` en la base de
  /// datos) — nunca hace falta un fallback de "sin identificador".
  ///
  /// Úsala en cualquier pantalla/listado/exportación que hoy muestre
  /// placas — es la ÚNICA fuente de esta decisión, no repitas
  /// `numeroEconomico ?? placas` en otro lado.
  String get etiquetaUnidad => numeroEconomico ?? placas!;

  /// Para pantallas de detalle de la marimba (la única unidad con AMBOS
  /// datos): "económico · placa" en vez de solo el principal. `null` si
  /// la unidad solo tiene uno de los dos (nada que combinar).
  String? get etiquetaCompleta => (placas != null && numeroEconomico != null)
      ? '$numeroEconomico · $placas'
      : null;

  /// Ej. "Diésel", "Magna", "Premium". `null` si aún no se confirma con
  /// el cliente (ej. maquinaria pesada recién importada).
  final String? tipoCombustible;

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

  /// `false` si el administrativo lo desactivó (soft-delete) — deja de
  /// ofrecerse en [SelectorVehiculo] pero conserva su historial de
  /// solicitudes/cargas.
  final bool activo;

  /// Unidad de la que esta fila es accesorio/sub-unidad (ej. el equipo
  /// menor de gasolina de una marimba) — `null` en toda unidad "normal".
  /// Se modela como otra fila de [Vehiculo] en vez de agregar un segundo
  /// combustible/métrica a esta misma fila (ver migración 0025), así que
  /// cada fila sigue siendo "1 combustible + 1 métrica" sin excepciones.
  final String? unidadPadreId;

  /// Frente/banco donde opera hoy (ej. "BANCO EL HUIZACHITO") — filtra el
  /// catálogo de máquinas destino al capturar despachos de marimba por
  /// recorrido (ver `RecorridoMarimba.frente`). `null` si no se ha
  /// asignado.
  final String? ubicacion;

  /// `placas`/`numeroEconomico`/`tipoCombustible` distinguen "no lo
  /// toques" (parámetro omitido) de "bórralo" (`null` explícito) —
  /// necesario para cuando el admin cambia de categoría (ej. Marimba →
  /// Maquinaria) y `placas` debe quedar en `null`, no conservar el valor
  /// anterior. Un `??` normal no puede representar "pon esto en null a
  /// propósito", por eso usan `Object?` + sentinel en vez de `String?` +
  /// `??` como el resto de los campos.
  Vehiculo copyWith({
    String? id,
    String? tipoUnidad,
    Object? placas = _sinTocar,
    Object? numeroEconomico = _sinTocar,
    Object? tipoCombustible = _sinTocar,
    String? modelo,
    double? intervaloServicio,
    double? lecturaUltimoServicio,
    DateTime? fechaUltimoServicio,
    bool? activo,
    Object? unidadPadreId = _sinTocar,
    Object? ubicacion = _sinTocar,
  }) {
    return Vehiculo(
      id: id ?? this.id,
      tipoUnidad: tipoUnidad ?? this.tipoUnidad,
      placas: identical(placas, _sinTocar) ? this.placas : placas as String?,
      numeroEconomico: identical(numeroEconomico, _sinTocar)
          ? this.numeroEconomico
          : numeroEconomico as String?,
      tipoCombustible: identical(tipoCombustible, _sinTocar)
          ? this.tipoCombustible
          : tipoCombustible as String?,
      modelo: modelo ?? this.modelo,
      intervaloServicio: intervaloServicio ?? this.intervaloServicio,
      lecturaUltimoServicio:
          lecturaUltimoServicio ?? this.lecturaUltimoServicio,
      fechaUltimoServicio: fechaUltimoServicio ?? this.fechaUltimoServicio,
      activo: activo ?? this.activo,
      unidadPadreId: identical(unidadPadreId, _sinTocar)
          ? this.unidadPadreId
          : unidadPadreId as String?,
      ubicacion: identical(ubicacion, _sinTocar)
          ? this.ubicacion
          : ubicacion as String?,
    );
  }

  factory Vehiculo.fromJson(Map<String, dynamic> json) {
    final placas = json['placas'] as String?;
    final numeroEconomico = json['numeroEconomico'] as String?;
    if ((placas == null || placas.trim().isEmpty) &&
        (numeroEconomico == null || numeroEconomico.trim().isEmpty)) {
      throw const FormatException(
        'Contrato de unidad inválido: falta un identificador.',
      );
    }
    if (!json.containsKey('activo') || json['activo'] is! bool) {
      throw const FormatException(
        'Contrato de unidad inválido: el estado activo es obligatorio.',
      );
    }
    return Vehiculo(
      id: json['id'] as String,
      tipoUnidad: json['tipoUnidad'] as String,
      placas: placas,
      numeroEconomico: numeroEconomico,
      tipoCombustible: json['tipoCombustible'] as String?,
      modelo: json['modelo'] as String?,
      intervaloServicio: (json['intervaloServicio'] as num).toDouble(),
      lecturaUltimoServicio: (json['lecturaUltimoServicio'] as num?)
          ?.toDouble(),
      fechaUltimoServicio: json['fechaUltimoServicio'] == null
          ? null
          : DateTime.parse(json['fechaUltimoServicio'] as String),
      activo: json['activo'] as bool,
      unidadPadreId: json['unidadPadreId'] as String?,
      ubicacion: json['ubicacion'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipoUnidad': tipoUnidad,
      'placas': placas,
      'numeroEconomico': numeroEconomico,
      'tipoCombustible': tipoCombustible,
      'modelo': modelo,
      'intervaloServicio': intervaloServicio,
      'lecturaUltimoServicio': lecturaUltimoServicio,
      'fechaUltimoServicio': fechaUltimoServicio?.toIso8601String(),
      'activo': activo,
      'unidadPadreId': unidadPadreId,
      'ubicacion': ubicacion,
    };
  }

  @override
  bool operator ==(Object other) {
    return other is Vehiculo &&
        other.id == id &&
        other.tipoUnidad == tipoUnidad &&
        other.placas == placas &&
        other.numeroEconomico == numeroEconomico &&
        other.tipoCombustible == tipoCombustible &&
        other.modelo == modelo &&
        other.intervaloServicio == intervaloServicio &&
        other.lecturaUltimoServicio == lecturaUltimoServicio &&
        other.fechaUltimoServicio == fechaUltimoServicio &&
        other.activo == activo &&
        other.unidadPadreId == unidadPadreId &&
        other.ubicacion == ubicacion;
  }

  @override
  int get hashCode => Object.hash(
    id,
    tipoUnidad,
    placas,
    numeroEconomico,
    tipoCombustible,
    modelo,
    intervaloServicio,
    lecturaUltimoServicio,
    fechaUltimoServicio,
    activo,
    unidadPadreId,
    ubicacion,
  );
}
