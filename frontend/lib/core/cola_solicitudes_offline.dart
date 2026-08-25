import 'dart:async';
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
    required this.usuarioId,
    required this.idempotencyKey,
    required this.payloadFingerprint,
    required this.vehiculoId,
    required this.litrosSolicitados,
    required this.esUrgente,
    required this.motivoChofer,
    required this.actividad,
    required this.fechaProgramada,
    required this.fotoTableroPath,
    required this.creadaEn,
    this.estado = EstadoSolicitudOffline.pendiente,
    this.idRemoto,
    this.intentos = 0,
    this.ultimoError,
    this.proximoIntento,
  });

  final String idLocal;
  final String usuarioId;
  final String idempotencyKey;
  final String payloadFingerprint;
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
  final EstadoSolicitudOffline estado;
  final String? idRemoto;
  final int intentos;
  final String? ultimoError;
  final DateTime? proximoIntento;

  factory SolicitudPendienteOffline.fromJson(Map<String, dynamic> json) {
    return SolicitudPendienteOffline(
      idLocal: json['idLocal'] as String,
      usuarioId: json['usuarioId'] as String? ?? '',
      idempotencyKey:
          json['idempotencyKey'] as String? ?? json['idLocal'] as String,
      payloadFingerprint: json['payloadFingerprint'] as String? ?? '',
      vehiculoId: json['vehiculoId'] as String,
      litrosSolicitados: (json['litrosSolicitados'] as num).toDouble(),
      esUrgente: json['esUrgente'] as bool,
      motivoChofer: json['motivoChofer'] as String?,
      actividad: json['actividad'] as String,
      fechaProgramada: DateTime.parse(json['fechaProgramada'] as String),
      fotoTableroPath: json['fotoTableroPath'] as String,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      estado: EstadoSolicitudOffline.values.byName(
        json['estado'] as String? ?? EstadoSolicitudOffline.pendiente.name,
      ),
      idRemoto: json['idRemoto'] as String?,
      intentos: json['intentos'] as int? ?? 0,
      ultimoError: json['ultimoError'] as String?,
      proximoIntento: json['proximoIntento'] == null
          ? null
          : DateTime.parse(json['proximoIntento'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'usuarioId': usuarioId,
    'idempotencyKey': idempotencyKey,
    'payloadFingerprint': payloadFingerprint,
    'vehiculoId': vehiculoId,
    'litrosSolicitados': litrosSolicitados,
    'esUrgente': esUrgente,
    'motivoChofer': motivoChofer,
    'actividad': actividad,
    'fechaProgramada': fechaProgramada.toIso8601String(),
    'fotoTableroPath': fotoTableroPath,
    'creadaEn': creadaEn.toIso8601String(),
    'estado': estado.name,
    'idRemoto': idRemoto,
    'intentos': intentos,
    'ultimoError': ultimoError,
    'proximoIntento': proximoIntento?.toIso8601String(),
  };

  SolicitudPendienteOffline copiar({
    EstadoSolicitudOffline? estado,
    String? idRemoto,
    int? intentos,
    String? ultimoError,
    DateTime? proximoIntento,
  }) => SolicitudPendienteOffline(
    idLocal: idLocal,
    usuarioId: usuarioId,
    idempotencyKey: idempotencyKey,
    payloadFingerprint: payloadFingerprint,
    vehiculoId: vehiculoId,
    litrosSolicitados: litrosSolicitados,
    esUrgente: esUrgente,
    motivoChofer: motivoChofer,
    actividad: actividad,
    fechaProgramada: fechaProgramada,
    fotoTableroPath: fotoTableroPath,
    creadaEn: creadaEn,
    estado: estado ?? this.estado,
    idRemoto: idRemoto ?? this.idRemoto,
    intentos: intentos ?? this.intentos,
    ultimoError: ultimoError,
    proximoIntento: proximoIntento,
  );
}

enum EstadoSolicitudOffline {
  pendiente,
  sincronizando,
  enviadaSinConfirmar,
  sincronizada,
  requiereReintento,
  fallidaPermanente,
  requiereRevision,
}

class ColaSolicitudesOffline {
  static const _key = 'cola_solicitudes_offline';
  static Future<void> _operacion = Future.value();

  Future<List<SolicitudPendienteOffline>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    final crudo = prefs.getStringList(_key) ?? const [];
    return crudo
        .map(
          (s) => SolicitudPendienteOffline.fromJson(
            jsonDecode(s) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<bool> agregar(SolicitudPendienteOffline pendiente) async {
    var agregada = false;
    final previa = _operacion;
    final completa = Completer<void>();
    _operacion = completa.future;
    await previa;
    try {
      final prefs = await SharedPreferences.getInstance();
      final actuales = await leer();
      final duplicada = actuales.any(
        (p) =>
            p.usuarioId == pendiente.usuarioId &&
            (p.idempotencyKey == pendiente.idempotencyKey ||
                p.payloadFingerprint == pendiente.payloadFingerprint) &&
            !{
              EstadoSolicitudOffline.sincronizada,
              EstadoSolicitudOffline.fallidaPermanente,
            }.contains(p.estado),
      );
      if (!duplicada) {
        await prefs.setStringList(_key, [
          ...actuales.map((p) => jsonEncode(p.toJson())),
          jsonEncode(pendiente.toJson()),
        ]);
        agregada = true;
      }
    } finally {
      completa.complete();
    }
    return agregada;
  }

  Future<void> actualizar(SolicitudPendienteOffline pendiente) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .map(
            (p) => jsonEncode(
              p.idLocal == pendiente.idLocal ? pendiente.toJson() : p.toJson(),
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
    required this.usuarioId,
    required this.vehiculoId,
    required this.descripcion,
    required this.creadaEn,
    this.fotoPath,
  });

  final String idLocal;
  final String usuarioId;
  final String vehiculoId;
  final String descripcion;
  final DateTime creadaEn;
  final String? fotoPath;

  factory IncidenciaPendienteOffline.fromJson(Map<String, dynamic> json) {
    return IncidenciaPendienteOffline(
      idLocal: json['idLocal'] as String,
      usuarioId: json['usuarioId'] as String? ?? '',
      vehiculoId: json['vehiculoId'] as String,
      descripcion: json['descripcion'] as String,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      fotoPath: json['fotoPath'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'usuarioId': usuarioId,
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
    required this.usuarioId,
    required this.rol,
    required this.marimbaId,
    required this.tipoCombustible,
    required this.frente,
    this.kmInicio,
    this.horasEquipoMenorInicio,
    required this.creadaEn,
    this.idServidor,
    this.intentos = 0,
    this.ultimoError,
  });

  final String idLocal;
  final String usuarioId;
  final String rol;
  final String marimbaId;
  final String tipoCombustible;
  final String frente;
  final double? kmInicio;
  final double? horasEquipoMenorInicio;
  final DateTime creadaEn;

  /// `null` hasta que `POST /recorridos-marimba` responde con éxito.
  final String? idServidor;
  final int intentos;
  final String? ultimoError;

  factory RecorridoMarimbaPendienteOffline.fromJson(Map<String, dynamic> json) {
    return RecorridoMarimbaPendienteOffline(
      idLocal: json['idLocal'] as String,
      usuarioId: json['usuarioId'] as String? ?? '',
      rol: json['rol'] as String? ?? '',
      marimbaId: json['marimbaId'] as String,
      tipoCombustible: json['tipoCombustible'] as String? ?? '',
      frente: json['frente'] as String,
      kmInicio: (json['kmInicio'] as num?)?.toDouble(),
      horasEquipoMenorInicio: (json['horasEquipoMenorInicio'] as num?)
          ?.toDouble(),
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      idServidor: json['idServidor'] as String?,
      intentos: json['intentos'] as int? ?? 0,
      ultimoError: json['ultimoError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'usuarioId': usuarioId,
    'rol': rol,
    'marimbaId': marimbaId,
    'tipoCombustible': tipoCombustible,
    'frente': frente,
    'kmInicio': kmInicio,
    'horasEquipoMenorInicio': horasEquipoMenorInicio,
    'creadaEn': creadaEn.toIso8601String(),
    'idServidor': idServidor,
    'intentos': intentos,
    'ultimoError': ultimoError,
  };

  RecorridoMarimbaPendienteOffline conIdServidor(String idServidor) {
    return RecorridoMarimbaPendienteOffline(
      idLocal: idLocal,
      usuarioId: usuarioId,
      rol: rol,
      marimbaId: marimbaId,
      tipoCombustible: tipoCombustible,
      frente: frente,
      kmInicio: kmInicio,
      horasEquipoMenorInicio: horasEquipoMenorInicio,
      creadaEn: creadaEn,
      idServidor: idServidor,
      intentos: intentos,
      ultimoError: null,
    );
  }

  RecorridoMarimbaPendienteOffline conError(String error) =>
      RecorridoMarimbaPendienteOffline(
        idLocal: idLocal,
        usuarioId: usuarioId,
        rol: rol,
        marimbaId: marimbaId,
        tipoCombustible: tipoCombustible,
        frente: frente,
        kmInicio: kmInicio,
        horasEquipoMenorInicio: horasEquipoMenorInicio,
        creadaEn: creadaEn,
        idServidor: idServidor,
        intentos: intentos + 1,
        ultimoError: error,
      );
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

  Future<void> registrarError(String idLocal, String error) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .map(
            (p) => jsonEncode(
              (p.idLocal == idLocal ? p.conError(error) : p).toJson(),
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
    required this.usuarioId,
    required this.rol,
    required this.vehiculoDestinoId,
    required this.tipoCombustible,
    required this.operadorTexto,
    required this.horometro,
    required this.fotoHorometroPath,
    this.litrosDeclarados,
    this.medidorInicial,
    this.medidorFinal,
    this.fotoMedidorPath,
    this.fotoEvidenciaPath,
    this.ubicacion,
    this.observaciones,
    required this.creadaEn,
    this.intentos = 0,
    this.ultimoError,
  });

  final String idLocal;
  final String recorridoIdLocal;
  final String usuarioId;
  final String rol;
  final String vehiculoDestinoId;
  final String tipoCombustible;
  final String operadorTexto;
  final double horometro;
  final String fotoHorometroPath;
  final double? litrosDeclarados;
  final double? medidorInicial;
  final double? medidorFinal;
  final String? fotoMedidorPath;
  final String? fotoEvidenciaPath;
  final String? ubicacion;
  final String? observaciones;
  final DateTime creadaEn;
  final int intentos;
  final String? ultimoError;

  bool get esMedido => medidorInicial != null && medidorFinal != null;

  factory DespachoMarimbaPendienteOffline.fromJson(Map<String, dynamic> json) {
    return DespachoMarimbaPendienteOffline(
      idLocal: json['idLocal'] as String,
      recorridoIdLocal: json['recorridoIdLocal'] as String,
      usuarioId: json['usuarioId'] as String? ?? '',
      rol: json['rol'] as String? ?? '',
      vehiculoDestinoId: json['vehiculoDestinoId'] as String? ?? '',
      tipoCombustible: json['tipoCombustible'] as String? ?? '',
      operadorTexto: json['operadorTexto'] as String,
      horometro: (json['horometro'] as num?)?.toDouble() ?? 0,
      fotoHorometroPath: json['fotoHorometroPath'] as String? ?? '',
      litrosDeclarados: (json['litrosDeclarados'] as num?)?.toDouble(),
      medidorInicial: (json['medidorInicial'] as num?)?.toDouble(),
      medidorFinal: (json['medidorFinal'] as num?)?.toDouble(),
      fotoMedidorPath: json['fotoMedidorPath'] as String?,
      fotoEvidenciaPath: json['fotoEvidenciaPath'] as String?,
      ubicacion: json['ubicacion'] as String?,
      observaciones: json['observaciones'] as String?,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      intentos: json['intentos'] as int? ?? 0,
      ultimoError: json['ultimoError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'recorridoIdLocal': recorridoIdLocal,
    'usuarioId': usuarioId,
    'rol': rol,
    'vehiculoDestinoId': vehiculoDestinoId,
    'tipoCombustible': tipoCombustible,
    'operadorTexto': operadorTexto,
    'horometro': horometro,
    'fotoHorometroPath': fotoHorometroPath,
    'litrosDeclarados': litrosDeclarados,
    'medidorInicial': medidorInicial,
    'medidorFinal': medidorFinal,
    'fotoMedidorPath': fotoMedidorPath,
    'fotoEvidenciaPath': fotoEvidenciaPath,
    'ubicacion': ubicacion,
    'observaciones': observaciones,
    'creadaEn': creadaEn.toIso8601String(),
    'intentos': intentos,
    'ultimoError': ultimoError,
  };

  DespachoMarimbaPendienteOffline conError(String error) =>
      DespachoMarimbaPendienteOffline(
        idLocal: idLocal,
        recorridoIdLocal: recorridoIdLocal,
        usuarioId: usuarioId,
        rol: rol,
        vehiculoDestinoId: vehiculoDestinoId,
        tipoCombustible: tipoCombustible,
        operadorTexto: operadorTexto,
        horometro: horometro,
        fotoHorometroPath: fotoHorometroPath,
        litrosDeclarados: litrosDeclarados,
        medidorInicial: medidorInicial,
        medidorFinal: medidorFinal,
        fotoMedidorPath: fotoMedidorPath,
        fotoEvidenciaPath: fotoEvidenciaPath,
        ubicacion: ubicacion,
        observaciones: observaciones,
        creadaEn: creadaEn,
        intentos: intentos + 1,
        ultimoError: error,
      );
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

  Future<void> registrarError(String idLocal, String error) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .map(
            (p) => jsonEncode(
              (p.idLocal == idLocal ? p.conError(error) : p).toJson(),
            ),
          )
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
    required this.usuarioId,
    required this.rol,
    this.kmCierre,
    this.horasEquipoMenorCierre,
    required this.fotoCierrePath,
    required this.fotoNivelPath,
    required this.existenciaFisica,
    this.observaciones,
    required this.creadaEn,
    this.intentos = 0,
    this.ultimoError,
  });

  final String idLocal;
  final String recorridoIdLocal;
  final String usuarioId;
  final String rol;
  final double? kmCierre;
  final double? horasEquipoMenorCierre;
  final String fotoCierrePath;
  final String fotoNivelPath;
  final double existenciaFisica;
  final String? observaciones;
  final DateTime creadaEn;
  final int intentos;
  final String? ultimoError;

  factory CierreRecorridoMarimbaPendienteOffline.fromJson(
    Map<String, dynamic> json,
  ) {
    return CierreRecorridoMarimbaPendienteOffline(
      idLocal: json['idLocal'] as String,
      recorridoIdLocal: json['recorridoIdLocal'] as String,
      usuarioId: json['usuarioId'] as String? ?? '',
      rol: json['rol'] as String? ?? '',
      kmCierre: (json['kmCierre'] as num?)?.toDouble(),
      horasEquipoMenorCierre: (json['horasEquipoMenorCierre'] as num?)
          ?.toDouble(),
      fotoCierrePath: json['fotoCierrePath'] as String,
      fotoNivelPath: json['fotoNivelPath'] as String? ?? '',
      existenciaFisica: (json['existenciaFisica'] as num?)?.toDouble() ?? 0,
      observaciones: json['observaciones'] as String?,
      creadaEn: DateTime.parse(json['creadaEn'] as String),
      intentos: json['intentos'] as int? ?? 0,
      ultimoError: json['ultimoError'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'recorridoIdLocal': recorridoIdLocal,
    'usuarioId': usuarioId,
    'rol': rol,
    'kmCierre': kmCierre,
    'horasEquipoMenorCierre': horasEquipoMenorCierre,
    'fotoCierrePath': fotoCierrePath,
    'fotoNivelPath': fotoNivelPath,
    'existenciaFisica': existenciaFisica,
    'observaciones': observaciones,
    'creadaEn': creadaEn.toIso8601String(),
    'intentos': intentos,
    'ultimoError': ultimoError,
  };

  CierreRecorridoMarimbaPendienteOffline conError(String error) =>
      CierreRecorridoMarimbaPendienteOffline(
        idLocal: idLocal,
        recorridoIdLocal: recorridoIdLocal,
        usuarioId: usuarioId,
        rol: rol,
        kmCierre: kmCierre,
        horasEquipoMenorCierre: horasEquipoMenorCierre,
        fotoCierrePath: fotoCierrePath,
        fotoNivelPath: fotoNivelPath,
        existenciaFisica: existenciaFisica,
        observaciones: observaciones,
        creadaEn: creadaEn,
        intentos: intentos + 1,
        ultimoError: error,
      );
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

  Future<void> registrarError(String idLocal, String error) async {
    final prefs = await SharedPreferences.getInstance();
    final actuales = await leer();
    await prefs.setStringList(
      _key,
      actuales
          .map(
            (p) => jsonEncode(
              (p.idLocal == idLocal ? p.conError(error) : p).toJson(),
            ),
          )
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
    await prefs.setStringList(_key, [...actuales, jsonEncode(aviso.toJson())]);
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
  final usuarioId = ref.watch(sessionProvider)?.id;
  final solicitudes = await ref.read(colaSolicitudesOfflineProvider).leer();
  final resultados = await Future.wait([
    ref.read(colaComprobarCargaOfflineProvider).leer(),
    ref.read(colaCerrarDiaOfflineProvider).leer(),
    ref.read(colaIncidenciasOfflineProvider).leer(),
    ref.read(colaRecorridosMarimbaOfflineProvider).leer(),
    ref.read(colaDespachosMarimbaOfflineProvider).leer(),
    ref.read(colaCierresRecorridoMarimbaOfflineProvider).leer(),
  ]);
  return solicitudes.where((p) => p.usuarioId == usuarioId).length +
      resultados.fold<int>(0, (suma, lista) => suma + lista.length);
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
    if (pendiente.usuarioId != choferId ||
        pendiente.estado == EstadoSolicitudOffline.sincronizada ||
        pendiente.estado == EstadoSolicitudOffline.fallidaPermanente ||
        pendiente.estado == EstadoSolicitudOffline.requiereRevision ||
        (pendiente.proximoIntento?.isAfter(DateTime.now()) ?? false)) {
      continue;
    }
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
      await cola.actualizar(
        pendiente.copiar(estado: EstadoSolicitudOffline.sincronizando),
      );
      await repo.enviarSolicitud(
        idempotencyKey: pendiente.idempotencyKey,
        payloadFingerprint: pendiente.payloadFingerprint,
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
        final intentos = pendiente.intentos + 1;
        final segundos =
            (1 << intentos.clamp(0, 8)) +
            (pendiente.idLocal.hashCode.abs() % 4);
        await cola.actualizar(
          pendiente.copiar(
            estado: EstadoSolicitudOffline.enviadaSinConfirmar,
            intentos: intentos,
            ultimoError: e.mensaje,
            proximoIntento: DateTime.now().add(Duration(seconds: segundos)),
          ),
        );
        return;
      }
      if (e.codigo == 'SOLICITUD_PENDIENTE_EXISTENTE' &&
          e.solicitudId != null) {
        await cola.quitar(pendiente.idLocal);
      } else {
        final transitorio = {408, 429, 500, 502, 503, 504}.contains(e.status);
        await cola.actualizar(
          pendiente.copiar(
            estado: transitorio
                ? EstadoSolicitudOffline.requiereReintento
                : e.status == 409
                ? EstadoSolicitudOffline.requiereRevision
                : EstadoSolicitudOffline.fallidaPermanente,
            intentos: pendiente.intentos + 1,
            ultimoError: e.mensaje,
            proximoIntento: transitorio
                ? DateTime.now().add(
                    Duration(
                      seconds: 1 << (pendiente.intentos + 1).clamp(0, 8),
                    ),
                  )
                : null,
          ),
        );
      }
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
  final usuarioActualId = ref.read(sessionProvider)?.id;

  for (final pendiente in pendientes) {
    if (pendiente.choferId != usuarioActualId) continue;
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
  final usuarioActualId = ref.read(sessionProvider)?.id;

  for (final pendiente in pendientes) {
    if (pendiente.usuarioId != usuarioActualId) continue;
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
  final perfil = ref.read(sessionProvider);
  if (perfil == null || !perfil.esSupervisor) return;
  final colaRecorridos = ref.read(colaRecorridosMarimbaOfflineProvider);
  final colaDespachos = ref.read(colaDespachosMarimbaOfflineProvider);
  final colaCierres = ref.read(colaCierresRecorridoMarimbaOfflineProvider);
  final recorridos = await colaRecorridos.leer();
  if (recorridos.isEmpty) return;

  final repo = ref.read(recorridosMarimbaRepositoryProvider);

  for (final recorrido in recorridos) {
    if (recorrido.usuarioId != perfil.id || recorrido.rol != perfil.rol.name) {
      continue;
    }
    var idServidor = recorrido.idServidor;
    if (idServidor == null) {
      if (recorrido.tipoCombustible.isEmpty) {
        await colaRecorridos.registrarError(
          recorrido.idLocal,
          'El recorrido pendiente no identifica el combustible.',
        );
        continue;
      }
      try {
        final creado = await repo.abrirRecorrido(
          marimbaId: recorrido.marimbaId,
          tipoCombustible: recorrido.tipoCombustible,
          frente: recorrido.frente,
          kmInicio: recorrido.kmInicio,
          horasEquipoMenorInicio: recorrido.horasEquipoMenorInicio,
        );
        idServidor = creado.id;
        await colaRecorridos.actualizarIdServidor(
          recorrido.idLocal,
          idServidor,
        );
      } on ApiException catch (e) {
        // Sin señal de verdad — probablemente todos los recorridos
        // pendientes fallarían igual ahora mismo, se reintenta en el
        // próximo evento de reconexión.
        if (e.status == null) return;
        await colaRecorridos.registrarError(recorrido.idLocal, e.mensaje);
        ref.read(operacionesTickProvider.notifier).state++;
        continue;
      }
    }

    final despachosDelRecorrido = (await colaDespachos.leer())
        .where(
          (d) =>
              d.recorridoIdLocal == recorrido.idLocal &&
              d.usuarioId == perfil.id &&
              d.rol == perfil.rol.name,
        )
        .toList();
    var despachoFallido = false;
    for (final despacho in despachosDelRecorrido) {
      final archivos = <String?>[
        despacho.fotoHorometroPath,
        despacho.fotoMedidorPath,
        despacho.fotoEvidenciaPath,
      ].whereType<String>();
      if (archivos.any((ruta) => ruta.isEmpty || !File(ruta).existsSync())) {
        await colaDespachos.registrarError(
          despacho.idLocal,
          'Una evidencia del despacho ya no existe en el dispositivo.',
        );
        despachoFallido = true;
        break;
      }
      try {
        await repo.agregarDespacho(
          recorridoId: idServidor,
          tipoCombustible: despacho.tipoCombustible,
          vehiculoDestinoId: despacho.vehiculoDestinoId,
          operadorTexto: despacho.operadorTexto,
          horometro: despacho.horometro,
          fotoHorometroPath: despacho.fotoHorometroPath,
          litrosDeclarados: despacho.litrosDeclarados,
          medidorInicial: despacho.medidorInicial,
          medidorFinal: despacho.medidorFinal,
          fotoMedidorPath: despacho.fotoMedidorPath,
          fotoEvidenciaPath: despacho.fotoEvidenciaPath,
          ubicacion: despacho.ubicacion,
          observaciones: despacho.observaciones,
        );
        await colaDespachos.quitar(despacho.idLocal);
      } on ApiException catch (e) {
        if (e.status == null) {
          return;
        }
        await colaDespachos.registrarError(despacho.idLocal, e.mensaje);
        despachoFallido = true;
        break;
      }
      ref.read(operacionesTickProvider.notifier).state++;
    }
    if (despachoFallido) continue;

    final quedanDespachosPendientes = (await colaDespachos.leer()).any(
      (d) => d.recorridoIdLocal == recorrido.idLocal,
    );
    if (quedanDespachosPendientes) continue;

    final cierre = (await colaCierres.leer())
        .where(
          (c) =>
              c.recorridoIdLocal == recorrido.idLocal &&
              c.usuarioId == perfil.id &&
              c.rol == perfil.rol.name,
        )
        .toList();
    if (cierre.isEmpty) continue;
    final pendienteCierre = cierre.first;

    if (!File(pendienteCierre.fotoCierrePath).existsSync() ||
        !File(pendienteCierre.fotoNivelPath).existsSync()) {
      await colaCierres.registrarError(
        pendienteCierre.idLocal,
        'Una evidencia del cierre ya no existe en el dispositivo.',
      );
      continue;
    }
    try {
      await repo.cerrarRecorrido(
        recorridoId: idServidor,
        kmCierre: pendienteCierre.kmCierre,
        horasEquipoMenorCierre: pendienteCierre.horasEquipoMenorCierre,
        fotoCierrePath: pendienteCierre.fotoCierrePath,
        fotoNivelPath: pendienteCierre.fotoNivelPath,
        existenciaFisica: pendienteCierre.existenciaFisica,
        observaciones: pendienteCierre.observaciones,
      );
      await colaCierres.quitar(pendienteCierre.idLocal);
      await colaRecorridos.quitar(recorrido.idLocal);
    } on ApiException catch (e) {
      if (e.status == null) return;
      await colaCierres.registrarError(pendienteCierre.idLocal, e.mensaje);
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
  final perfil = ref.read(sessionProvider);
  if (perfil == null || (!perfil.esChofer && !perfil.esSupervisor)) return;
  final existente = _sincronizacionesSolicitudes[perfil.id];
  if (existente != null) return existente;
  final futura = _sincronizarSolicitudes(ref);
  _sincronizacionesSolicitudes[perfil.id] = futura;
  try {
    await futura;
  } finally {
    if (identical(_sincronizacionesSolicitudes[perfil.id], futura)) {
      _sincronizacionesSolicitudes.remove(perfil.id);
    }
  }
  await _sincronizarComprobarCarga(ref);
  await _sincronizarCerrarDia(ref);
  await _sincronizarIncidencias(ref);
  await _sincronizarRecorridosMarimba(ref);
}

final Map<String, Future<void>> _sincronizacionesSolicitudes = {};

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
  final perfil = ref.read(sessionProvider);
  bool? anterior = ref.read(conectividadProvider).valueOrNull;
  final controlInicial = ref.read(_sesionSincronizacionInicialProvider);
  if (perfil == null) {
    controlInicial.usuarioId = null;
    controlInicial.intentoRealizado = false;
  } else if (controlInicial.usuarioId != perfil.id) {
    controlInicial.usuarioId = perfil.id;
    controlInicial.intentoRealizado = false;
    if (anterior == true) {
      controlInicial.intentoRealizado = true;
      unawaited(sincronizarSolicitudesOffline(ref));
    }
  }
  ref.listen<AsyncValue<bool>>(conectividadProvider, (previous, next) {
    final actual = next.valueOrNull;
    if (actual == true &&
        (anterior == false || !controlInicial.intentoRealizado)) {
      controlInicial.intentoRealizado = true;
      sincronizarSolicitudesOffline(ref);
    }
    anterior = actual;
  });
}

class _ControlSincronizacionInicial {
  String? usuarioId;
  bool intentoRealizado = false;
}

final _sesionSincronizacionInicialProvider = Provider(
  (ref) => _ControlSincronizacionInicial(),
);
