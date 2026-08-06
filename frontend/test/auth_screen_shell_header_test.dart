import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/auth_screen_shell.dart';
import 'package:indi_combustible/widgets/wave_clipper.dart';

void main() {
  testWidgets(
    'en escritorio, la tarjeta nunca mide más que la ventana disponible',
    (tester) async {
      // Ancho ≥ AppBreakpoints.tablet (modo tarjeta centrada). Antes, con
      // alturas de ventana menores a ~468px, el piso mínimo (420) forzaba
      // a la tarjeta a medir más que el viewport y se recortaba —
      // empujando botones/instructivos fuera de vista. La garantía real
      // no es "sin scroll a cualquier tamaño" (un formulario completo
      // jamás cabe sin scroll en una ventana de 400px de alto, en ningún
      // diseño responsivo) sino que la tarjeta en sí nunca exceda el
      // espacio visible. No se prueba por debajo de 400: ningún navegador
      // de escritorio real permite un área de contenido más baja que eso
      // (la barra de pestañas/UI del propio navegador ya ocupa más que
      // esa diferencia).
      for (final alto in [1200.0, 700.0, 500.0, 400.0]) {
        tester.view.physicalSize = Size(900, alto);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light(),
            home: AuthScreenShell(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('¡Bienvenido!'),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Iniciar sesión'),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () {},
                    child: const Text('Crear cuenta'),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull, reason: 'alto=$alto');

        final tarjetaRect = tester.getRect(
          find.byKey(const Key('auth-screen-shell-card')),
        );
        expect(
          tarjetaRect.top,
          greaterThanOrEqualTo(0),
          reason: 'alto=$alto: la tarjeta se recorta por arriba',
        );
        expect(
          tarjetaRect.bottom,
          lessThanOrEqualTo(alto),
          reason: 'alto=$alto: la tarjeta se recorta por abajo',
        );
      }
    },
  );


  testWidgets(
    'el header crece con el contenido y no hay overflow con subtítulos largos',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: AuthScreenShell(
            titulo: 'Regístrate',
            subtitulo:
                'Primero tus datos personales, esto puede tomar un par de '
                'minutos nada más, así que no te preocupes por la extensión '
                'de este texto de prueba.',
            child: const SizedBox(height: 400, child: Text('formulario')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final subtituloRect = tester.getRect(find.textContaining('Primero tus datos'));
      final waveFinder = find.byWidgetPredicate(
        (w) => w is ClipPath && w.clipper is WaveBottomClipper,
      );
      final headerBackground = tester.widget<ClipPath>(waveFinder);
      final headerRect = tester.getRect(waveFinder);

      // El subtítulo completo (incluido su borde inferior) debe quedar por
      // encima del punto más alto que alcanza la curva diagonal tipo "S"
      // (el menor de los dos extremos, `leftHeightFactor`/
      // `rightHeightFactor` — una curva cúbica de Bézier nunca sobrepasa
      // el "convex hull" de sus puntos de control, así que ese mínimo es
      // el punto más alto real de la curva), o el bug reportado (texto
      // tapado por la curva) sigue presente.
      final clipper = headerBackground.clipper as WaveBottomClipper;
      final menorFactor = clipper.leftHeightFactor < clipper.rightHeightFactor
          ? clipper.leftHeightFactor
          : clipper.rightHeightFactor;
      final topeDeLaOnda = headerRect.top + headerRect.height * menorFactor;

      expect(
        subtituloRect.bottom,
        lessThan(topeDeLaOnda),
        reason:
            'el subtítulo se solapa con la onda inferior del header '
            '(bottom=${subtituloRect.bottom}, tope de la onda=$topeDeLaOnda)',
      );
    },
  );
}
