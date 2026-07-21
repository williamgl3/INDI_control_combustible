import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Registro centralizado de errores de la app.
///
/// Antes de esto no había NINGÚN rastro de lo que fallaba fuera de lo que
/// se mostraba en pantalla — si algo tronaba en el celular de un chofer
/// en obra, nadie se enteraba. `AppLogger` no reemplaza un servicio real
/// de monitoreo (Sentry/Crashlytics), pero deja un archivo local
/// (`app_errores.log`, en el directorio de soporte de la app) con los
/// últimos errores — suficiente para pedirle a un usuario "mándame el
/// archivo de errores" cuando reporte un problema.
class AppLogger {
  AppLogger._();

  static File? _archivo;
  static bool _inicializando = false;

  /// Máximo de bytes que se conservan del log — al pasarse, se trunca
  /// desde el inicio para no crecer indefinidamente en el dispositivo.
  static const _maxBytes = 512 * 1024;

  static Future<void> _asegurarArchivo() async {
    if (_archivo != null || _inicializando) return;
    _inicializando = true;
    try {
      final dir = await getApplicationSupportDirectory();
      _archivo = File('${dir.path}/app_errores.log');
    } catch (_) {
      // Sin acceso al filesystem (ej. algunos entornos de test) — el
      // logging sigue funcionando vía `developer.log`, solo sin archivo.
    } finally {
      _inicializando = false;
    }
  }

  /// Registra un error con su contexto. `contexto` debe ser algo
  /// identificable (ej. "ApiClient.get /solicitudes", nombre de pantalla)
  /// para poder rastrear de dónde vino sin stack trace completo.
  static void error(
    String contexto,
    Object error, {
    StackTrace? stackTrace,
  }) {
    final linea =
        '[${DateTime.now().toIso8601String()}] ERROR $contexto: $error';

    developer.log(
      contexto,
      name: 'AppLogger',
      error: error,
      stackTrace: stackTrace,
      level: 1000,
    );

    // Efecto de lado (escribir a disco) disparado sin bloquear al
    // llamador — el logging nunca debe frenar el flujo de la app.
    unawaited(_escribir(linea));
  }

  static Future<void> _escribir(String linea) async {
    await _asegurarArchivo();
    final archivo = _archivo;
    if (archivo == null) return;
    try {
      await archivo.writeAsString('$linea\n', mode: FileMode.append);
      final tamano = await archivo.length();
      if (tamano > _maxBytes) {
        final contenido = await archivo.readAsString();
        await archivo.writeAsString(
          contenido.substring(contenido.length - (_maxBytes ~/ 2)),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        // ignore: avoid_print
        print('AppLogger no pudo escribir a disco: $e');
      }
    }
  }

  /// Ruta del archivo de log, si ya se inicializó — útil para una
  /// pantalla de soporte que ofrezca compartirlo.
  static Future<String?> rutaArchivo() async {
    await _asegurarArchivo();
    return _archivo?.path;
  }
}
