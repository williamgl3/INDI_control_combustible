import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_logger.dart';
import 'core/cola_solicitudes_offline.dart';
import 'core/connectivity_provider.dart';
import 'core/providers.dart';
import 'core/theme_mode_provider.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

/// La app es solo en español por ahora, pero se configura vía
/// `flutter_localizations` (no solo `Locale('es')` a secas) para que
/// widgets nativos de Material (selector de fecha/hora, etc.) también
/// salgan en español en vez del inglés por defecto del SDK.
const _localeApp = Locale('es');
const _localesSoportados = [_localeApp];
const _localizationsDelegates = [
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

void main() {
  // Captura cualquier error no manejado (de Flutter o de Dart puro, ej.
  // una excepción dentro de un `Future` sin `catch`) y lo manda a
  // AppLogger — antes de esto, un error fuera de un `try/catch` explícito
  // se perdía en el vacío (o solo aparecía en la consola de debug, que
  // nadie ve en un dispositivo real en obra).
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.error(
      'FlutterError',
      details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.error('PlatformDispatcher', error, stackTrace: stack);
    return true;
  };

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mientras se resuelve `restaurarSesionProvider` (lee token+perfil
    // guardados de una sesión anterior) se muestra una pantalla de carga
    // en vez del router — si no, el usuario vería el login destellar un
    // instante antes de saltar a su sección.
    final restauracion = ref.watch(restaurarSesionProvider);
    final modoTema = ref.watch(themeModeProvider);

    if (restauracion.isLoading) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: modoTema,
        localizationsDelegates: _localizationsDelegates,
        supportedLocales: _localesSoportados,
        locale: _localeApp,
        home: const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return const _AppConRouter();
  }
}

class _AppConRouter extends ConsumerWidget {
  const _AppConRouter();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final modoTema = ref.watch(themeModeProvider);
    observarReconexionParaSincronizar(ref);

    return MaterialApp.router(
      title: 'INDI Combustible',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // Antes fijo en `ThemeMode.light` porque el tema oscuro no se había
      // probado — ahora es elegible por el usuario (claro/oscuro/sistema)
      // desde el botón de tema en el home de chofer/admin, persistido con
      // `themeModeProvider`.
      themeMode: modoTema,
      routerConfig: router,
      localizationsDelegates: _localizationsDelegates,
      supportedLocales: _localesSoportados,
      locale: _localeApp,
      builder: (context, child) => _ConAvisoDeConectividad(child: child),
    );
  }
}

/// Banner fijo arriba de toda la app cuando no hay conexión — antes de
/// esto, sin internet, el usuario solo se enteraba al tocar un botón y
/// ver un mensaje de error genérico en esa pantalla puntual.
class _ConAvisoDeConectividad extends ConsumerWidget {
  const _ConAvisoDeConectividad({required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conectado = ref.watch(conectividadProvider).valueOrNull ?? true;

    return Column(
      children: [
        if (!conectado)
          Material(
            color: Colors.red.shade700,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off,
                      color: Colors.white,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sin conexión a internet',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        if (child != null) Expanded(child: child!),
      ],
    );
  }
}
