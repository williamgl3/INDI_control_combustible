import 'package:flutter/material.dart';

import '../theme/app_breakpoints.dart';
import '../theme/app_sizes.dart';
import '../theme/app_theme.dart';
import 'auth_s_shape_header.dart';

/// Envoltura visual compartida por login / registro / recuperar
/// contraseña: header navy sólido con separador inferior mínimo, logo y nombre de la empresa
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
/// Altura responsiva: el header ocupa ~34 % de la altura disponible
/// (pero nunca menos de 180 ni más de 260 px). Cuando la ventana es baja
/// (< 650 px) o aparece el teclado entra en modo compacto de 128 px:
/// reduce el logo, la onda y los
/// espaciados para que el contenido nunca quede desplazado ni haya
/// huecos vacíos desproporcionados. Siempre hay scroll si el contenido
/// excede el área blanca.
class AuthScreenShell extends StatelessWidget {
  const AuthScreenShell({
    super.key,
    required this.child,
    this.onBack,
    this.mostrarLogo = true,
    this.mostrarMarca = true,
    this.logoSize,
    this.compactLogoSize,
    this.waveLeftHeightFactor,
    this.waveRightHeightFactor,
    this.titulo,
    this.subtitulo,
    this.centrarContenido = true,
    this.loginWave = false,
  });

  final Widget child;
  final VoidCallback? onBack;
  final bool mostrarLogo;
  final bool mostrarMarca;
  final double? logoSize;
  final double? compactLogoSize;
  final double? waveLeftHeightFactor;
  final double? waveRightHeightFactor;

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
  final bool loginWave;

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
  static const double _headerHeightFraction = 0.30;
  static const double _headerMinHeightPx = 220;
  static const double _headerMaxHeightPx = 280;
  // Altura del contenido compacto sin el inset superior del sistema. El
  // inset se suma abajo para que SafeArea no reduzca el espacio del logo y
  // del tÃ­tulo ni produzca un overflow en pantallas bajas.
  static const double _compactHeaderContentHeightPx = 160;
  static const double _waveLeftHeightFactor = 0.94;
  static const double _waveRightHeightFactor = 0.80;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = MediaQuery.sizeOf(context);
    final esEscritorio = AppBreakpoints.isTabletOrDesktop(size.width);

    final cuerpo = _Cuerpo(
      onBack: onBack,
      mostrarLogo: mostrarLogo,
      mostrarMarca: mostrarMarca,
      logoSize: logoSize,
      compactLogoSize: compactLogoSize,
      titulo: titulo,
      subtitulo: subtitulo,
      headerHeightFraction: _headerHeightFraction,
      headerMinHeightPx: _headerMinHeightPx,
      headerMaxHeightPx: _headerMaxHeightPx,
      compactHeaderContentHeightPx: _compactHeaderContentHeightPx,
      waveLeftHeightFactor: waveLeftHeightFactor ?? _waveLeftHeightFactor,
      waveRightHeightFactor: waveRightHeightFactor ?? _waveRightHeightFactor,
      centrarContenido: centrarContenido,
      loginWave: loginWave,
      child: child,
    );

