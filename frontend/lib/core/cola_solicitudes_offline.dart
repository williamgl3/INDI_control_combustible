import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/api_client.dart';
import 'app_logger.dart';
import 'connectivity_provider.dart';
import 'providers.dart';
import 'session_provider.dart';

/// Una solicitud de carga guardada localmente porque no había conexión
/// al momento de enviarla — se reintenta automáticamente cuando vuelve la
/// señal (ver [sincronizarSolicitudesOffline]). Mismo patrón que
/// [ComprobarCargaPendienteOffline], [CerrarDiaPendienteOffline] e
/// [IncidenciaPendienteOffline] — juntas cubren los cuatro flujos del
/// chofer que pueden ejecutarse sin señal en obra.
class SolicitudPendienteOffline {
  const SolicitudPendienteOffline({
    required this.idLocal,
    required this.vehiculoId,
    required this.litrosSolicitados,
    required this.esUrgente,
    required this.motivoChofer,
    required this.actividad,
    required this.fechaProgramada,
    required this.fotoTableroPath,
    required this.creadaEn,
  });

  final String idLocal;
  final String vehiculoId;
  final double litrosSolicitados;
  final bool esUrgente;
  final String? motivoChofer;
  final String actividad;
  final DateTime fechaProgramada;

  /// Foto del tablero (km/horómetro) tomada al pedir — igual que en
  /// [ComprobarCargaPendienteOffline], solo se guarda la ruta local; si el
  /// archivo ya no existe al sincronizar, se descarta la pendiente.
  final String fotoTableroPath;
  final DateTime creadaEn;

  factory SolicitudPendienteOffline.fromJson(Map<String, dynamic> json) {
    return SolicitudPendienteOffline(
      idLocal: json['idLocal'] as String,
      vehiculoId: json['vehiculoId'] as String,
      litrosSolicitados: (json['litrosSolicitados'] as num).toDouble(),
      esUrgente: json['esUrgente'] as bool,
      motivoChofer: json['motivoChofer'] as String?,
      actividad: json['actividad'] as String,
      fechaProgramada: DateTime.parse(json['fechaProgramada'] as String),
      fotoTableroPath: json['fotoTableroPath'] as String,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'vehiculoId': vehiculoId,
    'litrosSolicitados': litrosSolicitados,
    'esUrgente': esUrgente,
    'motivoChofer': motivoChofer,
    'actividad': actividad,
    'fechaProgramada': fechaProgramada.toIso8601String(),
    'fotoTableroPath': fotoTableroPath,
    'creadaEn': creadaEn.toIso8601String(),
  };
}

class ColaSolicitudesOffline {
  static const _key = 'cola_solicitudes_offline';

  Future<List<SolicitudPendienteOffline>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map((s) => SolicitudPendienteOffline.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  Future<void> agregar(SolicitudPendienteOffline pendiente) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [
      ...actuales,
      jsonEncode(pendiente.toJson()),
    ]);
  }

  Future<void> quitar(String idLocal) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .where((p) => p.idLocal != idLocal)
          .map((p) => jsonEncode(p.toJson()))
          .toList(),
    );
  }
}

/// Comprobación de carga (registro 1) pendiente de sincronizar. A
/// diferencia de [SolicitudPendienteOffline], SIEMPRE lleva dos fotos ya
/// tomadas — se guarda solo la ruta local del archivo (no se sube nada
/// hasta reconectar); si el archivo ya no existe al momento de
/// sincronizar (el usuario lo borró/el SO limpió caché), se descarta esa
/// pendiente entera en vez de reintentarla para siempre (ver
/// [sincronizarSolicitudesOffline]).
class ComprobarCargaPendienteOffline {
  const ComprobarCargaPendienteOffline({
    required this.idLocal,
    required this.choferId,
    required this.vehiculoId,
    required this.folioAutorizacion,
    required this.litrosCargados,
    required this.kmAlCargar,
    required this.gasolinera,
    required this.fotoTicketPath,
    required this.fotoTableroPath,
    this.litrosDetectadosOcr,
    required this.creadaEn,
  });

