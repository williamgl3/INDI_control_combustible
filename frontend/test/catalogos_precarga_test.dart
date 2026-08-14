import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/auth_controller.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/vehiculo.dart';

import 'mocks/mock_vehiculos_repository.dart';
import 'mocks/mock_auth_repository.dart';
import 'mocks/mock_evidencias_repository.dart';
import 'mocks/mock_incidencias_repository.dart';
import 'mocks/mock_operaciones_repository.dart';

class _AuthContable extends MockAuthRepository {
  int cargasUsuarios = 0;

  @override
  Future<void> cargarChoferes() async => cargasUsuarios++;
}

class _OperacionesContables extends MockOperacionesRepository {
  int cargas = 0;

  @override
  Future<void> cargarDatosIniciales({required Perfil perfil}) async => cargas++;
}

class _IncidenciasContables extends MockIncidenciasRepository {
  int cargasPropias = 0;
  int cargasAdministrativas = 0;

  @override
  Future<void> cargarMisIncidencias() async => cargasPropias++;

  @override
  Future<void> cargarTodasLasIncidencias() async => cargasAdministrativas++;
}

class _EvidenciasContables extends MockEvidenciasRepository {
  int cargasAdministrativas = 0;

  @override
  Future<void> cargarTodasLasEvidencias() async => cargasAdministrativas++;
}

const _chofer = Perfil(
  id: 'chofer-catalogo',
  usuario: 'chofer_catalogo',
  nombre: 'Chofer',
  correo: 'chofer@example.com',
  rol: RolUsuario.chofer,
);

const _supervisor = Perfil(
  id: 'supervisor-catalogo',
  usuario: 'supervisor_catalogo',
  nombre: 'Supervisor',
  correo: 'supervisor@example.com',
  rol: RolUsuario.supervisor,
);

Vehiculo _unidad(String id, String tipo, String combustible) => Vehiculo(
  id: id,
  tipoUnidad: tipo,
  placas: null,
  numeroEconomico: id,
  modelo: 'Modelo $id',
  tipoCombustible: combustible,
  intervaloServicio: null,
);

