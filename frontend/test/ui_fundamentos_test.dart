import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/solicitud_autorizacion.dart';
import 'package:indi_combustible/screens/bienvenida/bienvenida_screen.dart';
import 'package:indi_combustible/theme/app_radii.dart';
import 'package:indi_combustible/theme/app_colors.dart';
import 'package:indi_combustible/theme/app_status_colors.dart';
import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/app_status_chip.dart';
import 'package:indi_combustible/widgets/brand_header.dart';
import 'package:indi_combustible/widgets/estado_solicitud_badge.dart';
import 'package:indi_combustible/widgets/logo_glass.dart';
import 'package:indi_combustible/widgets/sidebar_chofer.dart';

void main() {
  testWidgets('bienvenida conserva jerarquía y acciones equivalentes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const BienvenidaScreen()),
    );

    expect(find.text('¡Bienvenido!'), findsOneWidget);
    expect(
      find.text(
        'Registra y controla el combustible de forma rápida y sencilla.',
      ),
      findsOneWidget,
    );
    final principal = find.widgetWithText(ElevatedButton, 'Iniciar sesión');
    final secundaria = find.widgetWithText(OutlinedButton, 'Crear cuenta');
    expect(tester.getSize(principal).height, greaterThanOrEqualTo(52));
    expect(tester.getSize(secundaria).height, greaterThanOrEqualTo(52));
    expect(tester.getSize(principal).width, tester.getSize(secundaria).width);

    final shape = Theme.of(
      tester.element(secundaria),
    ).outlinedButtonTheme.style?.shape?.resolve(<WidgetState>{});
    expect(shape, RoundedRectangleBorder(borderRadius: AppRadii.buttonRadius));
    expect(tester.takeException(), isNull);
  });

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
      expect(theme.colorScheme.primary, AppColors.brandBlue);
      expect(theme.colorScheme.primary, isNot(theme.colorScheme.onPrimary));
      expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('los estados de solicitud conservan semÃ¡ntica en $mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: const Scaffold(
            body: Column(
              children: [
                EstadoSolicitudBadge(
                  estadoVisual: EstadoVisualSolicitud.pendiente,
                ),
                EstadoSolicitudBadge(
                  estadoVisual: EstadoVisualSolicitud.autorizada,
                ),
                EstadoSolicitudBadge(
                  estadoVisual: EstadoVisualSolicitud.ajustada,
                ),
                EstadoSolicitudBadge(
                  estadoVisual: EstadoVisualSolicitud.rechazada,
                ),
              ],
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(EstadoSolicitudBadge).first);
      final colors = context.colors;
      Color colorDe(String texto) =>
          tester.widget<Text>(find.text(texto)).style!.color!;

      expect(colorDe('POR AUTORIZAR'), colors.textSecondary);
      expect(colorDe('AUTORIZADO'), colors.success);
      expect(colorDe('AJUSTADO'), colors.textSecondary);
      expect(colorDe('RECHAZADO'), colors.error);
      for (final texto in const [
        'POR AUTORIZAR',
        'AUTORIZADO',
        'AJUSTADO',
        'RECHAZADO',
      ]) {
        expect(find.text(texto), findsOneWidget);
      }
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
        (widget) => widget is Tooltip && widget.message == 'Ver perfil',
      ),
      findsOneWidget,
    );
    expect(find.text('INDI Combustible'), findsNothing);
    expect(find.bySemanticsLabel('INDI Combustible'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el logo y los encabezados parten del mismo primary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Column(
          children: [
            const IndiLogo(colorVariant: IndiLogoColor.primary),
            const BrandHeader(child: SizedBox(height: 8)),
          ],
        ),
      ),
    );

    expect(AppColors.brandBlue, AppColors.light.primary);
    expect(find.bySemanticsLabel('INDI Combustible'), findsOneWidget);
    expect(find.byType(BrandHeader), findsOneWidget);
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