  final String idLocal;
  final String choferId;
  final String vehiculoId;
  final String folioAutorizacion;
  final double litrosCargados;
  final double kmAlCargar;
  final String gasolinera;
  final String fotoTicketPath;
  final String fotoTableroPath;
  final double? litrosDetectadosOcr;
  final DateTime creadaEn;

  factory ComprobarCargaPendienteOffline.fromJson(Map<String, dynamic> json) {
    return ComprobarCargaPendienteOffline(
      idLocal: json['idLocal'] as String,
      choferId: json['choferId'] as String,
      vehiculoId: json['vehiculoId'] as String,
      folioAutorizacion: json['folioAutorizacion'] as String,
      litrosCargados: (json['litrosCargados'] as num).toDouble(),
      kmAlCargar: (json['kmAlCargar'] as num).toDouble(),
      gasolinera: json['gasolinera'] as String,
      fotoTicketPath: json['fotoTicketPath'] as String,
      fotoTableroPath: json['fotoTableroPath'] as String,
      litrosDetectadosOcr: (json['litrosDetectadosOcr'] as num?)?.toDouble(),
      creadaEn: DateTime.parse(json['creadaEn'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'choferId': choferId,
    'vehiculoId': vehiculoId,
    'folioAutorizacion': folioAutorizacion,
    'litrosCargados': litrosCargados,
    'kmAlCargar': kmAlCargar,
    'gasolinera': gasolinera,
    'fotoTicketPath': fotoTicketPath,
    'fotoTableroPath': fotoTableroPath,
    'litrosDetectadosOcr': litrosDetectadosOcr,
    'creadaEn': creadaEn.toIso8601String(),
  };
}

class ColaComprobarCargaOffline {
  static const _key = 'cola_comprobar_carga_offline';

  Future<List<ComprobarCargaPendienteOffline>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map(
          (s) => ComprobarCargaPendienteOffline.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> agregar(ComprobarCargaPendienteOffline pendiente) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [
      ...actuales,
      jsonEncode(pendiente.toJson()),
    ]);
  }

  Future<void> quitar(String idLocal) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .where((p) => p.idLocal != idLocal)
          .map((p) => jsonEncode(p.toJson()))
          .toList(),
    );
  }
}

/// Cierre de día (registro 2) pendiente de sincronizar — misma lógica de
/// foto local que [ComprobarCargaPendienteOffline].
class CerrarDiaPendienteOffline {
  const CerrarDiaPendienteOffline({
    required this.idLocal,
    required this.choferId,
    required this.cargaId,
    required this.kmFinal,
    required this.fotoTableroPath,
    required this.creadaEn,
  });

  final String idLocal;
  final String choferId;
  final String cargaId;
  final double kmFinal;
  final String fotoTableroPath;
  final DateTime creadaEn;

  factory CerrarDiaPendienteOffline.fromJson(Map<String, dynamic> json) {
    return CerrarDiaPendienteOffline(
      idLocal: json['idLocal'] as String,
      choferId: json['choferId'] as String,
      cargaId: json['cargaId'] as String,
      kmFinal: (json['kmFinal'] as num).toDouble(),
      fotoTableroPath: json['fotoTableroPath'] as String,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'choferId': choferId,
    'cargaId': cargaId,
    'kmFinal': kmFinal,
    'fotoTableroPath': fotoTableroPath,
    'creadaEn': creadaEn.toIso8601String(),
  };
}

class ColaCerrarDiaOffline {
  static const _key = 'cola_cerrar_dia_offline';

  Future<List<CerrarDiaPendienteOffline>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map(
          (s) => CerrarDiaPendienteOffline.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> agregar(CerrarDiaPendienteOffline pendiente) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [
      ...actuales,
      jsonEncode(pendiente.toJson()),
    ]);
  }

