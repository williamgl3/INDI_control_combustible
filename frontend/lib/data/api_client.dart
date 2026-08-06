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
  ApiClient({
    required this._tokenStorage,
    http.Client? httpClient,
    this.onSesionExpirada,
  }) : _http = httpClient ?? http.Client();

  final TokenStorage _tokenStorage;
  final http.Client _http;

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
    // Igual que `archivos`, pero para campos que aceptan varios archivos
    // bajo el mismo nombre (ej. `fotos`, hasta 5) — multer/el backend los
    // lee como una lista por ese campo.
    Map<String, List<String>> archivosMultiples = const {},
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
        for (final entry in archivosMultiples.entries) {
          for (final ruta in entry.value) {
            req.files.add(await http.MultipartFile.fromPath(entry.key, ruta));
          }
        }
        final streamed = await _http.send(req);
        return http.Response.fromStream(streamed);
      }

      return _conReintentoDeToken(enviar);
    });
  }
}
