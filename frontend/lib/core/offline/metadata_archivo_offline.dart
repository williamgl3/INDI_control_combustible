import 'dart:convert';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Metadata serializable de un archivo persistido en [AlmacenamientoOffline].
///
/// No contiene bytes — solo la información necesaria para localizar, verificar
/// integridad y rearmar el campo multipart al enviar.
class MetadataArchivoOffline {
  MetadataArchivoOffline({
    required this.storageKey,
    required this.sizeBytes,
    required this.sha256,
    required this.multipartField,
    this.mimeType = 'image/jpeg',
    this.originalName,
  });

  factory MetadataArchivoOffline.nueva({
    required int sizeBytes,
    required String sha256,
    required String multipartField,
    String mimeType = 'image/jpeg',
    String? originalName,
  }) {
    return MetadataArchivoOffline(
      storageKey: _uuid.v4(),
      sizeBytes: sizeBytes,
      sha256: sha256,
      multipartField: multipartField,
      mimeType: mimeType,
      originalName: originalName,
    );
  }

  factory MetadataArchivoOffline.fromJson(Map<String, dynamic> json) {
    return MetadataArchivoOffline(
      storageKey: json['storageKey'] as String,
      sizeBytes: json['sizeBytes'] as int,
      sha256: json['sha256'] as String,
      multipartField: json['multipartField'] as String,
      mimeType: json['mimeType'] as String? ?? 'image/jpeg',
      originalName: json['originalName'] as String?,
    );
  }

  final String storageKey;
  final int sizeBytes;
  final String sha256;
  final String multipartField;
  final String mimeType;
  final String? originalName;

  Map<String, dynamic> toJson() => {
    'storageKey': storageKey,
    'sizeBytes': sizeBytes,
    'sha256': sha256,
    'multipartField': multipartField,
    'mimeType': mimeType,
    if (originalName != null) 'originalName': originalName,
  };

  /// Serializa a JSON string para almacenamiento en SharedPreferences.
  String serializar() => jsonEncode(toJson());

  /// Deserializa desde un JSON string.
  static MetadataArchivoOffline? deserializar(String? texto) {
    if (texto == null || texto.isEmpty) return null;
    try {
      final json = jsonDecode(texto) as Map<String, dynamic>;
      return MetadataArchivoOffline.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetadataArchivoOffline &&
          runtimeType == other.runtimeType &&
          storageKey == other.storageKey &&
          sizeBytes == other.sizeBytes &&
          sha256 == other.sha256 &&
          multipartField == other.multipartField;

  @override
  int get hashCode => Object.hash(storageKey, sizeBytes, sha256, multipartField);
}
