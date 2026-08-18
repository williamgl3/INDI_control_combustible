import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/theme/app_status_colors.dart';
import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/app_status_chip.dart';
import 'package:indi_combustible/widgets/sidebar_chofer.dart';

void main() {
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('el sistema visual instala tokens y estados en $mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: AppStatusChip(
                  label: 'Sin conexión',
                  icon: Icons.cloud_off_outlined,
                  color: context.statusColors.offline,
                ),
              ),
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(AppStatusChip));
      final theme = Theme.of(context);
      expect(theme.extension<AppStatusColors>(), isNotNull);
      expect(theme.colorScheme.primary, const Color(0xFF1463FF));
      expect(theme.colorScheme.primary, isNot(theme.colorScheme.onPrimary));
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('la navegación compacta conserva iconos y tooltips', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(() => _Sesion(_supervisor))],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SidebarChofer(
              indiceSeleccionado: 0,
              compacto: true,
              onSeleccionar: (_) {},
            ),
          ),
        ),
      ),
    );

    expect(find.byType(Icon), findsNWidgets(destinosOperativosChofer.length));
    for (final destino in destinosOperativosChofer) {
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Tooltip && widget.message == destino.etiqueta,
        ),
        findsOneWidget,
      );
    }
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Tooltip && widget.message == 'Perfil de Supervisor',
      ),
      findsOneWidget,
    );
    expect(find.text('INDI Combustible'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

const _supervisor = Perfil(
  id: 'supervisor-ui',
  usuario: 'supervisor.ui',
  nombre: 'Supervisor',
  correo: 'supervisor.ui@example.com',
  rol: RolUsuario.supervisor,
);

class _Sesion extends SessionController {
  _Sesion(this.perfil);
  final Perfil perfil;

  @override
  Perfil? build() => perfil;
}
