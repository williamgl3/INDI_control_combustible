import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../core/app_logger.dart';
import '../core/token_storage.dart';

/// Excepción lanzada por [ApiClient] cuando el backend responde con un
/// error, con un mensaje ya listo para mostrar al usuario (el backend
/// siempre responde `{ "error": "mensaje" }` — ver `errorHandler.ts`).
class ApiException implements Exception {
  ApiException(this.mensaje, {this.status});
  final String mensaje;
  final int? status;

  @override
  String toString() => mensaje;
}

/// Cliente HTTP compartido por todos los repositorios reales: agrega el
/// token JWT (si hay uno guardado) a cada petición y traduce las
/// respuestas de error del backend a [ApiException].
class ApiClient {
  ApiClient({required TokenStorage tokenStorage, http.Client? httpClient})
    : _tokenStorage = tokenStorage,
      _http = httpClient ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _http;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<Map<String, String>> _headers({bool json = true}) async {
    final token = await _tokenStorage.leerToken();
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Intenta renovar el access token con el refresh token guardado
  /// (`POST /auth/refresh`). Devuelve `true` si obtuvo y guardó un par de
  /// tokens nuevo. No lanza — cualquier falla (sin refresh token, refresh
  /// token vencido, sin conexión) se traduce a `false`, para que quien
  /// llama decida qué hacer (reintentar una vez, o limpiar la sesión).
  Future<bool> _intentarRefrescarToken() async {
    final refreshToken = await _tokenStorage.leerRefreshToken();
    if (refreshToken == null) return false;
    try {
      final res = await _http.post(
        _uri('/auth/refresh'),
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

  /// Borra ambos tokens — el guard de rutas existente (`app_router.dart`)
  /// reacciona solo a `sessionProvider`, así que además hay que borrar el
  /// perfil guardado para que una sesión "colgada" (tokens borrados pero
  /// perfil todavía en memoria/`SessionStorage`) no confunda al arrancar
  /// la app de nuevo. Ver `AuthController` para el resto de la limpieza.
  Future<void> _limpiarSesionExpirada() async {
    await _tokenStorage.borrarToken();
    await _tokenStorage.borrarRefreshToken();
  }

  /// Envía una petición ya armada por [enviar] y, si responde 401 (access
  /// token expirado — dura solo 15 min, así que va a pasar seguido),
  /// intenta refrescar el token UNA vez y reintenta la petición original
  /// también una sola vez. Si el refresh falla, limpia la sesión y deja
  /// que la respuesta 401 original se propague como [ApiException] (el
  /// guard de rutas existente redirige a `/login` al ver que no hay
  /// sesión — no hace falta manejo especial de navegación aquí).
  Future<dynamic> _conReintentoDeToken(
    Future<http.Response> Function() enviar,
  ) async {
    final res = await enviar();
    if (res.statusCode != 401) return _decode(res);

    final refrescado = await _intentarRefrescarToken();
    if (!refrescado) {
      await _limpiarSesionExpirada();
      return _decode(res);
    }
    final res2 = await enviar();
    return _decode(res2);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return null;
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    var mensaje = 'Ocurrió un error. Intenta de nuevo.';
    try {
      final body = jsonDecode(utf8.decode(res.bodyBytes));
      if (body is Map && body['error'] is String) {
        mensaje = body['error'] as String;
      }
    } catch (_) {
      // Respuesta de error sin cuerpo JSON válido — se conserva el
      // mensaje genérico de arriba.
    }
    AppLogger.error(
      'ApiClient ${res.request?.method} ${res.request?.url.path}',
      'HTTP ${res.statusCode}: $mensaje',
    );
    throw ApiException(mensaje, status: res.statusCode);
  }

  /// Envuelve cualquier llamada HTTP: registra en [AppLogger] las fallas
  /// de RED (sin conexión, DNS, timeout) — que nunca llegan a [_decode]
  /// porque el propio cliente `http` truena antes de tener una respuesta
  /// — y las traduce a un mensaje claro para el usuario en vez de dejar
  /// pasar la excepción cruda de `dart:io`/`http`.
  Future<T> _conManejoDeErrores<T>(String contexto, Future<T> Function() fn) async {
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

  /// POST multipart — para /cargas y /cierres-dia, que reciben las fotos
  /// como `multipart/form-data` (ver `middleware/upload.ts`). `campos`
  /// son los valores de texto/número; `archivos` mapea el nombre del
  /// campo del formulario a la ruta local del archivo (`null`/ausente si
  /// esa foto no se tomó).
  Future<dynamic> postMultipart(
    String path, {
    required Map<String, String> campos,
    Map<String, String?> archivos = const {},
  }) {
    return _conManejoDeErrores('ApiClient.postMultipart $path', () async {
      Future<http.Response> enviar() async {
        final req = http.MultipartRequest('POST', _uri(path));
        req.headers.addAll(await _headers(json: false));
        req.fields.addAll(campos);
        for (final entry in archivos.entries) {
          final ruta = entry.value;
          if (ruta == null) continue;
          req.files.add(await http.MultipartFile.fromPath(entry.key, ruta));
        }
        final streamed = await _http.send(req);
        return http.Response.fromStream(streamed);
      }

      return _conReintentoDeToken(enviar);
    });
  }
}
