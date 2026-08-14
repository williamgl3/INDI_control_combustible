import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_auditoria_repository.dart';
import '../data/api_auth_repository.dart';
import '../data/api_client.dart';
import '../data/api_evidencias_repository.dart';
import '../data/api_incidencias_repository.dart';
import '../data/api_operaciones_repository.dart';
import '../data/api_recorridos_marimba_repository.dart';
import '../data/api_vehiculos_repository.dart';
import '../data/auditoria_repository.dart';
import '../data/auth_repository.dart';
import '../data/evidencias_repository.dart';
import '../data/incidencias_repository.dart';
import '../data/operaciones_repository.dart';
import '../data/recorridos_marimba_repository.dart';
import '../data/vehiculos_repository.dart';
import '../models/vehiculo.dart';
import '../models/panel_marimba.dart';
import '../models/despacho_marimba.dart';
import '../models/recorrido_marimba.dart';
import 'auth_controller.dart';
import 'exportador_service.dart';
import 'foto_picker.dart';
import 'recordatorio_service.dart';
import 'session_provider.dart';
import 'session_storage.dart';
import 'ticket_ocr_service.dart';
import 'token_storage.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    tokenStorage: ref.watch(tokenStorageProvider),
    // Sin esto, una sesión expirada (401 + refresh fallido) solo se
    // reflejaba en el storage — el guard de rutas no reaccionaba hasta el
    // siguiente arranque de la app (ver comentario en
    // `ApiClient._limpiarSesionExpirada`).
    onSesionExpirada: () => ref.read(sessionProvider.notifier).cerrarSesion(),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  ref.watch(sessionProvider.select((perfil) => perfil?.id));
  return ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

final auditoriaRepositoryProvider = Provider<AuditoriaRepository>((ref) {
  ref.watch(sessionProvider.select((perfil) => perfil?.id));
  return ApiAuditoriaRepository(ref.watch(apiClientProvider));
});

final operacionesRepositoryProvider = Provider<OperacionesRepository>((ref) {
  ref.watch(sessionProvider.select((perfil) => perfil?.id));
  return ApiOperacionesRepository(ref.watch(apiClientProvider));
});

/// [MockOperacionesRepository] es un objeto mutable en memoria, no un
/// `StateNotifier` — mutarlo no hace que Riverpod avise a los widgets que
/// lo observan. GoRouter, además, a veces reutiliza una pantalla ya
/// existente en el stack (mismo `pageKey`) sin reconstruirla al navegar
/// de vuelta a ella, así que ni siquiera un cambio de ruta garantiza un
/// rebuild. Cualquier pantalla que dependa de datos frescos del
/// repositorio debe hacer `ref.watch(operacionesTickProvider)` además de
/// `ref.watch(operacionesRepositoryProvider)`, y cualquier acción que
/// mute el repositorio debe incrementar este contador al terminar.
final operacionesTickProvider = StateProvider<int>((ref) => 0);

final vehiculosRepositoryProvider = Provider<VehiculosRepository>((ref) {
  ref.watch(sessionProvider.select((perfil) => perfil?.id));
  return ApiVehiculosRepository(ref.watch(apiClientProvider));
});

/// Catálogo base compartido de vehículos, maquinaria y unidades de granel.
/// Se crea por identidad de sesión, deduplica consumidores concurrentes y
/// distingue una lista vacía válida de un catálogo que todavía no cargó.
class CatalogoUnidadesController extends AsyncNotifier<List<Vehiculo>> {
  Future<List<Vehiculo>>? _cargaEnCurso;
  String? _usuarioDeCarga;

  @override
  Future<List<Vehiculo>> build() async {
    final perfil = ref.watch(sessionProvider);
    if (perfil == null) return const [];
    return _cargarPara(perfil.id);
  }

  Future<List<Vehiculo>> _cargarPara(String usuarioId) {
    final existente = _cargaEnCurso;
    if (existente != null && _usuarioDeCarga == usuarioId) return existente;
    final carga = () async {
      final repository = ref.read(vehiculosRepositoryProvider);
      await repository.cargarVehiculos();
      if (ref.read(sessionProvider)?.id != usuarioId) return const <Vehiculo>[];
      return repository.todos;
    }();
    _cargaEnCurso = carga;
    _usuarioDeCarga = usuarioId;
    return carga.whenComplete(() {
      if (identical(_cargaEnCurso, carga)) {
        _cargaEnCurso = null;
        _usuarioDeCarga = null;
      }
    });
  }

  /// Actualización manual: conserva el último dato válido mientras llega
  /// la respuesta y comparte la misma petición entre pulsaciones simultáneas.
  Future<void> actualizar() async {
    final perfil = ref.read(sessionProvider);
    if (perfil == null) {
      state = const AsyncData([]);
      return;
    }
    final anterior = state;
    state = const AsyncLoading<List<Vehiculo>>().copyWithPrevious(anterior);
    final resultado = await AsyncValue.guard(() => _cargarPara(perfil.id));
    state = resultado.hasError
        ? resultado.copyWithPrevious(anterior)
        : resultado;
  }

