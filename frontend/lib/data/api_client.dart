import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
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
    throw ApiException(mensaje, status: res.statusCode);
  }

  Future<dynamic> get(String path) async {
    final res = await _http.get(_uri(path), headers: await _headers());
    return _decode(res);
  }

  Future<dynamic> post(String path, {Object? body}) async {
    final res = await _http.post(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    final res = await _http.patch(
      _uri(path),
      headers: await _headers(),
      body: body == null ? null : jsonEncode(body),
    );
    return _decode(res);
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
  }) async {
    final req = http.MultipartRequest('POST', _uri(path));
    req.headers.addAll(await _headers(json: false));
    req.fields.addAll(campos);
    for (final entry in archivos.entries) {
      final ruta = entry.value;
      if (ruta == null) continue;
      req.files.add(await http.MultipartFile.fromPath(entry.key, ruta));
    }
    final streamed = await _http.send(req);
    final res = await http.Response.fromStream(streamed);
    return _decode(res);
  }
}
