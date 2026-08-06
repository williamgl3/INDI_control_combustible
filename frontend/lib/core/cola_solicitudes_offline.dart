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

/// Recorrido (jornada) de despacho de marimba pendiente de sincronizar —
/// a diferencia de las 4 colas anteriores (operaciones planas e
/// independientes), este es el ENCABEZADO de una operación compuesta:
/// sus despachos ([DespachoMarimbaPendienteOffline]) y su cierre
/// ([CierreRecorridoMarimbaPendienteOffline]) lo referencian por
/// [idLocal] y solo pueden sincronizarse después de que este recorrido ya
/// tenga [idServidor] — ver [_sincronizarRecorridosMarimba].
///
/// Se queda en la cola incluso después de sincronizarse (con
/// [idServidor] ya asignado) hasta que TODOS sus despachos y su cierre
/// (si existe) también se sincronizaron — recién ahí se considera
/// "terminado" y se quita.
class RecorridoMarimbaPendienteOffline {
  const RecorridoMarimbaPendienteOffline({
    required this.idLocal,
    required this.marimbaId,
    required this.frente,
    this.cargaId,
    required this.litrosIniciales,
    this.kmInicio,
    this.horasEquipoMenorInicio,
    required this.creadaEn,
    this.idServidor,
  });

  final String idLocal;
  final String marimbaId;
  final String frente;
  final String? cargaId;
  final double litrosIniciales;
  final double? kmInicio;
  final double? horasEquipoMenorInicio;
  final DateTime creadaEn;

  /// `null` hasta que `POST /recorridos-marimba` responde con éxito.
  final String? idServidor;

