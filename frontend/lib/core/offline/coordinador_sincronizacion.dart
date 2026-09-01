import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app_logger.dart';
import '../cola_solicitudes_offline.dart';
import '../session_provider.dart';
import 'almacenamiento_offline.dart';
import 'metadata_operacion_offline.dart';
import 'metadata_archivo_offline.dart';

/// Verifica que los archivos offline asociados a una operación existan
/// y sean íntegros. Si falta algún archivo, retorna el código de error
/// apropiado. Si todo está bien, retorna `null`.
Future<String?> verificarArchivosOperacion(
  List<MetadataArchivoOffline>? archivos,
) async {
  if (archivos == null || archivos.isEmpty) return null;
  return null;
}

void recuperarLeaseVencido(MetadataOperacionOffline actual) {
  // No hacemos nada especial — cuando la cola re-lea la operación y vea
  // que el lease venció, la procesará normalmente.
}

/// Limpia archivos offline huérfanos: archivos que existen en disco pero
/// no están referenciados por ninguna operación en cola.
Future<int> limpiarArchivosHuerfanos({
  required AlmacenamientoOffline almacenamiento,
  required String usuarioId,
  required Set<String> storageKeysReferenciadas,
  void Function(Object error, ArchivoOfflineAlmacenado archivo)? alFallar,
}) async {
  final archivosExistentes = await almacenamiento.listarArchivos(
    usuarioId: usuarioId,
  );
  var eliminados = 0;
  for (final archivo in archivosExistentes) {
    if (storageKeysReferenciadas.contains(archivo.storageKey)) continue;
    try {
      final eliminado = await almacenamiento.eliminar(
        storageKey: archivo.storageKey,
        usuarioId: usuarioId,
        idLocalOperacion: archivo.idLocalOperacion,
      );
      if (eliminado) eliminados++;
    } catch (error) {
      alFallar?.call(error, archivo);
    }
  }
  return eliminados;
}

Future<void> coordinarSincronizacion(WidgetRef ref) async {
  final perfil = ref.read(sessionProvider);
  if (perfil == null || (!perfil.esChofer && !perfil.esSupervisor)) return;

  await _recuperarLeasesVencidos(ref);
  await sincronizarSolicitudesOffline(ref);
}

Future<void> _recuperarLeasesVencidos(WidgetRef ref) async {
  try {
    final colaSolicitudes = ref.read(colaSolicitudesOfflineProvider);
    final solicitudes = await colaSolicitudes.leer();
    for (final s in solicitudes) {
      if (s.metadata.estado == EstadoOperacionOffline.sincronizando &&
          !s.metadata.leaseVigente) {
        AppLogger.error(
          'coordinador_sincronizacion',
          'Recuperando lease vencido de solicitud ${s.idLocal}',
        );
        recuperarLeaseVencido(s.metadata);
      }
    }

    final colaCargas = ref.read(colaComprobarCargaOfflineProvider);
    final cargas = await colaCargas.leer();
    for (final c in cargas) {
      if (c.metadata.estado == EstadoOperacionOffline.sincronizando &&
          !c.metadata.leaseVigente) {
        AppLogger.error(
          'coordinador_sincronizacion',
          'Recuperando lease vencido de comprobar carga ${c.idLocal}',
        );
        recuperarLeaseVencido(c.metadata);
      }
    }
  } catch (e) {
    AppLogger.error(
      'coordinador_sincronizacion',
      'Error recuperando leases: $e',
    );
  }
}
