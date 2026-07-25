import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import 'blob_background.dart';
import 'logo_glass.dart';
import 'wave_clipper.dart';

/// Envoltura visual compartida por login / registro / recuperar
/// contraseña: header con degradado de marca (mismo tratamiento que
/// [BrandHeader]) y borde inferior ondulado, logo y nombre de la empresa
/// siempre visibles, seguido —en
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
  /// continuar") — reemplazan el tagline genérico de la empresa ("Control
  /// de combustible en obra") dentro del header azul, en vez de vivir en
  /// el área blanca. Antes vivían fijos ahí (fuera del scroll): al
  /// arrastrar el formulario, esa franja se quedaba quieta mientras el
  /// resto se movía, y en ciertos frames el campo justo debajo terminaba
  /// renderizándose encima de ese texto fijo. Subirlos al header (que de
  /// por sí siempre es fijo, es chrome de marca) resuelve eso sin perder
  /// la garantía de que nunca se ocultan al hacer scroll.
  final String? titulo;
  final String? subtitulo;

  static const double _headerMinHeight = 180;
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
      headerMinHeight: _headerMinHeight,
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
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // En modo oscuro, colors.background y colors.surface de la tarjeta
      // quedan cerca en escritorio (tarjeta flotante centrada, sin el
      // header azul de fondo que en móvil ya marca el contraste), así que
      // se aclara un poco solo aquí (detrás de la tarjeta), sin tocar el
      // token background usado en el resto de la app.
      backgroundColor: esOscuro
          ? Color.lerp(colors.background, Colors.white, 0.05)
          : colors.background,
      body: Center(
        child: Container(
          width: 440,
          height: alturaTarjeta,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: esOscuro ? Border.all(color: colors.border) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: esOscuro ? 0.4 : 0.18),
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
    required this.headerMinHeight,
    required this.waveAmplitude,
    required this.child,
  });

  final VoidCallback? onBack;
  final bool mostrarLogo;
  final String? titulo;
  final String? subtitulo;
  final double headerMinHeight;
  final double waveAmplitude;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Mismo degradado de 3 puntos que [BrandHeader] (home de
    // chofer/administrativo), para que el header del login combine con el
    // resto de la app en vez de verse plano — es chrome de marca fijo,
    // igual en ambos temas.
    final mid = Color.lerp(
      colors.brandHeaderStart,
      colors.brandHeaderEnd,
      0.5,
    )!;
    // Alto del hueco que deja la onda bajo el texto: el punto más alto de
    // [WaveBottomClipper] llega hasta `2 * amplitude` desde el borde
    // inferior, más un margen de seguridad fijo — así el texto nunca queda
    // pegado ni tapado sin importar cuánto crezca el contenido.
    const margenSeguridad = 28.0;
    final waveGap = waveAmplitude * 2 + margenSeguridad;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: headerMinHeight),
            child: Stack(
              alignment: AlignmentDirectional.topCenter,
              children: [
                Positioned.fill(
                  child: ClipPath(
                    clipper: WaveBottomClipper(amplitude: waveAmplitude),
                    child: BlobBackground(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.brandHeaderStart,
                          mid,
                          colors.brandHeaderEnd,
                        ],
                        stops: const [0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                if (mostrarLogo)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LogoYMarca(titulo: titulo, subtitulo: subtitulo),
                      SizedBox(height: waveGap),
                    ],
                  ),
                if (onBack != null)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: SafeArea(
                      bottom: false,
                      child: IconButton(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: ColoredBox(
            color: colors.surface,
            child: SafeArea(
              top: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const padding = EdgeInsets.fromLTRB(24, 16, 24, 24);
                  return SingleChildScrollView(
                    // Antes forzaba `ClampingScrollPhysics` — se sentía
                    // "seco"/topado comparado con el resto de la app, que
                    // deja el physics nativo de la plataforma (con rebote en
                    // iOS). Sin override, este scroll queda igual que
                    // cualquier otro de la app.
                    padding: padding,
                    child: ConstrainedBox(
                      // Formularios cortos (p. ej. recuperar contraseña)
                      // quedaban pegados arriba con todo el aire sobrante
                      // amontonado al fondo. Forzar la altura mínima del
                      // contenido a la del viewport y centrar reparte ese
                      // aire arriba/abajo; formularios largos (login,
                      // registro) simplemente exceden ese mínimo y el
                      // scroll sigue funcionando igual que antes.
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight -
                            padding.vertical,
                      ),
                      child: Center(child: child),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LogoYMarca extends StatelessWidget {
  const _LogoYMarca({required this.titulo, required this.subtitulo});

  final String? titulo;
  final String? subtitulo;

  @override
  Widget build(BuildContext context) {
    // El login (sin `titulo`) es donde se establece la marca, así que ahí
    // "INDI Combustible" es el texto protagonista. En el resto de pantallas
    // (registro, recuperar contraseña) el título propio de la pantalla
    // pasa a ser el protagonista y la marca queda como referencia chica
    // debajo del logo — repetirla al mismo peso que el título se sentía
    // como dos mensajes apilados compitiendo por atención.
    final esPantallaDeMarca = titulo == null;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const LogoGlass(size: AppSizes.logoHeaderSize),
            const SizedBox(height: 10),
            if (esPantallaDeMarca) ...[
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
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xB3FFFFFF),
                ),
              ),
            ] else ...[
              Text(
                'INDI Combustible',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: const Color(0x99FFFFFF),
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              // Título propio de la pantalla (ej. "Recuperar contraseña"),
              // protagonista del header — antes vivía fijo en el área
              // blanca (fuera del scroll): al arrastrar el formulario, el
              // campo justo debajo terminaba renderizándose encima de ese
              // texto fijo. Aquí, dentro del header (siempre fijo, es
              // chrome de marca), no hay scroll con el que pueda chocar.
              Text(
                titulo!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitulo!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xB3FFFFFF),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
