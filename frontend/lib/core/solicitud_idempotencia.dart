import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:uuid/uuid.dart';

import '../models/solicitud_autorizacion.dart';

const _uuid = Uuid();

String nuevaIdempotencyKey() => _uuid.v4();

String _texto(String? valor) =>
    (valor ?? '').trim().replaceAll(RegExp(r'\s+'), ' ');

/// Calcula SHA-256 de los bytes dados. Usado para archivos durables
/// donde los bytes ya están en memoria.
String sha256DeBytes(Uint8List bytes) => sha256.convert(bytes).toString();

/// Calcula SHA-256 de un archivo en disco. Se mantiene para backward
/// compatibility con código existente que aún usa rutas.
Future<String> sha256DeArchivo(String? ruta) async {
  if (ruta == null) return '';
  return sha256DeBytes(File(ruta).readAsBytesSync());
}

Future<String> fingerprintEvidencia({
  required String usuarioId,
  required String tipo,
  double? km,
  String? folioId,
  String? cargaId,
  bool pendienteVincular = false,
  String? notas,
  String? tipoCombustibleCargado,
  double? litros,
  double? precioPorLitro,
  double? montoPagado,
  required List<String> fotosSha256,
}) async {
  final canonico = <String, Object>{
    'usuarioId': usuarioId,
    'tipo': tipo,
    if (km != null) 'km': km.toStringAsFixed(2),
    'folioId': ?folioId,
    'cargaId': ?cargaId,
    'pendienteVincular': pendienteVincular,
    'notas': _texto(notas),
    'tipoCombustibleCargado': _texto(tipoCombustibleCargado),
    if (litros != null) 'litros': litros.toStringAsFixed(2),
    if (precioPorLitro != null)
      'precioPorLitro': precioPorLitro.toStringAsFixed(2),
    if (montoPagado != null) 'montoPagado': montoPagado.toStringAsFixed(2),
    'fotosSha256': fotosSha256,
  };
  return sha256.convert(utf8.encode(jsonEncode(canonico))).toString();
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
  String? fotoTableroSha256,
}) async {
  final partidasCanonicas = [...?partidas]
    ..sort((a, b) => a.tipoApi.compareTo(b.tipoApi));
  final fotoSha256 = fotoTableroSha256 ?? await sha256DeArchivo(fotoTableroPath);
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
