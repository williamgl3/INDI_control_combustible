import 'package:flutter/material.dart';

import '../theme/app_motion.dart';
import '../theme/app_radii.dart';
import '../theme/app_spacing.dart';
import '../theme/app_theme.dart';

/// Estructura compartida de los diálogos modales de la app (formulario +
/// botones Cancelar/Acción): mismo padding, mismo radio, misma sombra
/// `raised` para todos — antes cada diálogo se armaba a mano con su
/// propio `Dialog`/`Padding`, y uno de seis (`AdminLoginDialog`) tenía un
/// header de color recortado manualmente sin ningún token compartido.
///
/// [header] es opcional — si se da, se pinta a todo lo ancho arriba del
/// contenido (ver `AdminLoginDialog`), sin el padding de 24 que sí aplica
/// al resto del contenido.
class AppDialogShell extends StatelessWidget {
  const AppDialogShell({
    super.key,
    required this.child,
    this.header,
    this.footer,
    this.maxWidth = 420,
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Tope de alto relativo a la pantalla — sin esto, un diálogo con
    // varios campos (ej. EditarVehiculoDialog) se desborda en pantallas
    // cortas (teléfono en horizontal, o ventanas de escritorio bajas) en
    // vez de hacer scroll.
    final mediaQuery = MediaQuery.of(context);
    final alturaDisponible =
        mediaQuery.size.height - mediaQuery.viewInsets.bottom;
    final alturaMaxima = alturaDisponible * 0.9;

    return Dialog(
      // `Dialog` sigue siendo el widget raíz (algunos tests lo ubican por
      // tipo, y da el ancestro Material que TextField/InkWell necesitan) —
      // pero sin su decoración default: la sombra/radio los pinta el
      // Container de adentro con nuestros propios tokens (`raised`).
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: alturaMaxima,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.cardRadius,
            boxShadow: context.shadows.raised,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ?header,
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: child,
                ),
              ),
              if (footer != null)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xxl,
                      AppSpacing.sm,
                      AppSpacing.xxl,
                      AppSpacing.xxl,
                    ),
                    child: footer,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Abre un diálogo con la transición de marca (fade + scale sutil) en vez
/// de la transición default de Material — para que se sienta igual de
/// cuidada que la navegación de página completa (ver `_conTransicion` en
/// app_router.dart), usando la misma duración/curva de `AppMotion`.
Future<T?> mostrarDialogoApp<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black.withValues(alpha: 0.54),
    transitionDuration: AppMotion.base,
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curva = CurvedAnimation(parent: animation, curve: AppMotion.curve);
      return FadeTransition(
        opacity: curva,
        child: ScaleTransition(
          scale: Tween(begin: 0.96, end: 1.0).animate(curva),
          child: child,
        ),
      );
    },
  );
}
