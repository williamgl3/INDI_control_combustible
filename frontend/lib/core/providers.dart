import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/mock_auth_repository.dart';
import '../data/mock_operaciones_repository.dart';
import 'exportador_service.dart';
import 'foto_picker.dart';
import 'recordatorio_service.dart';
import 'session_storage.dart';
import 'ticket_ocr_service.dart';
import 'token_storage.dart';

/// TODO-SPEC / TODO-BACKEND: reemplazar por el repositorio real de auth
/// cuando el backend esté listo, manteniendo la misma interfaz pública.
final authRepositoryProvider = Provider<MockAuthRepository>((ref) {
  return MockAuthRepository();
});

/// TODO-BACKEND: reemplazar por el repositorio real de solicitudes/cargas
/// cuando el backend esté listo, manteniendo la misma interfaz pública.
final operacionesRepositoryProvider = Provider<MockOperacionesRepository>((ref) {
  return MockOperacionesRepository();
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

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final sessionStorageProvider = Provider<SessionStorage>((ref) => SessionStorage());

/// TODO-BACKEND: si más adelante se sube la foto a un servidor, esta
/// interfaz no cambia — solo la implementación.
final fotoPickerProvider = Provider<FotoPicker>((ref) => const ImagePickerFotoPicker());

final ticketOcrServiceProvider =
    Provider<TicketOcrService>((ref) => const MlKitTicketOcrService());

final recordatorioServiceProvider =
    Provider<RecordatorioService>((ref) => LocalRecordatorioService());

final exportadorServiceProvider =
    Provider<ExportadorService>((ref) => const ArchivoExportadorService());
