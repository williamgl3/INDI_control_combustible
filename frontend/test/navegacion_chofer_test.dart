import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/screens/chofer/chofer_home_shell.dart';
import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/sidebar_chofer.dart';

void main() {
  test('cada ruta del chofer selecciona exactamente un destino', () {
    final rutas = <String, int>{
      RoutePaths.chofer: 0,
      RoutePaths.choferDashboard: 0,
      RoutePaths.choferTipoOperacion: 1,
      '/chofer/solicitar/vehiculo': 1,
      '/chofer/solicitar/maquinaria': 1,
      '/chofer/solicitar/granel': 1,
      RoutePaths.choferRespuesta: 1,
      RoutePaths.choferSolicitudes: 2,
      '${RoutePaths.choferSolicitudes}/detalle': 2,
      RoutePaths.choferComprobar: 3,
      RoutePaths.choferSubirEvidencias: 3,
      RoutePaths.choferCerrarDia: 3,
      RoutePaths.choferPerfil: 4,
    };

    for (final entry in rutas.entries) {
      final indice = indiceDestinoChoferParaRuta(entry.key);
      expect(indice, entry.value, reason: entry.key);
      expect(
        List.generate(5, (i) => i == indice).where((activo) => activo),
        hasLength(1),
        reason: entry.key,
      );
    }
  });

  for (final perfil in [_chofer, _supervisor]) {
    testWidgets(
      'el sidebar muestra iconos contrastantes para ${perfil.rol.name}',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sessionProvider.overrideWith(() => _Sesion(perfil))],
            child: MaterialApp(
              theme: AppTheme.light(),
              home: Scaffold(
                body: SidebarChofer(
                  indiceSeleccionado: 1,
                  onSeleccionar: _sinAccion,
                ),
              ),
            ),
          ),
        );

        final context = tester.element(find.byType(SidebarChofer));
        final scheme = Theme.of(context).colorScheme;

        expect(find.byType(Icon), findsNWidgets(destinosChofer.length));
        for (final destino in destinosChofer) {
          expect(find.text(destino.etiqueta), findsOneWidget);
        }

        for (var i = 0; i < destinosChofer.length; i++) {
          final item = find.byKey(ValueKey('sidebar-chofer-destino-$i'));
          final icon = tester.widget<Icon>(
            find.descendant(of: item, matching: find.byType(Icon)),
          );
          final material = tester.widget<Material>(
            find.descendant(of: item, matching: find.byType(Material)),
          );
          final activo = i == 1;

          expect(material.color, activo ? scheme.primary : Colors.transparent);
          expect(
            icon.color,
            activo ? scheme.onPrimary : scheme.onSurfaceVariant,
          );
          expect(icon.color, isNot(material.color));
        }

        expect(
          find.byWidgetPredicate(
            (widget) => widget is Material && widget.color == scheme.primary,
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final themeMode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('la barra usa colores semánticos en $themeMode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeMode,
          home: const Scaffold(
            bottomNavigationBar: NavegacionInferiorChofer(
              indiceSeleccionado: 2,
              onSeleccionar: _sinAccion,
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(NavigationBar));
      final scheme = Theme.of(context).colorScheme;
      final navTheme = NavigationBarTheme.of(context);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 2);
      expect(navTheme.indicatorColor, scheme.primary);
      expect(
        navTheme.iconTheme!.resolve({WidgetState.selected})!.color,
        scheme.onPrimary,
      );
      expect(navTheme.iconTheme!.resolve({})!.color, scheme.onSurfaceVariant);
      expect(
        navTheme.labelTextStyle!.resolve({WidgetState.selected})!.fontWeight,
        FontWeight.w700,
      );
      expect(navTheme.labelTextStyle!.resolve({})!.fontWeight, FontWeight.w500);
      expect(tester.takeException(), isNull);
    });
  }

  for (final width in [320.0, 480.0, 768.0, 1200.0]) {
    testWidgets('no hay overflow en navegación a ${width.toInt()} px', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            bottomNavigationBar: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
              child: NavegacionInferiorChofer(
                indiceSeleccionado: 1,
                onSeleccionar: _sinAccion,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  }
}

void _sinAccion(int _) {}

const _chofer = Perfil(
  id: 'chofer-sidebar',
  usuario: 'chofer.sidebar',
  nombre: 'Chofer',
  apellidoPaterno: 'Prueba',
  correo: 'chofer.sidebar@example.com',
  rol: RolUsuario.chofer,
);

const _supervisor = Perfil(
  id: 'supervisor-sidebar',
  usuario: 'supervisor.sidebar',
  nombre: 'Supervisor',
  apellidoPaterno: 'Prueba',
  correo: 'supervisor.sidebar@example.com',
  rol: RolUsuario.supervisor,
);

class _Sesion extends SessionController {
  _Sesion(this.perfil);

  final Perfil perfil;

  @override
  Perfil? build() => perfil;
}
