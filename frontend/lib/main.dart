import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'INDI Combustible',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      // El diseño se construyó y verificó contra el tema claro (los
      // mockups de referencia son claros) — sin esto, un dispositivo con
      // modo oscuro del sistema activado usa `darkTheme`, que no se ha
      // afinado con la misma atención al detalle todavía.
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
