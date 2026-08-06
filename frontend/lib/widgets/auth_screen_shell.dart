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
///
/// Altura responsiva: el header ocupa ~38 % de la altura disponible
/// (pero nunca menos de 160 ni más de 260 px). Cuando la ventana es baja
/// (< 500 px) entra en modo compacto: reduce el logo, la onda y los
/// espaciados para que el contenido nunca quede desplazado ni haya
/// huecos vacíos desproporcionados. Siempre hay scroll si el contenido
/// excede el área blanca.
class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.child,
    this.onBack,
    this.mostrarLogo = true,
    this.titulo,
    this.subtitulo,
    this.centrarContenido = true,
  });

  final Widget child;
  final VoidCallback? onBack;
  final bool mostrarLogo;

  /// Formularios cortos (recuperar contraseña, bienvenida) se ven mejor
  /// centrados en el espacio restante bajo el header: si no, quedan
  /// pegados arriba con todo el aire sobrante amontonado al fondo. Pero
  /// un formulario largo (login, con enlaces/legales/botón de admin) en
  /// una pantalla alta, antes de que aparezca ningún error, puede ser más
  /// corto que el espacio disponible — centrarlo entonces deja un hueco
  /// vacío (pintado con `colors.surface`, casi negro en modo oscuro)
  /// entre la onda y el primer campo. Con `centrarContenido: false` el
  /// contenido se ancla arriba, pegado al padding fijo bajo el header.
  final bool centrarContenido;

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

  // El header ahora ocupa una fracción del alto disponible (no un valor
  // fijo en píxeles) para que la diagonal de la onda tenga espacio real
  // donde cruzar la pantalla, con límites absolutos para pantallas muy
  // chicas o muy altas.
  static const double _headerHeightFraction = 0.45;
  static const double _headerMinHeightPx = 220;
  static const double _headerMaxHeightPx = 420;
  static const double _waveLeftHeightFactor = 0.85;
  static const double _waveRightHeightFactor = 0.35;

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
      headerHeightFraction: _headerHeightFraction,
      headerMinHeightPx: _headerMinHeightPx,
      headerMaxHeightPx: _headerMaxHeightPx,
      waveLeftHeightFactor: _waveLeftHeightFactor,
      waveRightHeightFactor: _waveRightHeightFactor,
      centrarContenido: centrarContenido,
      child: child,
    );

    if (!esEscritorio) {
      // Mismo valor de Color que usa el área debajo de la onda
      // (`colors.surface` en `_Cuerpo`) — así, si algún pixel de la curva
      // queda sin cubrir por el degradado, se funde con el fondo en vez
      // de dejar ver `colors.background` (un tono distinto) como un hueco.
      return Scaffold(backgroundColor: colors.surface, body: cuerpo);
    }

    // La tarjeta nunca debe exceder el alto disponible de la ventana; 350
    // es el mínimo que garantiza header + un área de contenido usable.
    final alturaTarjeta = (size.height - 48).clamp(350.0, 780.0);
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
          key: const Key('auth-screen-shell-card'),
          width: 440,
          height: alturaTarjeta,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(28),
            border: esOscuro ? Border.all(color: colors.border) : null,
            // Variante intencional de `AppShadows.floating` — NO es un
            // olvido de migrar al token: esta es la única "mega-card" que
            // envuelve toda la pantalla de login/registro en escritorio,
            // así que se justifica un efecto más dramático (blur/offset
            // mayores) que el de una card de contenido normal.
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
    required this.headerHeightFraction,
    required this.headerMinHeightPx,
    required this.headerMaxHeightPx,
    required this.waveLeftHeightFactor,
    required this.waveRightHeightFactor,
    required this.centrarContenido,
    required this.child,
  });

  final VoidCallback? onBack;
  final bool mostrarLogo;
  final String? titulo;
  final String? subtitulo;
  final double headerHeightFraction;
  final double headerMinHeightPx;
  final double headerMaxHeightPx;
  final double waveLeftHeightFactor;
  final double waveRightHeightFactor;
  final bool centrarContenido;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final mid = Color.lerp(
      colors.brandHeaderStart,
      colors.brandHeaderEnd,
      0.5,
    )!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalHeight = constraints.maxHeight;

        // Modo compacto: ventanas muy bajas reducen el logo y la onda.
        final isCompact = totalHeight < 500;
        final margenSeguridad = 12.0;
        // Alto real del header: fracción del alto total disponible (no un
        // valor fijo en píxeles), acotado por límites absolutos para no
        // desbordar en pantallas muy chicas ni verse absurdo en muy altas.
        final headerHeight = (totalHeight * headerHeightFraction).clamp(
          headerMinHeightPx,
          headerMaxHeightPx,
        );
        // Estimación conservadora: el lado más corto de la diagonal (el
        // factor menor entre izquierda/derecha, ver `WaveBottomClipper`)
        // es el punto más alto al que puede llegar el azul.
        final waveMinFactor = waveLeftHeightFactor < waveRightHeightFactor
            ? waveLeftHeightFactor
            : waveRightHeightFactor;
        final waveGap =
            headerHeight * (1 - waveMinFactor) * 0.3 + margenSeguridad;

        return Column(
          children: [
            // El header ocupa exactamente `headerHeight` (ya calculado
            // como fracción del alto total): con tanto espacio real
            // disponible ahora, no necesita el rango min/max "elástico"
            // que tenía antes — si el contenido (logo/título/subtítulo)
            // aun así no cupiera, el `Flexible` + `FittedBox` de abajo lo
            // reduce en vez de desbordar.
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: headerHeight,
                maxHeight: headerHeight,
              ),
              child: SizedBox(
                width: double.infinity,
                child: Stack(
                  alignment: AlignmentDirectional.topCenter,
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: ClipPath(
                        clipper: WaveBottomClipper(
                          leftHeightFactor: waveLeftHeightFactor,
                          rightHeightFactor: waveRightHeightFactor,
                        ),
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
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _LogoYMarca(
                                titulo: titulo,
                                subtitulo: subtitulo,
                                compact: isCompact,
                              ),
                            ),
                          ),
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
                    builder: (context, contentConstraints) {
                      const padding = EdgeInsets.fromLTRB(24, 12, 24, 24);
                      return SingleChildScrollView(
                        // Antes forzaba `ClampingScrollPhysics` — se sentía
                        // "seco"/topado comparado con el resto de la app,
                        // que deja el physics nativo de la plataforma (con
                        // rebote en iOS). Sin override, este scroll queda
                        // igual que cualquier otro de la app.
                        padding: padding,
                        child: centrarContenido
                            ? ConstrainedBox(
                                // Formularios cortos (p. ej. recuperar
                                // contraseña) quedaban pegados arriba con
                                // todo el aire sobrante amontonado al
                                // fondo. Forzar la altura mínima del
                                // contenido a la del viewport y centrar
                                // reparte ese aire arriba/abajo;
                                // formularios largos simplemente exceden
                                // ese mínimo y el scroll sigue funcionando
                                // igual que antes.
                                constraints: BoxConstraints(
                                  minHeight:
                                      contentConstraints.maxHeight -
                                      padding.vertical,
                                ),
                                child: Center(child: child),
                              )
                            // Sin centrar: el contenido se ancla arriba,
                            // pegado al padding fijo bajo el header (sin
                            // esto, un formulario más corto que la
                            // pantalla dejaba un hueco de `colors.surface`
                            // —casi negro en modo oscuro— entre la onda y
                            // el primer campo).
                            : child,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LogoYMarca extends StatelessWidget {
  const _LogoYMarca({
    required this.titulo,
    required this.subtitulo,
    this.compact = false,
  });

  final String? titulo;
  final String? subtitulo;
  final bool compact;

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
        padding: EdgeInsets.only(top: compact ? 4 : 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LogoGlass(size: compact ? 40 : AppSizes.logoHeaderSize),
            SizedBox(height: compact ? 4 : 10),
            if (esPantallaDeMarca) ...[
              Text(
                'INDI Combustible',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 18 : null,
                ),
              ),
              SizedBox(height: compact ? 1 : 2),
              Text(
                'Control de combustible en obra',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xB3FFFFFF),
                  fontSize: compact ? 11 : null,
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
              SizedBox(height: compact ? 3 : 6),
              // Título propio de la pantalla (ej. "Recuperar contraseña"),
              // protagonista del header — antes vivía fijo en el área
              // blanca (fuera del scroll): al arrastrar el formulario, el
              // campo justo debajo terminaba renderizándose encima de ese
              // texto fijo. Aquí, dentro del header (siempre fijo, es
              // chrome de marca), no hay scroll con el que pueda chocar.
              Text(
                titulo!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: compact ? 20 : null,
                ),
              ),
              if (subtitulo != null) ...[
                SizedBox(height: compact ? 2 : 4),
                // Acotado a 2 líneas: sin límite, un subtítulo largo podía
                // hacer crecer el header más allá de `headerMaxHeight` y
                // producir overflow (el header se dimensiona por altura
                // disponible, no por su propio contenido).
                Text(
                  subtitulo!,
                  textAlign: TextAlign.center,
                  maxLines: compact ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: const Color(0xB3FFFFFF),
                    fontSize: compact ? 11 : null,
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
