import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/token_storage.dart';
import 'package:indi_combustible/data/api_auth_repository.dart';
import 'package:indi_combustible/data/api_client.dart';
import 'package:indi_combustible/data/auth_repository.dart';
import 'package:indi_combustible/models/perfil.dart';

class _TokenStorageVacio extends TokenStorage {
  @override
  Future<String?> leerToken() async => null;
}

class _ApiClientRespuesta extends ApiClient {
  _ApiClientRespuesta(this.respuesta)
    : super(tokenStorage: _TokenStorageVacio());

  final Object? respuesta;

  @override
  Future<dynamic> get(String path) async => respuesta;
}

Map<String, dynamic> _perfilJson() => {
  'id': 'chofer-1',
  'usuario': 'chofer1',
  'nombre': 'Juan',
  'apellidoPaterno': 'Pérez',
  'apellidoMaterno': null,
  'correo': 'chofer1@example.com',
  'fechaNacimiento': null,
  'rol': 'chofer',
  'activo': true,
  'version': '7',
};

Map<String, dynamic> _pagina({
  Object? datos,
  Object? pagina = 1,
  Object? limite = 25,
  Object? total = 1,
  Object? totalPaginas = 1,
}) => {
  'datos': datos ?? [_perfilJson()],
  'pagina': pagina,
  'limite': limite,
  'total': total,
  'totalPaginas': totalPaginas,
};

ApiAuthRepository _repositorio(Object? respuesta) =>
    ApiAuthRepository(_ApiClientRespuesta(respuesta), _TokenStorageVacio());

void main() {
  test('convierte una lista JSON válida en List<Perfil> inmutable', () async {
    final resultado = await _repositorio(_pagina()).cargarChoferes();

    expect(resultado.datos, isA<List<Perfil>>());
    expect(resultado.datos.single.usuario, 'chofer1');
    expect(
      () => resultado.datos.add(resultado.datos.single),
      throwsUnsupportedError,
    );
  });

  test('acepta una lista vacía válida y conserva la inmutabilidad', () async {
    final resultado = await _repositorio(
      _pagina(datos: <Object?>[], total: 0, totalPaginas: 0),
    ).cargarChoferes();

    expect(resultado.datos, isEmpty);
    expect(
      () => resultado.datos.add(
        const Perfil(
          id: 'otro',
          usuario: 'otro',
          nombre: 'Otro',
          correo: 'otro@example.com',
          rol: RolUsuario.chofer,
        ),
      ),
      throwsUnsupportedError,
    );
  });

  test('rechaza un perfil inválido sin publicar datos parciales', () async {
    final repo = _repositorio(
      _pagina(
        datos: [
          <String, dynamic>{'usuario': 'incompleto'},
        ],
      ),
    );

    await expectLater(repo.cargarChoferes(), throwsA(isA<AuthException>()));
    expect(repo.listarChoferes(), isEmpty);
  });

  test('rechaza una respuesta sin datos', () async {
    final respuesta = _pagina()..remove('datos');

    await expectLater(
      _repositorio(respuesta).cargarChoferes(),
      throwsA(isA<AuthException>()),
    );
  });

  test('rechaza metadatos ausentes, fraccionarios o inconsistentes', () async {
    for (final respuesta in [
      _pagina()..remove('total'),
      _pagina(pagina: 1.5),
      _pagina(limite: 0),
      _pagina(total: 26, totalPaginas: 1),
    ]) {
      await expectLater(
        _repositorio(respuesta).cargarChoferes(),
        throwsA(isA<AuthException>()),
      );
    }
  });

  test('normaliza metadatos enteros representados por num o String', () async {
    final resultado = await _repositorio(
      _pagina(pagina: '1', limite: 25.0, total: '1', totalPaginas: 1.0),
    ).cargarChoferes();

    expect(
      (
        resultado.pagina,
        resultado.limite,
        resultado.total,
        resultado.totalPaginas,
      ),
      (1, 25, 1, 1),
    );
  });
}
