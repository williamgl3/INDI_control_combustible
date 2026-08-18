import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

abstract class ExportadorService {
  Future<void> exportarXlsx({
    required String nombreArchivo,
    required Uint8List contenido,
    required String descripcion,
  });
}

/// Entrega el libro desde memoria. `XFile.fromData` funciona tanto en Android
/// como en web y evita depender de `dart:io` o de rutas temporales que el
/// navegador no puede usar.
class ArchivoExportadorService implements ExportadorService {
  const ArchivoExportadorService();

  @override
  Future<void> exportarXlsx({
    required String nombreArchivo,
    required Uint8List contenido,
    required String descripcion,
  }) async {
    await Share.shareXFiles(
      [
        XFile.fromData(
          contenido,
          name: nombreArchivo,
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ),
      ],
      text: '$descripcion — INDI Combustible',
      fileNameOverrides: [nombreArchivo],
    );
  }
}
