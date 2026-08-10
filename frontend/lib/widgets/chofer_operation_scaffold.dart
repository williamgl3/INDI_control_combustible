import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/route_paths.dart';
import '../theme/app_breakpoints.dart';
import 'brand_sub_header.dart';
import 'contenido_responsivo.dart';

void volverEnFlujoChofer(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(RoutePaths.chofer);
  }
}

class ChoferOperationScaffold extends StatelessWidget {
  const ChoferOperationScaffold({
    super.key,
    required this.titulo,
    required this.child,
    this.onBack,
    this.lateral,
    this.scrollable = true,
    this.loading = false,
    this.error,
    this.onRetry,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset = true,
  });

  final String titulo;
  final Widget child;
  final VoidCallback? onBack;
  final Widget? lateral;
  final bool scrollable;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;
  final Widget? bottomNavigationBar;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    final cuerpo = Column(
      children: [
        BrandSubHeader(
          titulo: titulo,
          onBack: onBack ?? () => volverEnFlujoChofer(context),
        ),
        Expanded(
          child: error != null
              ? _ErrorOperacion(mensaje: error!, onRetry: onRetry)
              : loading
              ? const Center(child: CircularProgressIndicator())
              : ContenidoResponsivo(scrollable: scrollable, child: child),
        ),
      ],
    );
    final esAncho = AppBreakpoints.isTabletOrDesktop(
      MediaQuery.sizeOf(context).width,
    );
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      bottomNavigationBar: bottomNavigationBar,
      body: SafeArea(
        child: esAncho && lateral != null
            ? Row(
                children: [
                  lateral!,
                  Expanded(child: cuerpo),
                ],
              )
            : cuerpo,
      ),
    );
  }
}

class _ErrorOperacion extends StatelessWidget {
  const _ErrorOperacion({required this.mensaje, this.onRetry});
  final String mensaje;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(mensaje, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
