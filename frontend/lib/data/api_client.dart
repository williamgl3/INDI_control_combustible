import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../core/app_logger.dart';
import '../core/token_storage.dart';

final _storageKeyArchivoPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\.(?:jpe?g|png|webp|heic|heif)$',
  caseSensitive: false,
);

/// Convierte únicamente referencias internas controladas al endpoint
/// privado. Rechaza hosts, schemes, query strings y rutas arbitrarias.
String normalizarReferenciaArchivo(String referencia) {
  final uri = Uri.tryParse(referencia);
  if (uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      uri.hasQuery ||
      uri.hasFragment) {
    throw ApiException('La referencia del archivo no es válida.');
  }
  final segmentos = uri.pathSegments;
  if (segmentos.length != 2 ||
      (segmentos.first != 'uploads' && segmentos.first != 'archivos')) {
    throw ApiException('La referencia del archivo no es válida.');
  }
  final storageKey = segmentos.last;
  if (!_storageKeyArchivoPattern.hasMatch(storageKey)) {
    throw ApiException('La referencia del archivo no es válida.');
  }
  return '/archivos/$storageKey';
}

/// Excepción lanzada por [ApiClient] cuando el backend responde con un
/// error, con un mensaje ya listo para mostrar al usuario (el backend
/// siempre responde `{ "error": "mensaje" }` — ver `errorHandler.ts`).
class ApiException implements Exception {
  ApiException(this.mensaje, {this.status, this.codigo, this.solicitudId});
  final String mensaje;
  final int? status;
  final String? codigo;
  final String? solicitudId;

  @override
  String toString() => mensaje;
}

/// Cliente HTTP compartido por todos los repositorios reales: agrega el
/// token JWT (si hay uno guardado) a cada petición y traduce las
/// respuestas de error del backend a [ApiException].
class ApiClient {
  ApiClient({
    required this._tokenStorage,
    http.Client? httpClient,
    this.onSesionExpirada,
  }) : _http = httpClient ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _http;
  Future<bool>? _refreshEnCurso;

