import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Genera un archivo (hoy: CSV, que Excel abre nativamente) y lo entrega
/// al usuario — en el propio dispositivo, sin backend. Abstraído para
/// poder sustituirse por un fake en widget tests (no hay filesystem ni
/// hoja de compartir real disponibles ahí).
abstract class ExportadorService {
  Future<void> exportarCsv({
    required String nombreArchivo,
    required String contenidoCsv,
  });
}

class ArchivoExportadorService implements ExportadorService {
  const ArchivoExportadorService();

  @override
  Future<void> exportarCsv({
    required String nombreArchivo,
    required String contenidoCsv,
  }) async {
    final directorio = await getTemporaryDirectory();
    final archivo = File('${directorio.path}/$nombreArchivo');
    await archivo.writeAsString(contenidoCsv);
    await Share.shareXFiles([
      XFile(archivo.path),
    ], text: 'Concentrado de cargas de combustible — INDI Combustible');
  }
}