void main() {
  test('sin sesión no consulta catálogos protegidos', () async {
    final repo = MockVehiculosRepository();
    final container = ProviderContainer(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    expect(await container.read(catalogoUnidadesProvider.future), isEmpty);
    expect(repo.cargasRealizadas, 0);
  });

  test(
    'dos consumidores comparten una sola carga y reutilizan el dato',
    () async {
      final espera = Completer<void>();
      final repo = MockVehiculosRepository(alCargar: () => espera.future);
      final container = ProviderContainer(
        overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).iniciarSesion(_chofer);

      final primero = container.read(catalogoUnidadesProvider.future);
      final segundo = container.read(catalogoUnidadesProvider.future);
      expect(repo.cargasRealizadas, 1);
      espera.complete();

      expect(await primero, isNotEmpty);
      expect(await segundo, isNotEmpty);
      expect(await container.read(catalogoUnidadesProvider.future), isNotEmpty);
      expect(repo.cargasRealizadas, 1);
    },
  );

  test('actualización manual simultánea realiza una sola consulta', () async {
    final repo = MockVehiculosRepository();
    final container = ProviderContainer(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).iniciarSesion(_chofer);
    await container.read(catalogoUnidadesProvider.future);

    await Future.wait([
      container.read(catalogoUnidadesProvider.notifier).actualizar(),
      container.read(catalogoUnidadesProvider.notifier).actualizar(),
    ]);

    expect(repo.cargasRealizadas, 2);
  });

  test('un catálogo vacío es un dato válido y no se recarga solo', () async {
    final repo = MockVehiculosRepository(vehiculos: const []);
    final container = ProviderContainer(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).iniciarSesion(_chofer);

    expect(await container.read(catalogoUnidadesProvider.future), isEmpty);
    expect(await container.read(catalogoUnidadesProvider.future), isEmpty);
    expect(repo.cargasRealizadas, 1);
    expect(container.read(catalogoUnidadesProvider).hasError, isFalse);
  });

  test('un error conserva unidades válidas y permite reintentar', () async {
    var falla = false;
    final repo = MockVehiculosRepository(
      alCargar: () async {
        if (falla) throw StateError('obras no disponibles');
      },
    );
    final container = ProviderContainer(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).iniciarSesion(_chofer);
    final unidades = await container.read(catalogoUnidadesProvider.future);

    falla = true;
    await container.read(catalogoUnidadesProvider.notifier).actualizar();

    final estado = container.read(catalogoUnidadesProvider);
    expect(estado.hasError, isTrue);
    expect(estado.valueOrNull, unidades);
  });

  test('cerrar sesión limpia el catálogo publicado', () async {
    final repo = MockVehiculosRepository();
    final container = ProviderContainer(
      overrides: [vehiculosRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider.notifier).iniciarSesion(_chofer);
    expect(await container.read(catalogoUnidadesProvider.future), isNotEmpty);

    container.read(sessionProvider.notifier).cerrarSesion();

    expect(await container.read(catalogoUnidadesProvider.future), isEmpty);
  });

  test(
    'una respuesta tardía no reemplaza el catálogo de otra sesión',
    () async {
      final esperaChofer = Completer<void>();
      final repositorios = <String?, MockVehiculosRepository>{
        _chofer.id: MockVehiculosRepository(
          vehiculos: [_unidad('vehiculo-chofer', 'Vehículo', 'Diésel')],
          alCargar: () => esperaChofer.future,
        ),
        _supervisor.id: MockVehiculosRepository(
          vehiculos: [_unidad('marimba-supervisor', 'Marimba', 'Magna')],
        ),
      };
      final container = ProviderContainer(
        overrides: [
          vehiculosRepositoryProvider.overrideWith((ref) {
            final id = ref.watch(sessionProvider.select((p) => p?.id));
            return repositorios[id]!;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(sessionProvider.notifier).iniciarSesion(_chofer);
      final respuestaVieja = container.read(catalogoUnidadesProvider.future);

      container.read(sessionProvider.notifier).iniciarSesion(_supervisor);
      final actuales = await container.read(catalogoUnidadesProvider.future);
      esperaChofer.complete();
      await respuestaVieja;

      expect(actuales.single.id, 'marimba-supervisor');
      expect(
        container.read(catalogoUnidadesProvider).requireValue.single.id,
        'marimba-supervisor',
      );
    },
  );

  test('los filtros mantienen separadas unidades y combustibles', () async {
    final unidades = [
      _unidad('vehiculo-diesel', 'Vehículo', 'Diésel'),
      _unidad('maquinaria-magna', 'Maquinaria', 'Magna'),
      _unidad('marimba-diesel', 'Marimba', 'Diésel'),
      _unidad('pipa-magna', 'Pipa', 'Magna'),
    ];

    expect(unidades.where((u) => u.tipoUnidad == 'Vehículo'), hasLength(1));
    expect(unidades.where((u) => u.tipoUnidad == 'Maquinaria'), hasLength(1));
    expect(
      unidades.where(
        (u) => u.tipoUnidad == 'Marimba' || u.tipoUnidad == 'Pipa',
      ),
      hasLength(2),
    );
    expect(
      unidades.where((u) => u.tipoCombustible == 'Diésel').map((u) => u.id),
      containsAll(['vehiculo-diesel', 'marimba-diesel']),
    );
    expect(
      unidades.where((u) => u.tipoCombustible == 'Magna').map((u) => u.id),
      containsAll(['maquinaria-magna', 'pipa-magna']),
    );
  });

  test('la precarga respeta los catálogos permitidos por rol', () async {
    Future<
      ({
        int usuarios,
        int incidenciasPropias,
        int incidenciasAdmin,
        int evidenciasAdmin,
      })
    >
    ejecutar(Perfil perfil) async {
      final auth = _AuthContable();
      final operaciones = _OperacionesContables();
      final incidencias = _IncidenciasContables();
      final evidencias = _EvidenciasContables();
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          operacionesRepositoryProvider.overrideWithValue(operaciones),
          incidenciasRepositoryProvider.overrideWithValue(incidencias),
          evidenciasRepositoryProvider.overrideWithValue(evidencias),
          vehiculosRepositoryProvider.overrideWithValue(
            MockVehiculosRepository(),
          ),
        ],
      );
      container.read(sessionProvider.notifier).iniciarSesion(perfil);
      await container
          .read(authControllerProvider)
          .precargarDatosDeSesion(perfil);
      expect(operaciones.cargas, 1);
      container.dispose();
      return (
        usuarios: auth.cargasUsuarios,
        incidenciasPropias: incidencias.cargasPropias,
        incidenciasAdmin: incidencias.cargasAdministrativas,
        evidenciasAdmin: evidencias.cargasAdministrativas,
      );
    }

    final chofer = await ejecutar(_chofer);
    expect(chofer.usuarios, 0);
    expect(chofer.incidenciasPropias, 1);
    expect(chofer.incidenciasAdmin, 0);

    final supervisor = await ejecutar(_supervisor);
    expect(supervisor.usuarios, 0);
    expect(supervisor.incidenciasPropias, 1);
    expect(supervisor.evidenciasAdmin, 0);

    final administrativo = await ejecutar(
      const Perfil(
        id: 'admin-catalogo',
        usuario: 'admin_catalogo',
        nombre: 'Administrativo',
        correo: 'admin@example.com',
        rol: RolUsuario.administrativo,
      ),
    );
    expect(administrativo.usuarios, 1);
    expect(administrativo.incidenciasPropias, 0);
    expect(administrativo.incidenciasAdmin, 1);
    expect(administrativo.evidenciasAdmin, 1);
  });
}