  /// Se llama cuando un 401 no se pudo resolver ni con refresh token —
  /// además de borrar el storage (ver `_limpiarSesionExpirada`), esto es
  /// lo que de verdad saca al usuario a la pantalla de login EN VIVO
  /// (mientras sigue usando la app), no solo en el próximo arranque.
  /// `ApiClient` es una clase de capa de datos sin acceso a `ref`/
  /// providers — quien lo construye (`apiClientProvider`) inyecta aquí la
  /// notificación a `sessionProvider`, en vez de que este archivo dependa
  /// de Riverpod directamente.
  final void Function()? onSesionExpirada;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _tokenStorage.leerToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Intenta renovar el access token con el refresh token guardado
  /// (`POST /refresh`). Devuelve `true` si obtuvo y guardó un par de
  /// tokens nuevo. No lanza — cualquier falla (sin refresh token, refresh
  /// token vencido, sin conexión) se traduce a `false`, para que quien
  /// llama decida qué hacer (reintentar una vez, o limpiar la sesión).
  Future<bool> _intentarRefrescarToken() async {
    final refreshToken = await _tokenStorage.leerRefreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await _http.post(
        _uri('/refresh'),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final nuevoToken = data['token'] as String?;
      final nuevoRefreshToken = data['refreshToken'] as String?;
      if (nuevoToken == null || nuevoRefreshToken == null) return false;
      await _tokenStorage.guardarToken(nuevoToken);
      await _tokenStorage.guardarRefreshToken(nuevoRefreshToken);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Comparte una sola rotación de refresh token entre todas las peticiones
  /// que fallen con 401 al mismo tiempo. El backend rota el token en cada uso;
  /// enviarlo en paralelo haría que una de las solicitudes use un token que
  /// la otra acaba de revocar.
  Future<bool> _refrescarTokenUnaVez() {
    final existente = _refreshEnCurso;
    if (existente != null) return existente;

    final futuro = _intentarRefrescarToken();
    _refreshEnCurso = futuro;
    futuro.whenComplete(() {
      if (identical(_refreshEnCurso, futuro)) {
        _refreshEnCurso = null;
      }
    });
    return futuro;
  }

  /// Borra ambos tokens y notifica [onSesionExpirada]. El guard de rutas
  /// (`app_router.dart`) reacciona solo a `sessionProvider`, no a
  /// `TokenStorage` directamente — sin el callback, la sesión quedaba
  /// "colgada" en memoria (tokens borrados pero `sessionProvider` seguía
  /// con el perfil viejo) hasta el siguiente arranque de la app, que sí
  /// revisa el token en `AuthController.restaurarSesionAlIniciar` antes
  /// de confiar en el perfil persistido.
  Future<void> _limpiarSesionExpirada() async {
    await _tokenStorage.borrarToken();
    await _tokenStorage.borrarRefreshToken();
    onSesionExpirada?.call();
  }

  /// Envía una petición ya armada por [enviar] y, si responde 401 (access
  /// token expirado — dura solo 15 min, así que va a pasar seguido),
  /// intenta refrescar el token UNA vez y reintenta la petición original
  /// también una sola vez. Si el refresh falla, limpia la sesión (incluido
  /// [onSesionExpirada], que saca al usuario a `/login` DE INMEDIATO, no
  /// solo en el próximo arranque de la app) y deja que la respuesta 401
  /// original se propague como [ApiException].
  Future<http.Response> _respuestaConReintentoDeToken(
    Future<http.Response> Function() enviar,
  ) async {
    final res = await enviar();
    if (res.statusCode != 401) return res;

    final refrescado = await _refrescarTokenUnaVez();
    if (!refrescado) {
      await _limpiarSesionExpirada();
      return res;
    }
    final res2 = await enviar();
    if (res2.statusCode == 401) {
      await _limpiarSesionExpirada();
    }
    return res2;
  }

  Future<dynamic> _conReintentoDeToken(
    Future<http.Response> Function() enviar,
  ) async {
    return _decode(await _respuestaConReintentoDeToken(enviar));
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    var mensaje = 'Ocurrió un error. Intenta de nuevo.';
    String? codigo;
    String? solicitudId;
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['error'] is String) {
        mensaje = body['error'] as String;
        codigo = body['codigo'] as String?;
        solicitudId = body['solicitudId'] as String?;
      }
    } catch (_) {
      // Respuesta de error sin cuerpo JSON válido — se conserva el
      // mensaje genérico de arriba.
    }
    AppLogger.error(
      'ApiClient ${res.request?.method} ${res.request?.url.path}',
      'HTTP ${res.statusCode}: $mensaje',
    );
    throw ApiException(
      mensaje,
      status: res.statusCode,
      codigo: codigo,
      solicitudId: solicitudId,
    );
  }

  /// Envuelve cualquier llamada HTTP: registra en [AppLogger] las fallas
  /// de RED (sin conexión, DNS, timeout) — que nunca llegan a [_decode]
  /// porque el propio cliente `http` truena antes de tener una respuesta
  /// — y las traduce a un mensaje claro para el usuario en vez de dejar
  /// pasar la excepción cruda de `dart:io`/`http`.
  Future<T> _conManejoDeErrores<T>(
    String contexto,
    Future<T> Function() fn,
  ) async {
    try {
      return await fn();
    } on ApiException {
      rethrow;
    } on SocketException catch (e, st) {
      AppLogger.error(contexto, e, stackTrace: st);
      throw ApiException('Sin conexión a internet. Intenta de nuevo.');
    } on HttpException catch (e, st) {
      AppLogger.error(contexto, e, stackTrace: st);
      throw ApiException('No pudimos conectar con el servidor.');
    } catch (e, st) {
      AppLogger.error(contexto, e, stackTrace: st);
      throw ApiException('Ocurrió un error. Intenta de nuevo.');
    }
  }

  Future<dynamic> get(String path) {
    return _conManejoDeErrores('ApiClient.get $path', () async {
      return _conReintentoDeToken(
        () async => _http.get(_uri(path), headers: await _headers()),
      );
    });
  }

