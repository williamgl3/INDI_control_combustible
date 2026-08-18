import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:indi_combustible/core/exportador_service.dart';
import 'package:indi_combustible/core/foto_picker.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/recordatorio_service.dart';
import 'package:indi_combustible/core/session_storage.dart';
import 'package:indi_combustible/core/ticket_ocr_service.dart';
import 'package:indi_combustible/core/token_storage.dart';
import 'mocks/mock_auditoria_repository.dart';
import 'mocks/mock_auth_repository.dart';
import 'mocks/mock_evidencias_repository.dart';
import 'mocks/mock_incidencias_repository.dart';
import 'mocks/mock_operaciones_repository.dart';
import 'mocks/mock_vehiculos_repository.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/router/app_router.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/theme/app_theme.dart';

/// Fakes en memoria para las dependencias que usan canales de plataforma
/// no disponibles en widget tests (secure storage, cámara, OCR,
/// notificaciones locales, compartir archivos).

class FakeTokenStorage extends TokenStorage {
  String? _token;
  String? _refreshToken;

  @override
  Future<void> guardarToken(String token) async => _token = token;

  @override
  Future<String?> leerToken() async => _token;

  @override
  Future<void> borrarToken() async => _token = null;

  @override
  Future<void> guardarRefreshToken(String refreshToken) async =>
      _refreshToken = refreshToken;

  @override
  Future<String?> leerRefreshToken() async => _refreshToken;

  @override
  Future<void> borrarRefreshToken() async => _refreshToken = null;
}

class FakeSessionStorage extends SessionStorage {
  Perfil? _perfil;

  @override
  Future<void> guardarPerfil(Perfil perfil) async => _perfil = perfil;

  @override
  Future<Perfil?> leerPerfil() async => _perfil;

  @override
  Future<void> borrarPerfil() async => _perfil = null;
}

/// Simula una foto tomada al instante, sin abrir la cámara real. Escribe
/// un archivo real y vacío en un directorio temporal — necesario para que
/// el chequeo de "¿sigue existiendo el archivo?" al sincronizar pendientes
/// offline (ver `cola_solicitudes_offline.dart`) se comporte igual que con
/// una foto real, en vez de descartar la pendiente por una ruta falsa.
class FakeFotoPicker implements FotoPicker {
  int contador = 0;

  @override
  Future<String?> tomarFoto() async {
    // Escritura SÍNCRONA a propósito: una real (`await ...writeAsBytes`)
    // no se resuelve dentro de la zona de fake-async de `flutter_test`
    // (a diferencia de `Future.delayed`, que sí tiene manejo especial) y
    // cuelga `pumpAndSettle()` indefinidamente.
    final archivo = File(
      '${Directory.systemTemp.path}/foto-fake-${contador++}.jpg',
    );
    archivo.writeAsBytesSync([0xff, 0xd8, 0xff, 0xd9]);
    return archivo.path;
  }
}

class FakeTicketOcrService implements TicketOcrService {
  const FakeTicketOcrService({this.litros = 40.0, this.importe = 959.60});

  final double litros;
  final double importe;

  @override
  Future<ResultadoOcrTicket> leerTicket(String rutaFoto) async {
    return ResultadoOcrTicket(litros: litros, importe: importe);
  }
}

/// No programa notificaciones reales — solo registra qué se pidió, para
/// poder verificarlo en las pruebas si hace falta.
class FakeRecordatorioService implements RecordatorioService {
  final programados = <String, DateTime>{};
  final cancelados = <String>[];

  @override
  Future<void> programarRecordatorioCerrarDia({
    required String cargaId,
    required DateTime cuando,
  }) async {
    programados[cargaId] = cuando;
  }

  @override
  Future<void> cancelarRecordatorio(String cargaId) async {
    cancelados.add(cargaId);
    programados.remove(cargaId);
  }
}

/// No escribe archivos ni abre la hoja de compartir — solo registra el
/// último XLSX generado, para poder verificar su contenido en las pruebas.
class FakeExportadorService implements ExportadorService {
  String? ultimoNombreArchivo;
  Uint8List? ultimoContenidoXlsx;
  String? ultimaDescripcion;

  @override
  Future<void> exportarXlsx({
    required String nombreArchivo,
    required Uint8List contenido,
    required String descripcion,
  }) async {
    ultimoNombreArchivo = nombreArchivo;
    ultimoContenidoXlsx = contenido;
    ultimaDescripcion = descripcion;
  }
}

/// Los repositorios reales (`Api*Repository`) hacen peticiones HTTP de
/// verdad — en los tests de widgets se sustituyen por los Mocks en
/// memoria, para no depender de un backend real ni colgar esperando una
/// respuesta de red.
ProviderContainer makeTestContainer({
  List<Override> overridesExtra = const [],
}) {
  return ProviderContainer(
    overrides: [
      tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
      sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
      fotoPickerProvider.overrideWithValue(FakeFotoPicker()),
      ticketOcrServiceProvider.overrideWithValue(const FakeTicketOcrService()),
      recordatorioServiceProvider.overrideWithValue(FakeRecordatorioService()),
      exportadorServiceProvider.overrideWithValue(FakeExportadorService()),
      authRepositoryProvider.overrideWithValue(MockAuthRepository()),
      evidenciasRepositoryProvider.overrideWithValue(
        MockEvidenciasRepository(),
      ),
      operacionesRepositoryProvider.overrideWithValue(
        MockOperacionesRepository(),
      ),
      vehiculosRepositoryProvider.overrideWithValue(MockVehiculosRepository()),
      incidenciasRepositoryProvider.overrideWithValue(
        MockIncidenciasRepository(),
      ),
      auditoriaRepositoryProvider.overrideWithValue(MockAuditoriaRepository()),
      ...overridesExtra,
    ],
  );
}

Future<GoRouter> pumpTestApp(
  WidgetTester tester, {
  required ProviderContainer container,
  ScrollBehavior? scrollBehavior,
  ThemeMode themeMode = ThemeMode.light,
}) async {
  final router = container.read(appRouterProvider);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        scrollBehavior: scrollBehavior,
      ),
    ),
  );
  await tester.pumpAndSettle();
  // La ruta inicial ahora es la pantalla de bienvenida; la mayoría de las
  // pruebas ejercitan el flujo de login directo, así que se navega ahí.
  router.go(RoutePaths.login);
  await tester.pumpAndSettle();
  return router;
}