  /// Las mutaciones del repositorio ya actualizan su caché local. Publica
  /// solo ese catálogo, sin disparar una recarga global ni otra petición.
  void publicarCambiosLocales() {
    if (ref.read(sessionProvider) == null) return;
    state = AsyncData(ref.read(vehiculosRepositoryProvider).todos);
  }
}

final catalogoUnidadesProvider =
    AsyncNotifierProvider<CatalogoUnidadesController, List<Vehiculo>>(
      CatalogoUnidadesController.new,
    );

final recorridosMarimbaRepositoryProvider =
    Provider<RecorridosMarimbaRepository>((ref) {
      ref.watch(sessionProvider.select((perfil) => perfil?.id));
      return ApiRecorridosMarimbaRepository(ref.watch(apiClientProvider));
    });

final resumenUnidadesMarimbaProvider =
    FutureProvider<List<ResumenUnidadMarimba>>((ref) async {
      final perfil = ref.watch(sessionProvider);
      if (perfil == null || !perfil.esAdministrativo) return const [];
      final usuarioId = perfil.id;
      final datos = await ref
          .read(recorridosMarimbaRepositoryProvider)
          .listarResumenUnidades();
      return ref.read(sessionProvider)?.id == usuarioId ? datos : const [];
    });

final recorridosAdministrativosMarimbaProvider =
    FutureProvider.family<PaginaRecorridosMarimba, FiltrosRecorridosMarimba>((
      ref,
      filtros,
    ) async {
      final perfil = ref.watch(sessionProvider);
      if (perfil == null || !perfil.esAdministrativo) {
        return const PaginaRecorridosMarimba(
          items: [],
          total: 0,
          page: 1,
          limit: 25,
          totalPages: 0,
        );
      }
      final usuarioId = perfil.id;
      final datos = await ref
          .read(recorridosMarimbaRepositoryProvider)
          .listarRecorridosAdministrativos(filtros);
      return ref.read(sessionProvider)?.id == usuarioId
          ? datos
          : PaginaRecorridosMarimba(
              items: const [],
              total: 0,
              page: filtros.page,
              limit: filtros.limit,
              totalPages: 0,
            );
    });

typedef DetalleRecorridoMarimba = ({
  RecorridoMarimba recorrido,
  List<DespachoMarimba> despachos,
});

final detalleAdministrativoMarimbaProvider =
    FutureProvider.family<DetalleRecorridoMarimba, String>((
      ref,
      recorridoId,
    ) async {
      final perfil = ref.watch(sessionProvider);
      if (perfil == null || !perfil.esAdministrativo) {
        throw StateError('La sesión no puede consultar este recorrido.');
      }
      final usuarioId = perfil.id;
      final repo = ref.read(recorridosMarimbaRepositoryProvider);
      final resultados = await Future.wait([
        repo.buscarRecorrido(recorridoId),
        repo.listarDespachosDeRecorrido(recorridoId),
      ]);
      if (ref.read(sessionProvider)?.id != usuarioId) {
        throw StateError('La sesión cambió durante la consulta.');
      }
      final recorrido = resultados[0] as RecorridoMarimba?;
      if (recorrido == null) throw StateError('Recorrido no encontrado.');
      return (
        recorrido: recorrido,
        despachos: resultados[1] as List<DespachoMarimba>,
      );
    });

final incidenciasRepositoryProvider = Provider<IncidenciasRepository>((ref) {
  ref.watch(sessionProvider.select((perfil) => perfil?.id));
  return ApiIncidenciasRepository(ref.watch(apiClientProvider));
});

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final sessionStorageProvider = Provider<SessionStorage>(
  (ref) => SessionStorage(),
);

/// Se lee una sola vez al arrancar la app (ver `main.dart`) para restaurar
/// una sesión guardada de una vez anterior — mientras esto no resuelve,
/// `MyApp` muestra una pantalla de carga en vez del router, para no
/// mandar al usuario al login por un instante y luego saltar a su sección.
final restaurarSesionProvider = FutureProvider<void>((ref) {
  return ref.read(authControllerProvider).restaurarSesionAlIniciar();
});

/// TODO-BACKEND: si más adelante se sube la foto a un servidor, esta
/// interfaz no cambia — solo la implementación.
final fotoPickerProvider = Provider<FotoPicker>(
  (ref) => const ImagePickerFotoPicker(),
);

final ticketOcrServiceProvider = Provider<TicketOcrService>(
  (ref) => const MlKitTicketOcrService(),
);

final recordatorioServiceProvider = Provider<RecordatorioService>(
  (ref) => LocalRecordatorioService(),
);

final exportadorServiceProvider = Provider<ExportadorService>(
  (ref) => const ArchivoExportadorService(),
);

final evidenciasRepositoryProvider = Provider<EvidenciasRepository>((ref) {
  ref.watch(sessionProvider.select((perfil) => perfil?.id));
  return ApiEvidenciasRepository(ref.watch(apiClientProvider));
});
