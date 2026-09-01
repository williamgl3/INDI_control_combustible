import 'package:flutter/foundation.dart';

import 'carga.dart';
import 'cierre_dia.dart';

/// Estadísticas agregadas de carga para un vehículo en un día específico.
/// Se calcula en tiempo real a partir de las [Carga]s y [CierreDia] del día,
/// no se persiste en backend.
@immutable
class EstadisticaCargaDia {
  const EstadisticaCargaDia({
    required this.vehiculoId,
    required this.fecha,
    required this.totalCargas,
    required this.litrosTotales,
    required this.cargas,
    this.kmRecorridos,
    this.rendimiento,
    this.esAnomalo = false,
  });

  final String vehiculoId;
  final DateTime fecha;
  final int totalCargas;
  final double litrosTotales;

  /// Lista ordenada cronológicamente de cada carga individual del día.
  final List<Carga> cargas;

  /// Kilómetros recorridos entre la primera carga y el último cierre del día.
  /// `null` si aún no hay cierre registrado.
  final double? kmRecorridos;

  /// km/L promedio del día. `null` si no se puede calcular (sin cierre o
  /// km recorridos = 0).
  final double? rendimiento;

  /// `true` si el rendimiento está fuera de los umbrales normales (< 2 o > 15
  /// km/L), indicando posible dato inconsistente.
  final bool esAnomalo;

  /// Construye [EstadisticaCargaDia] a partir de las cargas y cierres
  /// filtrados para un vehículo y fecha específicos.
  ///
  /// [cargas] debe estar ordenada cronológicamente ascendente.
  /// [cierres] se matchea por [CierreDia.cargaId].
  factory EstadisticaCargaDia.desdeRegistros({
    required String vehiculoId,
    required DateTime fecha,
    required List<Carga> cargas,
    required List<CierreDia> cierres,
  }) {
    if (cargas.isEmpty) {
      return EstadisticaCargaDia._vacio(vehiculoId, fecha);
    }

    final litrosTotales = cargas.fold<double>(
      0,
      (suma, c) => suma + c.litrosCargados,
    );

    // Para calcular rendimiento, tomamos la primera carga y el último cierre
    // que la referencia.
    double? kmRecorridos;
    double? rendimiento;
    bool esAnomalo = false;

    final primeraCarga = cargas.first;
    final cierresPorCarga = <String, CierreDia>{
      for (final c in cierres) c.cargaId: c,
    };

    final cierre = cierresPorCarga[primeraCarga.id];
    if (cierre != null) {
      kmRecorridos = cierre.kmFinal - primeraCarga.kmAlCargar;
      if (kmRecorridos > 0 && litrosTotales > 0) {
        rendimiento = kmRecorridos / litrosTotales;
        esAnomalo = rendimiento < 2 || rendimiento > 15;
      }
    }

    return EstadisticaCargaDia(
      vehiculoId: vehiculoId,
      fecha: fecha,
      totalCargas: cargas.length,
      litrosTotales: litrosTotales,
      cargas: List.unmodifiable(cargas),
      kmRecorridos: kmRecorridos,
      rendimiento: rendimiento,
      esAnomalo: esAnomalo,
    );
  }

  factory EstadisticaCargaDia._vacio(String vehiculoId, DateTime fecha) {
    return EstadisticaCargaDia(
      vehiculoId: vehiculoId,
      fecha: fecha,
      totalCargas: 0,
      litrosTotales: 0,
      cargas: const [],
    );
  }

  bool get isEmpty => totalCargas == 0;
}
