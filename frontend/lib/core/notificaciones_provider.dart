import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/carga.dart';
import '../models/incidencia_vehiculo.dart';
import '../models/solicitud_autorizacion.dart';
import 'cola_solicitudes_offline.dart';
import 'providers.dart';
import 'session_provider.dart';

/// Una notificación in-app — no reemplaza la notificación local del
/// sistema operativo (`RecordatorioService`, sigue existiendo para
/// "¿ya cerraste tu día?"), sino que da un lugar DENTRO de la app para
/// ver qué cambió mientras no se estaba mirando (antes no existía nada
/// así — solo la notificación del SO, que se pierde si se descarta).
class NotificacionItem {
  const NotificacionItem({
    required this.id,
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    this.solicitudId,
    this.estadoSolicitud,
  });

  final String id;
  final String titulo;
  final String subtitulo;

  /// Nombre del ícono de Material — se resuelve a `IconData` en la UI
  /// para no acoplar este archivo (sin Flutter) a `package:flutter`.
  final String icono;

  /// Identificador estructurado para navegar a la solicitud exacta desde
  /// una notificación administrativa. No se infiere desde el texto visible.
  final String? solicitudId;
  final String? estadoSolicitud;
}

/// Guarda qué solicitudes ya "vio" el chofer en el centro de
/// notificaciones — para no marcar como nueva una resolución antigua en
/// cada reinicio de la app.
class NotificacionesVistasStorage {
  static const _key = 'solicitudes_notificadas_vistas';

  Future<Set<String>> leerVistas() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> marcarVistas(Iterable<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leerVistas();
    await prefs.setStringList(_key, {...actuales, ...ids}.toList());
  }
}

final notificacionesVistasStorageProvider =
    Provider<NotificacionesVistasStorage>(
      (ref) => NotificacionesVistasStorage(),
    );

/// Notificaciones pendientes del chofer en sesión: solicitudes ya
/// resueltas (aprobadas/rechazadas) que todavía no ha visto, más un
/// aviso si tiene una carga abierta sin cerrar el día.
final notificacionesChoferProvider = FutureProvider<List<NotificacionItem>>((
  ref,
) async {
  final perfil = ref.watch(sessionProvider);
  if (perfil == null || !perfil.esChofer) return const [];

  ref.watch(operacionesTickProvider);
  final repo = ref.watch(operacionesRepositoryProvider);
  final vistas = await ref
      .read(notificacionesVistasStorageProvider)
      .leerVistas();

  final solicitudes = repo.solicitudesDeChofer(perfil.id);
  final resueltas = solicitudes.where(
    (s) => s.estado != EstadoSolicitud.pendiente && !vistas.contains(s.id),
  );

  final items = <NotificacionItem>[
    for (final s in resueltas)
      NotificacionItem(
        id: s.id,
        titulo: s.estado == EstadoSolicitud.aprobada
            ? 'Solicitud autorizada'
            : 'Solicitud rechazada',
        subtitulo:
            '${s.litrosSolicitados.toStringAsFixed(1)} L'
            '${s.comentario != null ? ' · ${s.comentario}' : ''}',
        icono: s.estado == EstadoSolicitud.aprobada
            ? 'check_circle_outline'
            : 'cancel_outlined',
      ),
  ];

  final Carga? cargaAbierta = repo.cargaAbiertaDeHoy(perfil.id);
  if (cargaAbierta != null) {
    items.insert(
      0,
      const NotificacionItem(
        id: 'recordatorio-cerrar-dia',
        titulo: '¿Ya terminaste tu día?',
        subtitulo: 'Tienes una carga sin cerrar el día.',
        icono: 'schedule_outlined',
      ),
    );
  }

  // Avisos de sincronización offline fallida (ver
  // `cola_solicitudes_offline.dart`): una pendiente encolada sin conexión
  // que, al reintentarse tras reconectar, falló por una razón real del
  // servidor (no solo "seguía sin haber señal") — antes esto fallaba en
  // silencio, ver el pendiente que se resolvió en `auth_controller.dart`.
  final avisos = await ref.read(avisosSincronizacionOfflineProvider).leer();
  for (final aviso in avisos.where((a) => !vistas.contains(a.id))) {
    items.insert(
      0,
      NotificacionItem(
        id: aviso.id,
        titulo: 'No se pudo sincronizar: ${aviso.descripcion}',
        subtitulo: aviso.motivo,
        icono: 'error_outline',
      ),
    );
  }

  return items;
});

/// Notificaciones pendientes del administrativo en sesión: solicitudes
/// nuevas por revisar, incidencias reportadas sin resolver, y un aviso si
/// el presupuesto semanal ya se acerca a agotarse — antes el admin no
/// tenía ninguna señal dentro de la app (la campanita solo existía para
/// el chofer) y dependía de entrar a cada pestaña "por si acaso".
final notificacionesAdminProvider = FutureProvider<List<NotificacionItem>>((
  ref,
) async {
  final perfil = ref.watch(sessionProvider);
  if (perfil == null || !perfil.esAdministrativo) return const [];

  ref.watch(operacionesTickProvider);
  final repo = ref.watch(operacionesRepositoryProvider);
  final vistas = await ref
      .read(notificacionesVistasStorageProvider)
      .leerVistas();

  final pendientes = repo.todasLasSolicitudes.where(
    (s) => s.estado == EstadoSolicitud.pendiente && !vistas.contains(s.id),
  );

  final items = <NotificacionItem>[
    for (final s in pendientes)
      NotificacionItem(
        id: s.id,
        titulo: 'Nueva solicitud por revisar',
        subtitulo: '${s.litrosSolicitados.toStringAsFixed(1)} L solicitados',
        icono: 'assignment_outlined',
        solicitudId: s.id,
        estadoSolicitud: s.estado.name,
      ),
  ];

  final incidencias = ref
      .watch(incidenciasRepositoryProvider)
      .todasLasIncidencias;
  for (final inc in incidencias.where(
    (i) => i.estado == EstadoIncidencia.abierta && !vistas.contains(i.id),
  )) {
    items.add(
      NotificacionItem(
        id: inc.id,
        titulo: 'Incidencia reportada',
        subtitulo: inc.descripcion,
        icono: 'report_problem_outlined',
      ),
    );
  }

  // Presupuesto semanal cerca de agotarse — mismos umbrales que
  // `BarraPresupuesto` (0.7/0.9), pero como aviso activo en vez de solo un
  // color pasivo que solo se ve si el admin entra a Autorizaciones/Finanzas.
  final total = repo.presupuestoSemanalTotal;
  final proporcion = total > 0 ? repo.presupuestoEjercido / total : 0.0;
  if (proporcion >= 0.9) {
    items.insert(
      0,
      const NotificacionItem(
        id: 'presupuesto-90',
        titulo: 'Presupuesto casi agotado',
        subtitulo: 'Ya se ejerció el 90% o más del presupuesto semanal.',
        icono: 'error_outline',
      ),
    );
  } else if (proporcion >= 0.7) {
    items.insert(
      0,
      const NotificacionItem(
        id: 'presupuesto-70',
        titulo: 'Presupuesto por agotarse',
        subtitulo: 'Ya se ejerció el 70% o más del presupuesto semanal.',
        icono: 'error_outline',
      ),
    );
  }

  return items;
});
