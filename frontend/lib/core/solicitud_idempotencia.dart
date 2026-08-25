import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../models/solicitud_autorizacion.dart';

const _uuid = Uuid();

String nuevaIdempotencyKey() => _uuid.v4();

String _texto(String? valor) =>
    (valor ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

Future<String> sha256DeArchivo(String? ruta) async {
  if (ruta == null) return '';
  // La evidencia ya esta limitada a 10 MB. Leerla en una sola operacion
  // evita que un reintento dependa del scheduler (y que dos consumidores
  // calculen identidades en momentos distintos) antes de persistir la cola.
  return sha256.convert(File(ruta).readAsBytesSync()).toString();
}

Future<String> fingerprintSolicitud({
  required String choferId,
  required String vehiculoId,
  required double litrosSolicitados,
  required bool esUrgente,
  required String? motivoChofer,
  required String actividad,
  required DateTime fechaProgramada,
  required String? fotoTableroPath,
  List<SolicitudPartida>? partidas,
}) async {
  final partidasCanonicas = [...?partidas]
    ..sort((a, b) => a.tipoApi.compareTo(b.tipoApi));
  final fotoSha256 = await sha256DeArchivo(fotoTableroPath);
  final canonico = <String, Object>{
    'choferId': choferId,
    'vehiculoId': vehiculoId,
    'categoria': partidasCanonicas.isEmpty ? 'unidad' : 'partidas',
    'litros': litrosSolicitados.toStringAsFixed(2),
    'urgente': esUrgente,
    'fechaProgramada': fechaProgramada.toUtc().toIso8601String().substring(
      0,
      10,
    ),
    'actividad': _texto(actividad),
    'motivo': _texto(motivoChofer),
    'partidas': partidasCanonicas
        .map(
          (p) => <String, Object>{
            'tipo': p.tipoApi,
            'litros': p.litrosSolicitados.toStringAsFixed(2),
            'tipoCombustible': p.tipoCombustible,
            'observaciones': _texto(p.observaciones),
          },
        )
        .toList(growable: false),
    'fotoSha256': fotoSha256,
  };
  return sha256.convert(utf8.encode(jsonEncode(canonico))).toString();
}
