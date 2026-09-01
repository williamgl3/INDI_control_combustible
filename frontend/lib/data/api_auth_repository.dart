import '../core/token_storage.dart';
import '../models/perfil.dart';
import 'api_client.dart';
import 'auth_repository.dart';

/// Implementación real de [AuthRepository]: habla por HTTP con el
/// backend (ver `backend/src/routes/auth.routes.ts`).
class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._client, this._tokenStorage);

  final ApiClient _client;
  final TokenStorage _tokenStorage;
  List<Perfil> _choferes = [];

  ResultadoAuth _aResultado(dynamic data) {
    return (
      perfil: Perfil.fromJson(data['perfil'] as Map<String, dynamic>),
      token: data['token'] as String,
      refreshToken: data['refreshToken'] as String,
    );
  }

  @override
  Future<ResultadoAuth> login({
    required String usuario,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/login',
        body: {'usuario': usuario, 'password': password},
      );
      return _aResultado(data);
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<ResultadoAuth> registrarChofer({
    required String nombre,
    required String apellidoPaterno,
    String? apellidoMaterno,
    required String correo,
    required String usuario,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/registro-chofer',
        body: {
          'nombre': nombre,
          'apellidoPaterno': apellidoPaterno,
          'apellidoMaterno': apellidoMaterno,
          'correo': correo,
          'usuario': usuario,
          'password': password,
        },
      );
      return _aResultado(data);
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<void> recuperarPassword({required String usuarioOCorreo}) async {
    try {
      await _client.post(
        '/recuperar-password',
        body: {'usuarioOCorreo': usuarioOCorreo},
      );
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<void> restablecerPassword({
    required String token,
    required String passwordNueva,
  }) async {
    try {
      await _client.post(
        '/restablecer-password',
        body: {'token': token, 'passwordNueva': passwordNueva},
      );
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<void> cambiarPassword({
    required String passwordActual,
    required String passwordNueva,
  }) async {
    try {
      await _client.post(
        '/cambiar-password',
        body: {
          'passwordActual': passwordActual,
          'passwordNueva': passwordNueva,
        },
      );
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  List<Perfil> listarChoferes() => List.unmodifiable(_choferes);

  @override
  Future<PaginaChoferes> cargarChoferes({
    String buscar = '',
    String estado = 'todos',
    int pagina = 1,
    int limite = 25,
  }) async {
    final query = Uri(
      queryParameters: {
        'buscar': buscar,
        'estado': estado,
        'pagina': '$pagina',
        'limite': '$limite',
      },
    ).query;
    try {
      final respuesta = await _client.get('/choferes?$query');
      if (respuesta is! Map) {
        throw const FormatException('La respuesta no es un objeto JSON.');
      }
      final data = Map<String, dynamic>.from(respuesta);
      final datosJson = data['datos'];
      if (datosJson is! List) {
        throw const FormatException('Falta la lista de choferes.');
      }

      final perfiles = <Perfil>[];
      for (final elemento in datosJson) {
        if (elemento is! Map) {
          throw const FormatException('Un perfil no es un objeto JSON.');
        }
        perfiles.add(Perfil.fromJson(Map<String, dynamic>.from(elemento)));
      }

      final paginaRespuesta = _enteroPaginacion(data, 'pagina', minimo: 1);
      final limiteRespuesta = _enteroPaginacion(
        data,
        'limite',
        minimo: 1,
        maximo: 100,
      );
      final total = _enteroPaginacion(data, 'total', minimo: 0);
      final totalPaginas = _enteroPaginacion(data, 'totalPaginas', minimo: 0);
      final totalPaginasEsperado = total == 0
          ? 0
          : (total / limiteRespuesta).ceil();
      if (totalPaginas != totalPaginasEsperado ||
          perfiles.length > limiteRespuesta ||
          (totalPaginas > 0 && paginaRespuesta > totalPaginas)) {
        throw const FormatException('Metadatos de paginación inconsistentes.');
      }

      _choferes = List<Perfil>.of(perfiles);
      return (
        datos: List<Perfil>.unmodifiable(_choferes),
        pagina: paginaRespuesta,
        limite: limiteRespuesta,
        total: total,
        totalPaginas: totalPaginas,
      );
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    } on Object {
      throw AuthException(
        'La respuesta de choferes no tiene un formato válido.',
      );
    }
  }

  int _enteroPaginacion(
    Map<String, dynamic> data,
    String campo, {
    required int minimo,
    int? maximo,
  }) {
    final valor = data[campo];
    final entero = switch (valor) {
      int numero => numero,
      num numero when numero.isFinite && numero == numero.truncate() =>
        numero.toInt(),
      String texto => int.tryParse(texto),
      _ => null,
    };
    if (entero == null ||
        entero < minimo ||
        (maximo != null && entero > maximo)) {
      throw FormatException('Metadato de paginación inválido: $campo.');
    }
    return entero;
  }

  @override
  Future<DetalleChofer> obtenerChofer(String usuarioId) async {
    try {
      final data =
          await _client.get('/usuarios/choferes/$usuarioId')
              as Map<String, dynamic>;
      final a = data['actividad'] as Map<String, dynamic>;
      return (
        chofer: Perfil.fromJson(data['chofer'] as Map<String, dynamic>),
        actividad: (
          solicitudes: a['solicitudes'] as int,
          cargas: a['cargas'] as int,
          evidencias: a['evidencias'] as int,
          incidencias: a['incidencias'] as int,
          cierres: a['cierres'] as int,
          recorridos: a['recorridos'] as int,
          despachos: a['despachos'] as int,
          auditoria: a['auditoria'] as int,
        ),
      );
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<Perfil> editarChofer({
    required String usuarioId,
    required String version,
    required Map<String, dynamic> cambios,
  }) async {
    try {
      final data = await _client.patch(
        '/usuarios/choferes/$usuarioId',
        body: {...cambios, 'version': version},
      );
      final actualizado = Perfil.fromJson(data as Map<String, dynamic>);
      _reemplazar(actualizado);
      return actualizado;
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  void _reemplazar(Perfil perfil) {
    final indice = _choferes.indexWhere((p) => p.id == perfil.id);
    if (indice != -1) {
      _choferes = [..._choferes]..[indice] = perfil;
    }
  }

  @override
  Future<Perfil> cambiarEstado({
    required String usuarioId,
    required bool activo,
    required String motivo,
  }) async {
    try {
      final data = await _client.post(
        '/usuarios/choferes/$usuarioId/${activo ? 'reactivar' : 'desactivar'}',
        body: {'motivo': motivo},
      );
      final actualizado = Perfil.fromJson(data as Map<String, dynamic>);
      _reemplazar(actualizado);
      return actualizado;
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<String> resetearPassword({
    required String usuarioId,
    required String motivo,
  }) async {
    try {
      final data = await _client.post(
        '/usuarios/$usuarioId/resetear-password',
        body: {'motivo': motivo},
      );
      return (data as Map<String, dynamic>)['mensaje'] as String;
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<ElegibilidadEliminacion> consultarElegibilidadEliminacion(
    String usuarioId,
  ) async {
    try {
      final data =
          await _client.get(
                '/usuarios/choferes/$usuarioId/elegibilidad-eliminacion',
              )
              as Map<String, dynamic>;
      return (
        elegible: data['elegible'] as bool,
        tieneRelaciones: data['tieneRelaciones'] as bool,
      );
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<void> eliminarChofer({
    required String usuarioId,
    required String usuarioConfirmado,
    required String motivo,
  }) async {
    try {
      await _client.delete(
        '/usuarios/choferes/$usuarioId',
        body: {'usuarioConfirmado': usuarioConfirmado, 'motivo': motivo},
      );
      _choferes = _choferes.where((p) => p.id != usuarioId).toList();
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<Perfil> crearAdministrativo({
    required String nombre,
    required String apellidoPaterno,
    required String apellidoMaterno,
    required String usuario,
    required String correo,
    required String password,
  }) async {
    try {
      final data = await _client.post(
        '/usuarios/administrativos',
        body: {
          'nombre': nombre,
          'apellidoPaterno': apellidoPaterno,
          'apellidoMaterno': apellidoMaterno,
          'usuario': usuario,
          'correo': correo,
          'password': password,
        },
      );
      final perfil = Perfil.fromJson(data as Map<String, dynamic>);
      _choferes = [..._choferes, perfil];
      return perfil;
    } on ApiException catch (e) {
      throw AuthException(e.mensaje);
    }
  }

  @override
  Future<void> logout() async {
    final refreshToken = await _tokenStorage.leerRefreshToken();
    if (refreshToken == null) return;
    try {
      await _client.post('/logout', body: {'refreshToken': refreshToken});
    } on ApiException {
      // Best-effort: si el backend no puede invalidar el refresh token
      // (ya expiró, backend caído, etc.), de todos modos se limpia la
      // sesión local — ver `AuthController.logout`.
    }
  }
}
