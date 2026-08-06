import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'session_provider.dart';

/// Bandera de sesión (no persistida) que marca si el chofer ya subió al
/// menos una evidencia hoy. No existe todavía un endpoint para listar
/// evidencias del chofer, así que esto solo refleja lo que pasó desde
/// que se abrió la app — se pone en `true` justo después de que
/// [SubirEvidenciasScreen] guarda una evidencia con éxito.
final evidenciaSubidaHoyProvider = StateProvider<bool>((ref) => false);

/// Estado informativo de los 4 pasos del flujo diario del chofer — no
/// bloquea nada, solo indica qué ya se hizo hoy para [PasoDiarioStepper].
class PasoDiario {
  const PasoDiario({
    required this.unidad,
    required this.tablero,
    required this.solicitud,
    required this.evidencia,
  });

  final bool unidad;
  final bool tablero;
  final bool solicitud;
  final bool evidencia;
}

bool _esHoy(DateTime fecha) {
  final hoy = DateTime.now();
  return fecha.year == hoy.year &&
      fecha.month == hoy.month &&
      fecha.day == hoy.day;
}

/// Deriva [PasoDiario] de los datos ya disponibles en
/// [OperacionesRepository] (no hay un estado dedicado de "unidad
/// seleccionada" — se infiere de si hay una carga abierta hoy, igual que
/// hace `ChoferHomeScreen`) más la bandera local de evidencias.
final pasoDiarioProvider = Provider<PasoDiario>((ref) {
  final perfil = ref.watch(sessionProvider);
  ref.watch(operacionesTickProvider);
  final evidenciaHoy = ref.watch(evidenciaSubidaHoyProvider);

  if (perfil == null) {
    return const PasoDiario(
      unidad: false,
      tablero: false,
      solicitud: false,
      evidencia: false,
    );
  }

  final repo = ref.watch(operacionesRepositoryProvider);
  final cargaHoy = repo.cargaAbiertaDeHoy(perfil.id);
  final solicitudesHoy = repo
      .solicitudesDeChofer(perfil.id)
      .where((s) => _esHoy(s.creadaEn))
      .toList();
  final tableroHoy =
      evidenciaHoy || solicitudesHoy.any((s) => s.fotoTableroPath != null);

  return PasoDiario(
    unidad: cargaHoy != null || solicitudesHoy.isNotEmpty,
    tablero: tableroHoy,
    solicitud: solicitudesHoy.isNotEmpty,
    evidencia: evidenciaHoy,
  );
});
