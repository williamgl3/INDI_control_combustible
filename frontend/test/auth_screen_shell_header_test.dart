import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/auth_screen_shell.dart';
import 'package:indi_combustible/widgets/wave_clipper.dart';

void main() {
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
      // encima del punto más alto de la onda (2 * amplitude desde el fondo
      // del header), o el bug reportado (texto tapado por la curva) sigue
      // presente.
      final amplitude = (headerBackground.clipper as dynamic).amplitude as double;
      final topeDeLaOnda = headerRect.bottom - (amplitude * 2);

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
