import 'recorrido_marimba.dart';

class ResumenUnidadMarimba {
  const ResumenUnidadMarimba({
    required this.id,
    required this.tipoUnidad,
    this.placas,
    this.numeroEconomico,
    this.modelo,
    required this.activo,
    this.recorridoAbiertoId,
    this.responsableId,
    this.responsableNombre,
    this.fechaApertura,
    this.saldoMagna,
    this.saldoDiesel,
    this.ultimaActividad,
    required this.requiereRevision,
  });

  final String id;
  final String tipoUnidad;
  final String? placas;
  final String? numeroEconomico;
  final String? modelo;
  final bool activo;
  final String? recorridoAbiertoId;
  final String? responsableId;
  final String? responsableNombre;
  final DateTime? fechaApertura;
  final String? saldoMagna;
  final String? saldoDiesel;
  final DateTime? ultimaActividad;
  final bool requiereRevision;

  factory ResumenUnidadMarimba.fromJson(Map<String, dynamic> json) =>
      ResumenUnidadMarimba(
        id: json['id'] as String,
        tipoUnidad: json['tipoUnidad'] as String,
        placas: json['placas'] as String?,
        numeroEconomico: json['numeroEconomico'] as String?,
        modelo: json['modelo'] as String?,
        activo: json['activo'] as bool,
        recorridoAbiertoId: json['recorridoAbiertoId'] as String?,
        responsableId: json['responsableId'] as String?,
        responsableNombre: json['responsableNombre'] as String?,
        fechaApertura: _fecha(json['fechaApertura']),
        saldoMagna: json['saldoMagna']?.toString(),
        saldoDiesel: json['saldoDiesel']?.toString(),
        ultimaActividad: _fecha(json['ultimaActividad']),
        requiereRevision: json['requiereRevision'] as bool? ?? false,
      );
}

class PaginaRecorridosMarimba {
  const PaginaRecorridosMarimba({
    required this.items,
    required this.total,
    required this.page,
    required this.limit,
    required this.totalPages,
  });

  final List<RecorridoMarimba> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  factory PaginaRecorridosMarimba.fromJson(Map<String, dynamic> json) =>
      PaginaRecorridosMarimba(
        items: (json['items'] as List)
            .map(
              (item) => RecorridoMarimba.fromJson(item as Map<String, dynamic>),
            )
            .toList(growable: false),
        total: json['total'] as int,
        page: json['page'] as int,
        limit: json['limit'] as int,
        totalPages: json['totalPages'] as int,
      );
}

class FiltrosRecorridosMarimba {
  const FiltrosRecorridosMarimba({
    this.marimbaId,
    this.categoria,
    this.tipoCombustible,
    this.estado,
    this.responsableId,
    this.requiereRevision,
    this.fechaDesde,
    this.fechaHasta,
    this.page = 1,
    this.limit = 25,
  });

  final String? marimbaId;
  final String? categoria;
  final String? tipoCombustible;
  final String? estado;
  final String? responsableId;
  final bool? requiereRevision;
  final DateTime? fechaDesde;
  final DateTime? fechaHasta;
  final int page;
  final int limit;

  FiltrosRecorridosMarimba copyWith({int? page}) => FiltrosRecorridosMarimba(
    marimbaId: marimbaId,
    categoria: categoria,
    tipoCombustible: tipoCombustible,
    estado: estado,
    responsableId: responsableId,
    requiereRevision: requiereRevision,
    fechaDesde: fechaDesde,
    fechaHasta: fechaHasta,
    page: page ?? this.page,
    limit: limit,
  );

  @override
  bool operator ==(Object other) =>
      other is FiltrosRecorridosMarimba &&
      marimbaId == other.marimbaId &&
      categoria == other.categoria &&
      tipoCombustible == other.tipoCombustible &&
      estado == other.estado &&
      responsableId == other.responsableId &&
      requiereRevision == other.requiereRevision &&
      fechaDesde == other.fechaDesde &&
      fechaHasta == other.fechaHasta &&
      page == other.page &&
      limit == other.limit;

  @override
  int get hashCode => Object.hash(
    marimbaId,
    categoria,
    tipoCombustible,
    estado,
    responsableId,
    requiereRevision,
    fechaDesde,
    fechaHasta,
    page,
    limit,
  );
}

DateTime? _fecha(Object? valor) =>
    valor == null ? null : DateTime.parse(valor as String);
