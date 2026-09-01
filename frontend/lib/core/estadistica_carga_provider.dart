import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/estadistica_carga_dia.dart';
import 'providers.dart';
import 'session_provider.dart';

/// Estadísticas de carga del día actual para el vehículo que el chofer
/// está usando hoy (o el último registrado). Se recalcula cada vez que
/// cambia el [operacionesTickProvider] (post-registro de carga / cierre).
final estadisticaCargaHoyProvider = Provider<EstadisticaCargaDia>((ref) {
  final perfil = ref.watch(sessionProvider);
  if (perfil == null) {
    return EstadisticaCargaDia.desdeRegistros(
      vehiculoId: '',
      fecha: DateTime.now(),
      cargas: const [],
      cierres: const [],
    );
  }

  final repo = ref.watch(operacionesRepositoryProvider);
  ref.watch(operacionesTickProvider);

  final cargasDelChofer = repo.cargasDeChofer(perfil.id);
  final cierresDelChofer = repo.cierresDeChofer(perfil.id);

  // Filtrar solo las cargas de hoy.
  final hoy = _soloFecha(DateTime.now());
  final cargasHoy = cargasDelChofer
      .where((c) => _soloFecha(c.creadaEn) == hoy)
      .toList()
    ..sort((a, b) => a.creadaEn.compareTo(b.creadaEn));

  if (cargasHoy.isEmpty) {
    return EstadisticaCargaDia.desdeRegistros(
      vehiculoId: '',
      fecha: hoy,
      cargas: const [],
      cierres: const [],
    );
  }

  // Usar el vehículo de la primera carga de hoy.
  final vehiculoId = cargasHoy.first.vehiculoId;

  // Filtrar cierres que referencian las cargas de hoy.
  final cargaIdsHoy = cargasHoy.map((c) => c.id).toSet();
  final cierresHoy = cierresDelChofer
      .where((c) => cargaIdsHoy.contains(c.cargaId))
      .toList();

  return EstadisticaCargaDia.desdeRegistros(
    vehiculoId: vehiculoId,
    fecha: hoy,
    cargas: cargasHoy,
    cierres: cierresHoy,
  );
});

DateTime _soloFecha(DateTime fecha) =>
    DateTime(fecha.year, fecha.month, fecha.day);