  Future<void> quitar(String idLocal) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .where((p) => p.idLocal != idLocal)
          .map((p) => jsonEncode(p.toJson()))
          .toList(),
    );
  }
}

/// Reporte de incidencia/falla de vehículo pendiente de sincronizar — la
/// foto es opcional (no toda incidencia es fotografiable), a diferencia
/// de las otras 3 colas donde la(s) foto(s) son obligatorias.
class IncidenciaPendienteOffline {
  const IncidenciaPendienteOffline({
    required this.idLocal,
    required this.vehiculoId,
    required this.descripcion,
    required this.creadaEn,
    this.fotoPath,
  });

  final String idLocal;
  final String vehiculoId;
  final String descripcion;
  final DateTime creadaEn;
  final String? fotoPath;

  factory IncidenciaPendienteOffline.fromJson(Map<String, dynamic> json) {
    return IncidenciaPendienteOffline(
      idLocal: json['idLocal'] as String,
      vehiculoId: json['vehiculoId'] as String,
      descripcion: json['descripcion'] as String,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      fotoPath: json['fotoPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'vehiculoId': vehiculoId,
    'descripcion': descripcion,
    'creadaEn': creadaEn.toIso8601String(),
    'fotoPath': fotoPath,
  };
}

class ColaIncidenciasOffline {
  static const _key = 'cola_incidencias_offline';

  Future<List<IncidenciaPendienteOffline>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map(
          (s) => IncidenciaPendienteOffline.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> agregar(IncidenciaPendienteOffline pendiente) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [
      ...actuales,
      jsonEncode(pendiente.toJson()),
    ]);
  }

  Future<void> quitar(String idLocal) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .where((p) => p.idLocal != idLocal)
          .map((p) => jsonEncode(p.toJson()))
          .toList(),
    );
  }
}

/// Un aviso de que una pendiente offline (de cualquiera de las cuatro
/// colas) falló al reintentarse por una razón real del servidor (ej.
/// 400/422/500) — no solo "seguía sin haber señal". Se muestra al chofer
/// en el centro de notificaciones (ver `notificaciones_provider.dart`)
/// para que sepa que ESA solicitud no se sincronizó y por qué, en vez de
/// fallar en silencio.
class AvisoSincronizacionFallida {
  const AvisoSincronizacionFallida({
    required this.id,
    required this.descripcion,
    required this.motivo,
    required this.ocurridoEn,
  });

  final String id;

  /// Ej. "Solicitud de carga", "Comprobación de carga", "Cierre de día",
  /// "Reporte de incidencia" — de qué flujo venía la pendiente.
  final String descripcion;

  /// Mensaje real del backend (`ApiException.mensaje`).
  final String motivo;
  final DateTime ocurridoEn;

