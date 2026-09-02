import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cola_solicitudes_offline.dart';
import '../offline/coordinador_sincronizacion.dart';
import '../providers.dart';
import '../session_provider.dart';
export 'agregador_sincronizacion.dart' show CentroSincronizacionData;
import 'agregador_sincronizacion.dart';
import 'operacion_sincronizacion_view.dart';

/// Provider principal del Centro de Sincronización.
///
/// Lee las 8 colas offline, filtra por el usuario actual y construye
/// un [CentroSincronizacionData] con todas las operaciones unificadas.
///
/// Se reconstruye cada vez que:
/// - `operacionesTickProvider` cambia (post-sincronización)
/// - El usuario cambia de sesión
final centroSincronizacionProvider =
    FutureProvider<CentroSincronizacionData>((ref) async {
  ref.watch(operacionesTickProvider);
  final usuarioId = ref.watch(sessionProvider)?.id;

  // Si no hay sesión, retornar vacío.
  if (usuarioId == null || usuarioId.isEmpty) {
    return const CentroSincronizacionData(
      operaciones: [],
      conteoPorEstado: {},
    );
  }

  // Leer las 8 colas en paralelo.
  final resultados = await Future.wait([
    ref.read(colaSolicitudesOfflineProvider).leer(),
    ref.read(colaComprobarCargaOfflineProvider).leer(),
    ref.read(colaCerrarDiaOfflineProvider).leer(),
    ref.read(colaIncidenciasOfflineProvider).leer(),
    ref.read(colaEvidenciasOfflineProvider).leer(),
    ref.read(colaRecorridosMarimbaOfflineProvider).leer(),
    ref.read(colaDespachosMarimbaOfflineProvider).leer(),
    ref.read(colaCierresRecorridoMarimbaOfflineProvider).leer(),
  ]);

  // Filtrar por usuario (nota: cargas y cierres usan choferId, no usuarioId).
  final solicitudes = (resultados[0] as List<SolicitudPendienteOffline>)
      .where((p) => p.usuarioId == usuarioId)
      .toList();
  final cargas = (resultados[1] as List<ComprobarCargaPendienteOffline>)
      .where((p) => p.choferId == usuarioId)
      .toList();
  final cierres = (resultados[2] as List<CerrarDiaPendienteOffline>)
      .where((p) => p.choferId == usuarioId)
      .toList();
  final incidencias = (resultados[3] as List<IncidenciaPendienteOffline>)
      .where((p) => p.usuarioId == usuarioId)
      .toList();
  final evidencias = (resultados[4] as List<EvidenciaPendienteOffline>)
      .where((p) => p.usuarioId == usuarioId)
      .toList();
  final recorridos = (resultados[5] as List<RecorridoMarimbaPendienteOffline>)
      .where((p) => p.usuarioId == usuarioId)
      .toList();
  final despachos = (resultados[6] as List<DespachoMarimbaPendienteOffline>)
      .where((p) => p.usuarioId == usuarioId)
      .toList();
  final cierresRecorrido =
      (resultados[7] as List<CierreRecorridoMarimbaPendienteOffline>)
          .where((p) => p.usuarioId == usuarioId)
          .toList();

  return AgregadorSincronizacion.agregar(
    solicitudes: solicitudes,
    cargas: cargas,
    cierres: cierres,
    incidencias: incidencias,
    evidencias: evidencias,
    recorridos: recorridos,
    despachos: despachos,
    cierresRecorrido: cierresRecorrido,
  );
});

/// Filtra el Centro por un conjunto de estados visuales.
/// Si [estados] está vacío, retorna todas las operaciones.
List<OperacionSincronizacionView> filtrarPorEstados(
  CentroSincronizacionData data,
  Set<EstadoVisualSincronizacion> estados,
) {
  if (estados.isEmpty) return data.operaciones;
  return data.operaciones
      .where((op) => estados.contains(op.estadoVisual))
      .toList();
}

/// Filtra el Centro por tipo de operación.
List<OperacionSincronizacionView> filtrarPorTipos(
  CentroSincronizacionData data,
  Set<TipoOperacionOffline> tipos,
) {
  if (tipos.isEmpty) return data.operaciones;
  return data.operaciones
      .where((op) => tipos.contains(op.tipo))
      .toList();
}

/// Reintenta una operación individual invocando al coordinador.
/// Retorna true si se inició la sincronización, false si no era posible.
Future<bool> reintentarOperacion(
  WidgetRef ref,
  OperacionSincronizacionView operacion,
) async {
  if (!operacion.puedeReintentar) return false;

  // Invocar el coordinador que ya existe — no duplicamos lógica.
  await coordinarSincronizacion(ref);

  // Forzar rebuild del Centro para reflejar los cambios.
  ref.invalidate(centroSincronizacionProvider);
  return true;
}

/// Sincroniza todas las operaciones reintentables del Centro.
Future<int> sincronizarTodasOffline(WidgetRef ref) async {
  final datos = await ref.read(centroSincronizacionProvider.future);
  if (datos.reintentables == 0) return 0;

  await coordinarSincronizacion(ref);
  ref.invalidate(centroSincronizacionProvider);
  return datos.reintentables;
}
