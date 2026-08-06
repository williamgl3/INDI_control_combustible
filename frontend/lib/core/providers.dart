import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/api_auditoria_repository.dart';
import '../data/api_auth_repository.dart';
import '../data/api_client.dart';
import '../data/api_evidencias_repository.dart';
import '../data/api_incidencias_repository.dart';
import '../data/api_despachos_marimba_repository.dart';
import '../data/api_operaciones_repository.dart';
import '../data/api_recorridos_marimba_repository.dart';
import '../data/api_vehiculos_repository.dart';
import '../data/auditoria_repository.dart';
import '../data/auth_repository.dart';
import '../data/despachos_marimba_repository.dart';
import '../data/evidencias_repository.dart';
import '../data/incidencias_repository.dart';
import '../data/operaciones_repository.dart';
import '../data/recorridos_marimba_repository.dart';
import '../data/vehiculos_repository.dart';
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
  return ApiAuthRepository(
    ref.watch(apiClientProvider),
    ref.watch(tokenStorageProvider),
  );
});

final auditoriaRepositoryProvider = Provider<AuditoriaRepository>((ref) {
  return ApiAuditoriaRepository(ref.watch(apiClientProvider));
});

final operacionesRepositoryProvider = Provider<OperacionesRepository>((ref) {
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
  return ApiVehiculosRepository(ref.watch(apiClientProvider));
});

final despachosMarimbaRepositoryProvider = Provider<DespachosMarimbaRepository>((ref) {
  return ApiDespachosMarimbaRepository(ref.watch(apiClientProvider));
});

final recorridosMarimbaRepositoryProvider =
    Provider<RecorridosMarimbaRepository>((ref) {
      return ApiRecorridosMarimbaRepository(ref.watch(apiClientProvider));
    });

final incidenciasRepositoryProvider = Provider<IncidenciasRepository>((ref) {
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
  return ApiEvidenciasRepository(ref.watch(apiClientProvider));
});
