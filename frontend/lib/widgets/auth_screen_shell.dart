import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_theme.dart';
import 'blob_background.dart';
import 'wave_clipper.dart';

/// Envoltura visual compartida por login / registro / recuperar
/// contraseña: header de un solo azul de marca con borde inferior
/// ondulado, logo y nombre de la empresa siempre visibles, seguido —en
/// flujo normal, sin superponerse— por el área blanca con el formulario
/// de cada pantalla.
///
/// Header y área blanca van uno debajo del otro en un [Column] (no en un
/// [Stack] superpuesto): así la división es fija y el contenido con
/// scroll nunca puede terminar detrás del header.
///
/// Responsiva: en teléfono ocupa toda la pantalla; en ventanas de
/// escritorio/web (>= [AppBreakpoints.tablet]) se centra como una tarjeta
/// flotante con esquinas redondeadas y sombra, para no estirar un layout
/// pensado para teléfono a todo el ancho de un monitor.
class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.child,
    this.onBack,
    this.mostrarLogo = true,
    this.titulo,
    this.subtitulo,
  });

  final Widget child;
  final VoidCallback? onBack;
  final bool mostrarLogo;

  /// Título y subtítulo (p. ej. "Bienvenido" / "Ingresa tus datos para
  /// continuar") — se pintan fijos justo debajo de la ola, FUERA del área
  /// con scroll, para que nunca se oculten al desplazar el formulario.
  final String? titulo;
  final String? subtitulo;

  /// Azul de marca fijo del header — el mismo tono muestreado del logo
  /// real ([Image.asset] de logo_indi.jpeg), constante en ambos temas
  /// (claro/oscuro) para que el logo se siga fundiendo sin costura sin
  /// importar el modo de color activo.
  static const Color headerBlue = Color(0xFF0165F9);

  static const double _headerHeight = 200;
  static const double _waveAmplitude = 28;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = MediaQuery.sizeOf(context);
    final esEscritorio = AppBreakpoints.isTabletOrDesktop(size.width);

    final cuerpo = _Cuerpo(
      onBack: onBack,
      mostrarLogo: mostrarLogo,
      titulo: titulo,
      subtitulo: subtitulo,
      headerHeight: _headerHeight,
      waveAmplitude: _waveAmplitude,
      child: child,
    );

    if (!esEscritorio) {
      return Scaffold(body: cuerpo);
    }

    // La tarjeta nunca debe exceder el alto disponible de la ventana — si
    // no cabe, se achica (el formulario sigue con scroll interno) en vez
    // de desbordarse fuera del contenedor.
    final alturaTarjeta = (size.height - 48).clamp(420.0, 780.0);

    return Scaffold(
      backgroundColor: colors.background,
      body: Center(
        child: Container(
          width: 440,
          height: alturaTarjeta,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: cuerpo,
        ),
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.onBack,
    required this.mostrarLogo,
    required this.titulo,
    required this.subtitulo,
    required this.headerHeight,
    required this.waveAmplitude,
    required this.child,
  });

  final VoidCallback? onBack;
  final bool mostrarLogo;
  final String? titulo;
  final String? subtitulo;
  final double headerHeight;
  final double waveAmplitude;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: headerHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipPath(
                clipper: WaveBottomClipper(amplitude: waveAmplitude),
                child: const BlobBackground(color: AuthScreenShell.headerBlue),
              ),
              if (mostrarLogo) const _LogoYMarca(),
              if (onBack != null)
                Positioned(
                  top: 4,
                  left: 4,
                  child: SafeArea(
                    bottom: false,
                    child: IconButton(
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: colors.surface,
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Título/subtítulo fijos: quedan fuera del
                  // SingleChildScrollView a propósito, para que nunca se
                  // oculten al desplazar el formulario de abajo.
                  if (titulo != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            titulo!,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (subtitulo != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              subtitulo!,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: colors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      child: child,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoYMarca extends StatelessWidget {
  const _LogoYMarca();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.92,
              child: Image.asset(
                'assets/images/logo_indi.jpeg',
                width: 56,
                height: 56,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'INDI Combustible',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Control de combustible en obra',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: const Color(0xB3FFFFFF)),
            ),
          ],
        ),
      ),
    );
  }
}