  factory RecorridoMarimbaPendienteOffline.fromJson(Map<String, dynamic> json) {
    return RecorridoMarimbaPendienteOffline(
      idLocal: json['idLocal'] as String,
      marimbaId: json['marimbaId'] as String,
      frente: json['frente'] as String,
      cargaId: json['cargaId'] as String?,
      litrosIniciales: (json['litrosIniciales'] as num).toDouble(),
      kmInicio: (json['kmInicio'] as num?)?.toDouble(),
      horasEquipoMenorInicio: (json['horasEquipoMenorInicio'] as num?)
          ?.toDouble(),
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      idServidor: json['idServidor'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'marimbaId': marimbaId,
    'frente': frente,
    'cargaId': cargaId,
    'litrosIniciales': litrosIniciales,
    'kmInicio': kmInicio,
    'horasEquipoMenorInicio': horasEquipoMenorInicio,
    'creadaEn': creadaEn.toIso8601String(),
    'idServidor': idServidor,
  };

  RecorridoMarimbaPendienteOffline conIdServidor(String idServidor) {
    return RecorridoMarimbaPendienteOffline(
      idLocal: idLocal,
      marimbaId: marimbaId,
      frente: frente,
      cargaId: cargaId,
      litrosIniciales: litrosIniciales,
      kmInicio: kmInicio,
      horasEquipoMenorInicio: horasEquipoMenorInicio,
      creadaEn: creadaEn,
      idServidor: idServidor,
    );
  }
}

class ColaRecorridosMarimbaOffline {
  static const _key = 'cola_recorridos_marimba_offline';

  Future<List<RecorridoMarimbaPendienteOffline>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map(
          (s) => RecorridoMarimbaPendienteOffline.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> agregar(RecorridoMarimbaPendienteOffline pendiente) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = prefs.getStringList(_key) ?? const [];
    await prefs.setStringList(_key, [
      ...actuales,
      jsonEncode(pendiente.toJson()),
    ]);
  }

  /// Reescribe el registro ya existente con el [idServidor] recién
  /// obtenido — el recorrido sigue en la cola (sus despachos/cierre aún
  /// pueden estar pendientes), solo deja de estar "sin resolver".
  Future<void> actualizarIdServidor(String idLocal, String idServidor) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .map(
            (p) => jsonEncode(
              (p.idLocal == idLocal ? p.conIdServidor(idServidor) : p).toJson(),
            ),
          )
          .toList(),
    );
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

/// Un despacho dentro de un recorrido de marimba pendiente de
/// sincronizar. Referencia a su recorrido por [recorridoIdLocal] — nunca
/// por el id del servidor, precisamente porque puede no existir todavía
/// (ver [RecorridoMarimbaPendienteOffline]).
class DespachoMarimbaPendienteOffline {
  const DespachoMarimbaPendienteOffline({
    required this.idLocal,
    required this.recorridoIdLocal,
    this.vehiculoDestinoId,
    this.destinoTexto,
    required this.operadorTexto,
    this.residenteTexto,
    this.litrosSolicitados,
    required this.litrosSuministrados,
    this.lecturaMedidor,
    this.fotoEvidenciaPath,
    required this.creadaEn,
  });

  final String idLocal;
  final String recorridoIdLocal;
  final String? vehiculoDestinoId;
  final String? destinoTexto;
  final String operadorTexto;
  final String? residenteTexto;
  final double? litrosSolicitados;
  final double litrosSuministrados;
  final double? lecturaMedidor;

  /// Opcional — a diferencia de las otras colas con foto, un despacho
  /// dentro de un recorrido no la exige (ver PASO 3e del diseño: la
  /// evidencia obligatoria es la foto de cierre del recorrido completo).
  final String? fotoEvidenciaPath;
  final DateTime creadaEn;

  factory DespachoMarimbaPendienteOffline.fromJson(Map<String, dynamic> json) {
    return DespachoMarimbaPendienteOffline(
      idLocal: json['idLocal'] as String,
      recorridoIdLocal: json['recorridoIdLocal'] as String,
      vehiculoDestinoId: json['vehiculoDestinoId'] as String?,
      destinoTexto: json['destinoTexto'] as String?,
      operadorTexto: json['operadorTexto'] as String,
      residenteTexto: json['residenteTexto'] as String?,
      litrosSolicitados: (json['litrosSolicitados'] as num?)?.toDouble(),
      litrosSuministrados: (json['litrosSuministrados'] as num).toDouble(),
      lecturaMedidor: (json['lecturaMedidor'] as num?)?.toDouble(),
      fotoEvidenciaPath: json['fotoEvidenciaPath'] as String?,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'recorridoIdLocal': recorridoIdLocal,
    'vehiculoDestinoId': vehiculoDestinoId,
    'destinoTexto': destinoTexto,
    'operadorTexto': operadorTexto,
    'residenteTexto': residenteTexto,
    'litrosSolicitados': litrosSolicitados,
    'litrosSuministrados': litrosSuministrados,
    'lecturaMedidor': lecturaMedidor,
    'fotoEvidenciaPath': fotoEvidenciaPath,
    'creadaEn': creadaEn.toIso8601String(),
  };
}

class ColaDespachosMarimbaOffline {
  static const _key = 'cola_despachos_marimba_offline';

  Future<List<DespachoMarimbaPendienteOffline>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map(
          (s) => DespachoMarimbaPendienteOffline.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> agregar(DespachoMarimbaPendienteOffline pendiente) async {
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

/// Cierre de un recorrido de marimba pendiente de sincronizar — espera a
/// que ya no queden [DespachoMarimbaPendienteOffline] de su
/// [recorridoIdLocal] antes de enviarse (ver
/// [_sincronizarRecorridosMarimba]), para que el backend calcule la
/// conciliación con TODOS los despachos ya aplicados.
class CierreRecorridoMarimbaPendienteOffline {
  const CierreRecorridoMarimbaPendienteOffline({
    required this.idLocal,
    required this.recorridoIdLocal,
    this.kmCierre,
    this.horasEquipoMenorCierre,
    required this.fotoCierrePath,
    required this.creadaEn,
  });

  final String idLocal;
  final String recorridoIdLocal;
  final double? kmCierre;
  final double? horasEquipoMenorCierre;
  final String fotoCierrePath;
  final DateTime creadaEn;

  factory CierreRecorridoMarimbaPendienteOffline.fromJson(
    Map<String, dynamic> json,
  ) {
    return CierreRecorridoMarimbaPendienteOffline(
      idLocal: json['idLocal'] as String,
      recorridoIdLocal: json['recorridoIdLocal'] as String,
      kmCierre: (json['kmCierre'] as num?)?.toDouble(),
      horasEquipoMenorCierre: (json['horasEquipoMenorCierre'] as num?)
          ?.toDouble(),
      fotoCierrePath: json['fotoCierrePath'] as String,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'recorridoIdLocal': recorridoIdLocal,
    'kmCierre': kmCierre,
    'horasEquipoMenorCierre': horasEquipoMenorCierre,
    'fotoCierrePath': fotoCierrePath,
    'creadaEn': creadaEn.toIso8601String(),
  };
}

class ColaCierresRecorridoMarimbaOffline {
  static const _key = 'cola_cierres_recorrido_marimba_offline';

  Future<List<CierreRecorridoMarimbaPendienteOffline>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map(
          (s) => CierreRecorridoMarimbaPendienteOffline.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> agregar(CierreRecorridoMarimbaPendienteOffline pendiente) async {
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

/// Un aviso de que una pendiente offline (de cualquiera de las colas)
/// falló al reintentarse por una razón real del servidor (ej.
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

final colaRecorridosMarimbaOfflineProvider =
    Provider<ColaRecorridosMarimbaOffline>(
      (ref) => ColaRecorridosMarimbaOffline(),
    );

final colaDespachosMarimbaOfflineProvider =
    Provider<ColaDespachosMarimbaOffline>(
      (ref) => ColaDespachosMarimbaOffline(),
    );

final colaCierresRecorridoMarimbaOfflineProvider =
    Provider<ColaCierresRecorridoMarimbaOffline>(
      (ref) => ColaCierresRecorridoMarimbaOffline(),
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

/// Suma de pendientes en todas las colas offline — útil para un badge
/// genérico de "tienes envíos pendientes de conexión". Los recorridos de
/// marimba se cuentan aparte de sus despachos/cierre (cada uno es una
/// operación de red distinta que falta por enviar), no como "1 recorrido
/// = 1 pendiente" — eso subestimaría cuánto falta en una jornada con
/// varios despachos sin sincronizar.
final totalPendientesOfflineProvider = FutureProvider<int>((ref) async {
  ref.watch(operacionesTickProvider);
  final resultados = await Future.wait([
    ref.read(colaSolicitudesOfflineProvider).leer(),
    ref.read(colaComprobarCargaOfflineProvider).leer(),
    ref.read(colaCerrarDiaOfflineProvider).leer(),
    ref.read(colaIncidenciasOfflineProvider).leer(),
    ref.read(colaRecorridosMarimbaOfflineProvider).leer(),
    ref.read(colaDespachosMarimbaOfflineProvider).leer(),
    ref.read(colaCierresRecorridoMarimbaOfflineProvider).leer(),
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

/// Descarta un recorrido completo (él mismo + todos sus despachos y su
/// cierre, si existen) de sus 3 colas — se usa cuando el recorrido en sí
/// falla por una razón de negocio real (ej. la marimba ya tenía otro
/// recorrido abierto): sin el recorrido, sus despachos/cierre nunca
/// podrían sincronizarse (quedarían huérfanos para siempre), así que se
/// descartan junto con él en vez de dejarlos atorados en la cola.
Future<void> _descartarRecorridoMarimbaCompleto(
  WidgetRef ref,
  String recorridoIdLocal,
) async {
  final colaDespachos = ref.read(colaDespachosMarimbaOfflineProvider);
  final colaCierres = ref.read(colaCierresRecorridoMarimbaOfflineProvider);
  final colaRecorridos = ref.read(colaRecorridosMarimbaOfflineProvider);

  for (final despacho in await colaDespachos.leer()) {
    if (despacho.recorridoIdLocal == recorridoIdLocal) {
      await colaDespachos.quitar(despacho.idLocal);
    }
  }
  for (final cierre in await colaCierres.leer()) {
    if (cierre.recorridoIdLocal == recorridoIdLocal) {
      await colaCierres.quitar(cierre.idLocal);
    }
  }
  await colaRecorridos.quitar(recorridoIdLocal);
}

/// Sincroniza recorridos de marimba — a diferencia de las 4 colas
/// anteriores (operaciones planas e independientes), esta es una
/// operación COMPUESTA con dependencias de orden: el recorrido debe
/// existir en el servidor (tener un id real) antes de que sus despachos
/// puedan enviarse, y el cierre debe esperar a que TODOS sus despachos ya
/// se hayan sincronizado (para que el backend concilie con datos
/// completos). Por recorrido, en este orden:
///   1. Si aún no tiene `idServidor`, se abre en el servidor y se guarda
///      el id devuelto — el recorrido sigue en su cola aunque esto tenga
///      éxito, porque puede seguir teniendo despachos/cierre pendientes.
///   2. Se envían los despachos de ESE recorrido cuyo padre ya está
///      resuelto (tiene `idServidor`). Los de un recorrido aún sin
///      resolver se dejan intactos para el siguiente ciclo.
///   3. Si existe un cierre pendiente Y ya no quedan despachos pendientes
///      de este recorrido, se envía el cierre y, recién ahí, se quita
///      también el recorrido de su cola (ciclo completo).
Future<void> _sincronizarRecorridosMarimba(WidgetRef ref) async {
  final colaRecorridos = ref.read(colaRecorridosMarimbaOfflineProvider);
  final colaDespachos = ref.read(colaDespachosMarimbaOfflineProvider);
  final colaCierres = ref.read(colaCierresRecorridoMarimbaOfflineProvider);
  final recorridos = await colaRecorridos.leer();
  if (recorridos.isEmpty) return;

  final repo = ref.read(recorridosMarimbaRepositoryProvider);

  for (final recorrido in recorridos) {
    var idServidor = recorrido.idServidor;
    if (idServidor == null) {
      try {
        final creado = await repo.abrirRecorrido(
          marimbaId: recorrido.marimbaId,
          frente: recorrido.frente,
          cargaId: recorrido.cargaId,
          litrosIniciales: recorrido.litrosIniciales,
          kmInicio: recorrido.kmInicio,
          horasEquipoMenorInicio: recorrido.horasEquipoMenorInicio,
        );
        idServidor = creado.id;
        await colaRecorridos.actualizarIdServidor(recorrido.idLocal, idServidor);
      } on ApiException catch (e) {
        // Sin señal de verdad — probablemente todos los recorridos
        // pendientes fallarían igual ahora mismo, se reintenta en el
        // próximo evento de reconexión.
        if (e.status == null) return;
        // Razón de negocio real (ej. "ya hay un recorrido abierto de esta
        // marimba") — reintentarlo para siempre no lo arreglaría.
        await _descartarRecorridoMarimbaCompleto(ref, recorrido.idLocal);
        await _registrarAviso(
          ref,
          idLocal: recorrido.idLocal,
          descripcion: 'Recorrido de marimba',
          motivo: e.mensaje,
        );
        ref.read(operacionesTickProvider.notifier).state++;
        continue;
      }
    }

    final despachosDelRecorrido = (await colaDespachos.leer())
        .where((d) => d.recorridoIdLocal == recorrido.idLocal)
        .toList();
    var detenidoPorRed = false;
    for (final despacho in despachosDelRecorrido) {
      if (despacho.fotoEvidenciaPath != null &&
          !File(despacho.fotoEvidenciaPath!).existsSync()) {
        await colaDespachos.quitar(despacho.idLocal);
        AppLogger.error(
          'sincronizarRecorridosMarimba',
          'La foto del despacho ${despacho.idLocal} ya no existe en el '
              'dispositivo — se descarta (la foto era opcional, el '
              'despacho no puede reenviarse con ese dato perdido).',
        );
        continue;
      }
      try {
        await repo.agregarDespacho(
          recorridoId: idServidor,
          vehiculoDestinoId: despacho.vehiculoDestinoId,
          destinoTexto: despacho.destinoTexto,
          operadorTexto: despacho.operadorTexto,
          residenteTexto: despacho.residenteTexto,
          litrosSolicitados: despacho.litrosSolicitados,
          litrosSuministrados: despacho.litrosSuministrados,
          lecturaMedidor: despacho.lecturaMedidor,
          fotoEvidenciaPath: despacho.fotoEvidenciaPath,
        );
        await colaDespachos.quitar(despacho.idLocal);
      } on ApiException catch (e) {
        if (e.status == null) {
          detenidoPorRed = true;
          break;
        }
        await colaDespachos.quitar(despacho.idLocal);
        await _registrarAviso(
          ref,
          idLocal: despacho.idLocal,
          descripcion: 'Despacho de marimba',
          motivo: e.mensaje,
        );
      }
      ref.read(operacionesTickProvider.notifier).state++;
    }
    if (detenidoPorRed) return;

    final quedanDespachosPendientes = (await colaDespachos.leer()).any(
      (d) => d.recorridoIdLocal == recorrido.idLocal,
    );
    if (quedanDespachosPendientes) continue;

    final cierre = (await colaCierres.leer())
        .where((c) => c.recorridoIdLocal == recorrido.idLocal)
        .toList();
    if (cierre.isEmpty) continue;
    final pendienteCierre = cierre.first;

    if (!File(pendienteCierre.fotoCierrePath).existsSync()) {
      await colaCierres.quitar(pendienteCierre.idLocal);
      await colaRecorridos.quitar(recorrido.idLocal);
      AppLogger.error(
        'sincronizarRecorridosMarimba',
        'La foto de cierre del recorrido ${recorrido.idLocal} ya no existe '
            'en el dispositivo — se descarta (la foto de cierre es '
            'obligatoria, no se puede cerrar sin ella).',
      );
      continue;
    }
    try {
      await repo.cerrarRecorrido(
        recorridoId: idServidor,
        kmCierre: pendienteCierre.kmCierre,
        horasEquipoMenorCierre: pendienteCierre.horasEquipoMenorCierre,
        fotoCierrePath: pendienteCierre.fotoCierrePath,
      );
      await colaCierres.quitar(pendienteCierre.idLocal);
      await colaRecorridos.quitar(recorrido.idLocal);
    } on ApiException catch (e) {
      if (e.status == null) return;
      await colaCierres.quitar(pendienteCierre.idLocal);
      await colaRecorridos.quitar(recorrido.idLocal);
      await _registrarAviso(
        ref,
        idLocal: pendienteCierre.idLocal,
        descripcion: 'Cierre de recorrido de marimba',
        motivo: e.mensaje,
      );
    }
    ref.read(operacionesTickProvider.notifier).state++;
  }
}

/// Wrapper público de [_sincronizarRecorridosMarimba] — las pantallas del
/// flujo de recorrido lo llaman directo tras cada acción (abrir/agregar
/// despacho/cerrar) para intentar resolverla de inmediato si hay señal,
/// en vez de esperar al próximo evento de reconexión general.
Future<void> sincronizarRecorridosMarimba(WidgetRef ref) =>
    _sincronizarRecorridosMarimba(ref);

/// Reintenta enviar todas las pendientes de las colas offline del chofer
/// (solicitar carga, comprobar carga, cerrar día, reportar incidencia,
/// recorridos de marimba). Cada cola se procesa de forma independiente —
/// que una se detenga por falta de red no impide que las demás lo
/// intenten.
Future<void> sincronizarSolicitudesOffline(WidgetRef ref) async {
  await _sincronizarSolicitudes(ref);
  await _sincronizarComprobarCarga(ref);
  await _sincronizarCerrarDia(ref);
  await _sincronizarIncidencias(ref);
  await _sincronizarRecorridosMarimba(ref);
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