    if (!esEscritorio) {
      // Mismo valor de Color que usa el área debajo de la onda
      // (`colors.surface` en `_Cuerpo`) — así, si algún pixel de la curva
      // queda sin cubrir por el degradado, se funde con el fondo en vez
      // de dejar ver `colors.background` (un tono distinto) como un hueco.
      return Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: colors.surface,
        body: cuerpo,
      );
    }

    // La tarjeta nunca debe exceder el alto disponible de la ventana.
    final esOscuro = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      // En modo oscuro, colors.background y colors.surface de la tarjeta
      // quedan cerca en escritorio (tarjeta flotante centrada, sin el
      // header azul de fondo que en móvil ya marca el contraste), así que
      // se aclara un poco solo aquí (detrás de la tarjeta), sin tocar el
      // token background usado en el resto de la app.
      backgroundColor: esOscuro
          ? Color.lerp(colors.background, Colors.white, 0.05)
          : colors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final alturaTarjeta = (constraints.maxHeight - 48).clamp(
              0.0,
              780.0,
            );
            return Center(
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
                      color: Colors.black.withValues(
                        alpha: esOscuro ? 0.4 : 0.18,
                      ),
                      blurRadius: 40,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: cuerpo,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Cuerpo extends StatelessWidget {
  const _Cuerpo({
    required this.onBack,
    required this.mostrarLogo,
    required this.mostrarMarca,
    required this.logoSize,
    required this.compactLogoSize,
    required this.titulo,
    required this.subtitulo,
    required this.headerHeightFraction,
    required this.headerMinHeightPx,
    required this.headerMaxHeightPx,
    required this.compactHeaderContentHeightPx,
    required this.waveLeftHeightFactor,
    required this.waveRightHeightFactor,
    required this.centrarContenido,
    required this.loginWave,
    required this.child,
  });

  final VoidCallback? onBack;
  final bool mostrarLogo;
  final bool mostrarMarca;
  final double? logoSize;
  final double? compactLogoSize;
  final String? titulo;
  final String? subtitulo;
  final double headerHeightFraction;
  final double headerMinHeightPx;
  final double headerMaxHeightPx;
  final double compactHeaderContentHeightPx;
  final double waveLeftHeightFactor;
  final double waveRightHeightFactor;
  final bool centrarContenido;
  final bool loginWave;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalHeight = constraints.maxHeight;

          final tecladoVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
          final isCompact = totalHeight < 650 || tecladoVisible;
          final disableAnimations = MediaQuery.disableAnimationsOf(context);
          final textScale = MediaQuery.textScalerOf(context).scale(1);
          final textScaleAllowance = ((textScale - 1).clamp(0.0, 1.0) * 100)
              .toDouble();
          // Alto real del header: fracción del alto total disponible (no un
          // valor fijo en píxeles), acotado por límites absolutos para no
          // desbordar en pantallas muy chicas ni verse absurdo en muy altas.
          final safeTop = MediaQuery.paddingOf(context).top;
          final headerHeight = isCompact
              ? (compactHeaderContentHeightPx + safeTop + textScaleAllowance)
                    .clamp(0.0, totalHeight)
              : (totalHeight * headerHeightFraction).clamp(
                      headerMinHeightPx,
                      headerMaxHeightPx,
                    ) +
                    textScaleAllowance;
          return Column(
            children: [
              // El header ocupa exactamente `headerHeight` (ya calculado
              // como fracción del alto total): con tanto espacio real
              // disponible ahora, no necesita el rango min/max "elástico"
              // que tenía antes — si el contenido (logo/título/subtítulo)
              // aun así no cupiera, el `Flexible` + `FittedBox` de abajo lo
              // reduce en vez de desbordar.
              AnimatedContainer(
                key: const Key('auth-responsive-header'),
                duration: disableAnimations
                    ? Duration.zero
                    : const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                height: headerHeight,
                child: AuthSShapeHeader(
                  height: headerHeight,
                  compact: isCompact,
                  showLogo: mostrarLogo,
                  showBrand: mostrarMarca,
                  logoSize: logoSize ?? AppSizes.logoHeaderSize,
                  compactLogoSize: compactLogoSize ?? 70,
                  title: titulo,
                  subtitle: subtitulo,
                  onBack: onBack,
                  leftHeightFactor: waveLeftHeightFactor,
                  rightHeightFactor: waveRightHeightFactor,
                  // Todas las pantallas de autenticación comparten la misma
                  // silueta orgánica; `loginWave` queda aceptado por
                  // compatibilidad con llamadas existentes.
                  clipper: null,
                ),
              ),
              Expanded(
                child: ColoredBox(
                  color: colors.surface,
                  child: SafeArea(
                    top: false,
                    child: LayoutBuilder(
                      builder: (context, contentConstraints) {
                        const padding = EdgeInsets.fromLTRB(24, 24, 24, 24);
                        return SingleChildScrollView(
                          key: const Key('auth-form-scroll'),
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
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
      ),
    );
  }
}