  /// Descarga una evidencia mediante el endpoint privado. Los bytes no se
  /// registran ni se decodifican como JSON; los errores conservan el manejo
  /// y la renovación de sesión usados por el resto del cliente.
  Future<Uint8List> descargarArchivo(String referencia) {
    return _conManejoDeErrores('ApiClient.descargarArchivo', () async {
      final path = normalizarReferenciaArchivo(referencia);
      final respuesta = await _respuestaConReintentoDeToken(
        () async => _http.get(_uri(path), headers: await _headers(json: false)),
      );
      if (respuesta.statusCode < 200 || respuesta.statusCode >= 300) {
        _decode(respuesta);
      }
      return respuesta.bodyBytes;
    });
  }

  Future<dynamic> post(String path, {Object? body}) {
    return _conManejoDeErrores('ApiClient.post $path', () async {
      return _conReintentoDeToken(
        () async => _http.post(
          _uri(path),
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        ),
      );
    });
  }

  Future<dynamic> patch(String path, {Object? body}) {
    return _conManejoDeErrores('ApiClient.patch $path', () async {
      return _conReintentoDeToken(
        () async => _http.patch(
          _uri(path),
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        ),
      );
    });
  }

  Future<dynamic> delete(String path, {Object? body}) {
    return _conManejoDeErrores('ApiClient.delete $path', () async {
      return _conReintentoDeToken(
        () async => _http.delete(
          _uri(path),
          headers: await _headers(),
          body: body == null ? null : jsonEncode(body),
        ),
      );
    });
  }

  /// POST multipart — para /cargas y /cierres-dia, que reciben las fotos
  /// como `multipart/form-data` (ver `middleware/upload.ts`). `campos`
  /// son los valores de texto/número; `archivos` mapea el nombre del
  /// campo del formulario a la ruta local del archivo (`null`/ausente si
  /// esa foto no se tomó).
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> campos,
    Map<String, String> headers = const {},
    Map<String, String?> archivos = const {},
    // Igual que `archivos`, pero para campos que aceptan varios archivos
    // bajo el mismo nombre (ej. `fotos`, hasta 5) — multer/el backend los
    // lee como una lista por ese campo.
    Map<String, List<String>> archivosMultiples = const {},
  }) {
    return _conManejoDeErrores('ApiClient.postMultipart $path', () async {
      Future<http.Response> enviar() async {
        final uri = _uri(path);
        final req = http.MultipartRequest('POST', uri);
        req.headers.addAll(await _headers(json: false));
        req.headers.addAll(headers);
        req.fields.addAll(campos);
        for (final entry in archivos.entries) {
          final ruta = entry.value;
          if (ruta == null) continue;
          if (!await File(ruta).exists()) {
            throw ApiException('No se encontró la evidencia seleccionada.');
          }
          req.files.add(await http.MultipartFile.fromPath(entry.key, ruta));
        }
        for (final entry in archivosMultiples.entries) {
          for (final ruta in entry.value) {
            if (!await File(ruta).exists()) {
              throw ApiException('No se encontró una evidencia seleccionada.');
            }
            req.files.add(await http.MultipartFile.fromPath(entry.key, ruta));
          }
        }
        if (kDebugMode) {
          final camposDebug = <String, Object?>{
            for (final entry in campos.entries)
              entry.key: entry.key.toLowerCase().contains('motivo')
                  ? '<redacted>'
                  : entry.value,
          };
          debugPrint('POST multipart $uri');
          debugPrint('Token presente: ${req.headers['Authorization'] != null}');
          debugPrint('Campos: $camposDebug');
          debugPrint(
            'Archivos: ${archivos.entries.map((e) => '${e.key}=${e.value != null}').join(', ')}',
          );
        }
        final streamed = await _http.send(req);
        final response = await http.Response.fromStream(streamed);
        if (kDebugMode) {
          final body = response.body;
          debugPrint(
            'Respuesta POST multipart ${response.statusCode}: '
            '${body.length > 1000 ? '${body.substring(0, 1000)}…' : body}',
          );
        }
        return response;
      }

      return _conReintentoDeToken(enviar);
    });
  }
}