  factory AvisoSincronizacionFallida.fromJson(Map<String, dynamic> json) {
    return AvisoSincronizacionFallida(
      id: json['id'] as String,
      descripcion: json['descripcion'] as String,
      motivo: json['motivo'] as String,
      ocurridoEn: DateTime.parse(json['ocurridoEn'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'descripcion': descripcion,
    'motivo': motivo,
    'ocurridoEn': ocurridoEn.toIso8601String(),
  };
}

class AvisosSincronizacionOfflineStorage {
  static const _key = 'avisos_sincronizacion_offline';

  Future<List<AvisoSincronizacionFallida>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map(
          (s) => AvisoSincronizacionFallida.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> agregar(AvisoSincronizacionFallida aviso) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [
      ...actuales,
      jsonEncode(aviso.toJson()),
    ]);
  }

  Future<void> quitar(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .where((a) => a.id != id)
          .map((a) => jsonEncode(a.toJson()))
          .toList(),
    );
  }
}

final colaSolicitudesOfflineProvider = Provider<ColaSolicitudesOffline>(
  (ref) => ColaSolicitudesOffline(),
);

final colaComprobarCargaOfflineProvider = Provider<ColaComprobarCargaOffline>(
  (ref) => ColaComprobarCargaOffline(),
);

final colaCerrarDiaOfflineProvider = Provider<ColaCerrarDiaOffline>(
  (ref) => ColaCerrarDiaOffline(),
);

final colaIncidenciasOfflineProvider = Provider<ColaIncidenciasOffline>(
  (ref) => ColaIncidenciasOffline(),
);

final avisosSincronizacionOfflineProvider =
    Provider<AvisosSincronizacionOfflineStorage>(
      (ref) => AvisosSincronizacionOfflineStorage(),
    );

/// Cuántas solicitudes hay pendientes de sincronizar — se recalcula cada
/// vez que cambia [operacionesTickProvider] (mismo patrón de "tick" que
/// usa el resto de la app para forzar rebuilds tras mutaciones locales).
final solicitudesPendientesOfflineProvider =
    FutureProvider<List<SolicitudPendienteOffline>>((ref) async {
      ref.watch(operacionesTickProvider);
      return ref.read(colaSolicitudesOfflineProvider).leer();
    });

/// Suma de pendientes en las cuatro colas offline — útil para un badge
/// genérico de "tienes envíos pendientes de conexión".
final totalPendientesOfflineProvider = FutureProvider<int>((ref) async {
  ref.watch(operacionesTickProvider);
  final resultados = await Future.wait([
    ref.read(colaSolicitudesOfflineProvider).leer(),
    ref.read(colaComprobarCargaOfflineProvider).leer(),
    ref.read(colaCerrarDiaOfflineProvider).leer(),
    ref.read(colaIncidenciasOfflineProvider).leer(),
  ]);
  return resultados.fold<int>(0, (suma, lista) => suma + lista.length);
});

/// Registra en [AvisosSincronizacionOfflineStorage] que una pendiente
/// offline falló por una razón real del servidor, y lo deja también en
/// [AppLogger] para poder investigarla.
Future<void> _registrarAviso(
  WidgetRef ref, {
  required String idLocal,
  required String descripcion,
  required String motivo,
}) async {
  await ref
      .read(avisosSincronizacionOfflineProvider)
      .agregar(
        AvisoSincronizacionFallida(
          id: 'aviso-$idLocal',
          descripcion: descripcion,
          motivo: motivo,
          ocurridoEn: DateTime.now(),
        ),
      );
  AppLogger.error(
    'sincronizarSolicitudesOffline',
    '$descripcion ($idLocal) no se pudo sincronizar: $motivo',
  );
}

/// Reintenta enviar cada solicitud de carga encolada, en orden. Se
/// detiene en cuanto una falla por falta de red (probablemente todas
/// fallarán igual en ese momento) — pero si una falla por una razón de
/// negocio real (`ApiException` con `status` HTTP, ej. vehículo ya no
/// existe), se descarta de la cola de todas formas: reintentarla para
/// siempre no la arreglaría. Se registra un [AvisoSincronizacionFallida]
/// visible para el chofer (ver `notificaciones_provider.dart`).
Future<void> _sincronizarSolicitudes(WidgetRef ref) async {
  final cola = ref.read(colaSolicitudesOfflineProvider);
  final pendientes = await cola.leer();
  if (pendientes.isEmpty) return;

  final repo = ref.read(operacionesRepositoryProvider);
  final vehiculosRepo = ref.read(vehiculosRepositoryProvider);
  final choferId = ref.read(sessionProvider)?.id ?? '';

  for (final pendiente in pendientes) {
    final vehiculo = vehiculosRepo.porId(pendiente.vehiculoId);
    if (vehiculo == null) {
      await cola.quitar(pendiente.idLocal);
      AppLogger.error(
        'sincronizarSolicitudesOffline',
        'Vehículo ${pendiente.vehiculoId} ya no existe — se descarta ${pendiente.idLocal}.',
      );
      continue;
    }
    if (!File(pendiente.fotoTableroPath).existsSync()) {
      await cola.quitar(pendiente.idLocal);
      AppLogger.error(
        'sincronizarSolicitudesOffline',
        'La foto del tablero de la solicitud ${pendiente.idLocal} ya no '
            'existe en el dispositivo — se descarta.',
      );
      continue;
    }
    try {
      await repo.enviarSolicitud(
        choferId: choferId,
        vehiculo: vehiculo,
        litrosSolicitados: pendiente.litrosSolicitados,
        esUrgente: pendiente.esUrgente,
        motivoChofer: pendiente.motivoChofer,
        actividad: pendiente.actividad,
        fechaProgramada: pendiente.fechaProgramada,
        fotoTableroPath: pendiente.fotoTableroPath,
      );
      await cola.quitar(pendiente.idLocal);
    } on ApiException catch (e) {
      if (e.status == null) {
        // Error de red — probablemente sigue sin haber conexión de
        // verdad (falso positivo de `conectividadProvider`, que solo
        // detecta wifi/datos, no que el backend responda). Se detiene
        // aquí y se reintenta en el próximo evento de reconexión.
        return;
      }
      await cola.quitar(pendiente.idLocal);
      await _registrarAviso(
        ref,
        idLocal: pendiente.idLocal,
        descripcion: 'Solicitud de carga',
        motivo: e.mensaje,
      );
    }
    ref.read(operacionesTickProvider.notifier).state++;
  }
}

/// Reintenta cada comprobación de carga encolada — misma lógica que
/// [_sincronizarSolicitudes], más el chequeo de que la foto local siga
/// existiendo (ver [ComprobarCargaPendienteOffline]).
Future<void> _sincronizarComprobarCarga(WidgetRef ref) async {
  final cola = ref.read(colaComprobarCargaOfflineProvider);
  final pendientes = await cola.leer();
  if (pendientes.isEmpty) return;

  final repo = ref.read(operacionesRepositoryProvider);

  for (final pendiente in pendientes) {
    if (!File(pendiente.fotoTicketPath).existsSync() ||
        !File(pendiente.fotoTableroPath).existsSync()) {
      await cola.quitar(pendiente.idLocal);
      AppLogger.error(
        'sincronizarSolicitudesOffline',
        'Una foto de la comprobación ${pendiente.idLocal} ya no existe en '
            'el dispositivo — se descarta.',
      );
      continue;
    }
    try {
      await repo.registrarCarga(
        choferId: pendiente.choferId,
        vehiculoId: pendiente.vehiculoId,
        folioAutorizacion: pendiente.folioAutorizacion,
        litrosCargados: pendiente.litrosCargados,
        kmAlCargar: pendiente.kmAlCargar,
        gasolinera: pendiente.gasolinera,
        fotoTicketPath: pendiente.fotoTicketPath,
        fotoTableroPath: pendiente.fotoTableroPath,
        litrosDetectadosOcr: pendiente.litrosDetectadosOcr,
      );
      await cola.quitar(pendiente.idLocal);
    } on ApiException catch (e) {
      if (e.status == null) return;
      await cola.quitar(pendiente.idLocal);
      await _registrarAviso(
        ref,
        idLocal: pendiente.idLocal,
        descripcion: 'Comprobación de carga',
        motivo: e.mensaje,
      );
    }
    ref.read(operacionesTickProvider.notifier).state++;
  }
}

/// Reintenta cada cierre de día encolado — misma lógica de foto que
/// [_sincronizarComprobarCarga].
Future<void> _sincronizarCerrarDia(WidgetRef ref) async {
  final cola = ref.read(colaCerrarDiaOfflineProvider);
  final pendientes = await cola.leer();
  if (pendientes.isEmpty) return;

  final repo = ref.read(operacionesRepositoryProvider);

  for (final pendiente in pendientes) {
    if (!File(pendiente.fotoTableroPath).existsSync()) {
      await cola.quitar(pendiente.idLocal);
      AppLogger.error(
        'sincronizarSolicitudesOffline',
        'La foto del cierre de día ${pendiente.idLocal} ya no existe en '
            'el dispositivo — se descarta.',
      );
      continue;
    }
    try {
      await repo.cerrarDia(
        choferId: pendiente.choferId,
        cargaId: pendiente.cargaId,
        kmFinal: pendiente.kmFinal,
        fotoTableroPath: pendiente.fotoTableroPath,
      );
      await cola.quitar(pendiente.idLocal);
    } on ApiException catch (e) {
      if (e.status == null) return;
      await cola.quitar(pendiente.idLocal);
      await _registrarAviso(
        ref,
        idLocal: pendiente.idLocal,
        descripcion: 'Cierre de día',
        motivo: e.mensaje,
      );
    }
    ref.read(operacionesTickProvider.notifier).state++;
  }
}

/// Reintenta cada reporte de incidencia encolado. La foto es opcional —
/// si se tomó una y ya no existe en el dispositivo, se descarta solo esa
/// foto (no toda la pendiente, a diferencia de las otras 3 colas donde
/// la foto es obligatoria).
Future<void> _sincronizarIncidencias(WidgetRef ref) async {
  final cola = ref.read(colaIncidenciasOfflineProvider);
  final pendientes = await cola.leer();
  if (pendientes.isEmpty) return;

  final repo = ref.read(incidenciasRepositoryProvider);

  for (final pendiente in pendientes) {
    final fotoSigueExistiendo =
        pendiente.fotoPath != null && File(pendiente.fotoPath!).existsSync();
    try {
      await repo.reportar(
        vehiculoId: pendiente.vehiculoId,
        descripcion: pendiente.descripcion,
        fotoPath: fotoSigueExistiendo ? pendiente.fotoPath : null,
      );
      await cola.quitar(pendiente.idLocal);
    } on ApiException catch (e) {
      if (e.status == null) return;
      await cola.quitar(pendiente.idLocal);
      await _registrarAviso(
        ref,
        idLocal: pendiente.idLocal,
        descripcion: 'Reporte de incidencia',
        motivo: e.mensaje,
      );
    }
    ref.read(operacionesTickProvider.notifier).state++;
  }
}

/// Reintenta enviar todas las pendientes de las cuatro colas offline del
/// chofer (solicitar carga, comprobar carga, cerrar día, reportar
/// incidencia). Cada cola se procesa de forma independiente — que una se
/// detenga por falta de red no impide que las demás lo intenten.
Future<void> sincronizarSolicitudesOffline(WidgetRef ref) async {
  await _sincronizarSolicitudes(ref);
  await _sincronizarComprobarCarga(ref);
  await _sincronizarCerrarDia(ref);
  await _sincronizarIncidencias(ref);
}

/// Se suscribe a `conectividadProvider` y sincroniza automáticamente en
/// cuanto detecta que volvió la conexión — se llama desde el `build` de
/// `_AppConRouter` en `main.dart` (se re-ejecuta en cada rebuild, ej. al
/// cambiar de tema o de ruta).
///
/// El estado "anterior" arranca leyendo el valor YA conocido del
/// provider (`ref.read`), no `null` — si arrancara siempre en `null`, un
/// rebuild justo después de perder la conexión (cualquier navegación
/// cuenta) registraría un listener nuevo que nunca "vio" la transición a
/// `false`, y por lo tanto jamás dispararía la sincronización al
/// reconectar.
void observarReconexionParaSincronizar(WidgetRef ref) {
  bool? anterior = ref.read(conectividadProvider).valueOrNull;
  ref.listen<AsyncValue<bool>>(conectividadProvider, (previous, next) {
    final actual = next.valueOrNull;
    if (actual == true && anterior == false) {
      sincronizarSolicitudesOffline(ref);
    }
    anterior = actual;
  });
}
