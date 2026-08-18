import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/router/route_paths.dart';
import 'package:indi_combustible/screens/chofer/chofer_home_shell.dart';
import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/sidebar_chofer.dart';

void main() {
  testWidgets('los destinos principales no se acumulan en el historial', (
    tester,
  ) async {
    late GoRouter router;
    Widget destino(BuildContext context, String ruta) {
      final actual = indiceDestinoChoferParaRuta(ruta);
      return Scaffold(
        body: Row(
          children: [
            for (var i = 0; i < destinosChofer.length; i++)
              TextButton(
                key: ValueKey('destino-$i'),
                onPressed: () => navegarDesdeSidebarChofer(context, actual, i),
                child: Text(destinosChofer[i].etiqueta),
              ),
          ],
        ),
      );
    }

    router = GoRouter(
      initialLocation: RoutePaths.chofer,
      routes: [
        for (final ruta in const [
          RoutePaths.chofer,
          RoutePaths.choferTipoOperacion,
          RoutePaths.choferSolicitudes,
          RoutePaths.choferSubirEvidencias,
          RoutePaths.choferPerfil,
        ])
          GoRoute(path: ruta, builder: (context, _) => destino(context, ruta)),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: router, theme: AppTheme.light()),
    );

    await tester.tap(find.byKey(const ValueKey('destino-2')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, RoutePaths.choferSolicitudes);
    expect(router.canPop(), isFalse);

    await tester.tap(find.byKey(const ValueKey('destino-4')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, RoutePaths.choferPerfil);
    expect(router.canPop(), isFalse);
  });

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

        expect(
          find.byType(Icon),
          findsNWidgets(destinosOperativosChofer.length),
        );
        for (final destino in destinosOperativosChofer) {
          expect(find.text(destino.etiqueta), findsOneWidget);
        }
        expect(find.text('Perfil'), findsNothing);
        expect(
          find.text(perfil.nombreCompleto.substring(0, 1).toUpperCase()),
          findsOneWidget,
        );
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Tooltip &&
                widget.message ==
                    'Perfil de ${perfil.nombreCompleto.split(' ').first}',
          ),
          findsOneWidget,
        );

        for (var i = 0; i < destinosOperativosChofer.length; i++) {
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
            activo ? scheme.onPrimary : context.colors.sidebarTextMuted,
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

  testWidgets('el avatar y el nombre abren Perfil y reflejan su selección', (
    tester,
  ) async {
    var seleccionado = -1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(() => _Sesion(_chofer))],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SidebarChofer(
              indiceSeleccionado: 4,
              onSeleccionar: (indice) => seleccionado = indice,
            ),
          ),
        ),
      ),
    );

    final avatar = find.byKey(const ValueKey('sidebar-chofer-perfil'));
    expect(avatar, findsOneWidget);
    final material = tester.widget<Material>(avatar);
    final context = tester.element(avatar);
    expect(material.color, Theme.of(context).colorScheme.primary);

    await tester.tap(avatar);
    expect(seleccionado, 4);
    seleccionado = -1;
    await tester.tap(find.text('Chofer Prueba'));
    expect(seleccionado, 4);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.selected == true,
      ),
      findsOneWidget,
    );
  });

  testWidgets('una sesión sin nombre usa el icono de persona', (tester) async {
    const sinNombre = Perfil(
      id: 'sin-nombre',
      usuario: 'sin.nombre',
      nombre: '',
      correo: 'sin.nombre@example.com',
      rol: RolUsuario.chofer,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWith(() => _Sesion(sinNombre))],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SidebarChofer(
              indiceSeleccionado: 0,
              onSeleccionar: _sinAccion,
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == 'Abrir perfil',
      ),
      findsOneWidget,
    );
    expect(find.text('?'), findsNothing);
  });

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
