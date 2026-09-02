import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/core/session_provider.dart';
import 'package:indi_combustible/models/despacho_marimba.dart';
import 'package:indi_combustible/models/panel_marimba.dart';
import 'package:indi_combustible/models/perfil.dart';
import 'package:indi_combustible/models/recorrido_marimba.dart';
import 'package:indi_combustible/screens/administrativo/tabs/marimba_tab.dart';
import 'package:indi_combustible/theme/app_theme.dart';

const unidades = [
  ResumenUnidadMarimba(
    id: 'm1',
    tipoUnidad: 'Marimba',
    modelo: 'Marimba activa',
    activo: true,
    recorridoAbiertoId: 'r1',
    responsableNombre: 'Ana Pérez',
    saldoMagna: '0',
    saldoDiesel: null,
    requiereRevision: true,
  ),
  ResumenUnidadMarimba(
    id: 'p1',
    tipoUnidad: 'Pipa',
    modelo: 'Pipa inactiva',
    activo: false,
    saldoMagna: '25.5',
    saldoDiesel: '80',
    requiereRevision: false,
  ),
];
final recorrido = RecorridoMarimba(
  id: 'r1',
  marimbaId: 'm1',
  operadorId: 's1',
  responsableNombre: 'Ana Pérez',
  marimbaEtiqueta: 'Marimba activa',
  tipoCombustible: 'Magna',
  frente: 'Frente norte',
  litrosIniciales: 100,
  litrosDespachadosTotal: 30,
  existenciaFisica: 65,
  requiereRevision: true,
  fotoCierrePath: 'cierre.jpg',
  fotoNivelPath: 'nivel.jpg',
  iniciadoEn: DateTime.utc(2026, 8, 13, 8),
  cerradoEn: DateTime.utc(2026, 8, 13, 12),
);
final despachos = [
  DespachoMarimba(
    id: 'd1',
    marimbaId: 'm1',
    unidadDestinoEtiqueta: 'Excavadora 1',
    operadorTexto: 'Luis',
    litrosSuministrados: 20,
    registradoPor: 's1',
    creadoEn: DateTime.utc(2026),
    cantidadDeclarada: false,
    medidorInicial: 10,
    medidorFinal: 30,
    horometro: 50,
    fotoHorometroPath: 'h.jpg',
    fotoMedidorPath: 'm.jpg',
    fotoEvidenciaPath: 'e.jpg',
    tipoCombustible: 'Magna',
  ),
  DespachoMarimba(
    id: 'd2',
    marimbaId: 'm1',
    operadorTexto: 'Luis',
    litrosSuministrados: 10,
    registradoPor: 's1',
    creadoEn: DateTime.utc(2026),
    cantidadDeclarada: true,
    tipoCombustible: 'Magna',
  ),
  DespachoMarimba(
    id: 'd3',
    marimbaId: 'm1',
    operadorTexto: 'Luis',
    litrosSuministrados: 1,
    registradoPor: 's1',
    creadoEn: DateTime.utc(2026),
    cantidadDeclarada: null,
  ),
];

ProviderContainer container({
  bool errorResumen = false,
  bool errorHistorial = false,
  List<ResumenUnidadMarimba> resumen = unidades,
  List<RecorridoMarimba>? items,
}) {
  final c = ProviderContainer(
    overrides: [
      resumenUnidadesMarimbaProvider.overrideWith((ref) async {
        if (errorResumen) throw StateError('inventario');
        return resumen;
      }),
      recorridosAdministrativosMarimbaProvider.overrideWith((
        ref,
        filtros,
      ) async {
        if (errorHistorial) throw StateError('historial');
        return PaginaRecorridosMarimba(
          items: items ?? [recorrido],
          total: 26,
          page: filtros.page,
          limit: filtros.limit,
          totalPages: 2,
        );
      }),
      detalleAdministrativoMarimbaProvider.overrideWith(
        (ref, id) async => (recorrido: recorrido, despachos: despachos),
      ),
    ],
  );
  c
      .read(sessionProvider.notifier)
      .iniciarSesion(
        const Perfil(
          id: 'admin',
          usuario: 'admin',
          nombre: 'Administración',
          correo: 'admin@example.com',
          rol: RolUsuario.administrativo,
        ),
      );
  return c;
}

Future<void> pump(WidgetTester tester, ProviderContainer c) async {
  await tester.binding.setSurfaceSize(const Size(1200, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: MarimbaTab()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('muestra unidades, saldos y estados sin cruzar combustibles', (
    tester,
  ) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);
    expect(find.text('Marimba activa'), findsOneWidget);
    expect(find.text('Pipa inactiva'), findsOneWidget);
    expect(find.textContaining('Activa'), findsWidgets);
    expect(find.textContaining('Inactiva'), findsWidgets);
    expect(find.text('Magna: 0 L'), findsOneWidget);
    expect(find.text('Diésel: Sin registro'), findsOneWidget);
    expect(find.textContaining('Recorrido abierto'), findsOneWidget);
    expect(find.text('Sin recorrido abierto'), findsOneWidget);
  });

  testWidgets('distingue vacío, error parcial e historial válido', (
    tester,
  ) async {
    final c = container(errorResumen: true);
    addTearDown(c.dispose);
    await pump(tester, c);
    expect(
      find.textContaining('No fue posible consultar el inventario'),
      findsOneWidget,
    );
    expect(find.text('Frente norte'), findsOneWidget);
  });

  testWidgets('combina y limpia filtros, pagina y abre el detalle', (
    tester,
  ) async {
    final c = container();
    addTearDown(c.dispose);
    await pump(tester, c);
    final filtroCategoria = find.byKey(
      const ValueKey('filtro-categoria-marimba'),
    );
    expect(filtroCategoria, findsOneWidget);
    await tester.ensureVisible(filtroCategoria);
    await tester.pumpAndSettle();
    await tester.tap(filtroCategoria);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pipa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Requiere revisión').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.textContaining('Página 2'), findsOneWidget);
    await tester.tap(find.text('Limpiar filtros'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Página 1'), findsOneWidget);
    await tester.tap(find.text('Frente norte'));
    await tester.pumpAndSettle();
    expect(find.text('Detalle del recorrido'), findsOneWidget);
    expect(find.textContaining('Responsable: Ana Pérez'), findsOneWidget);
    expect(find.textContaining('Inventario inicial: 100'), findsOneWidget);
    expect(find.textContaining('Inventario final: 65'), findsOneWidget);
    expect(find.textContaining('Cantidad medida'), findsOneWidget);
    expect(find.textContaining('Cantidad declarada'), findsOneWidget);
    expect(find.textContaining('Registro histórico'), findsOneWidget);
    expect(find.text('Foto de cierre'), findsOneWidget);
    expect(find.text('Foto de nivel'), findsOneWidget);
    expect(find.text('Requiere revisión'), findsWidgets);
    final evidencias = <(String, String, String)>[
      ('d1', 'foto-horometro', 'Foto de horómetro'),
      ('d1', 'foto-medidor', 'Foto de medidor'),
      ('d1', 'foto-evidencia', 'Evidencia del despacho'),
      ('d2', 'foto-horometro', 'Foto de horómetro'),
      ('d2', 'foto-medidor', 'Foto de medidor'),
      ('d2', 'foto-evidencia', 'Evidencia del despacho'),
      ('d3', 'foto-horometro', 'Foto de horómetro'),
      ('d3', 'foto-medidor', 'Foto de medidor'),
      ('d3', 'foto-evidencia', 'Evidencia del despacho'),
    ];
    final detalleScrollable = find.byType(Scrollable).last;
    for (final (despachoId, campo, etiqueta) in evidencias) {
      final fila = find.byKey(ValueKey('despacho-$despachoId-$campo'));
      await tester.scrollUntilVisible(fila, 120, scrollable: detalleScrollable);
      expect(fila, findsOneWidget);
      expect(
        find.descendant(of: fila, matching: find.text(etiqueta)),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: fila,
          matching: find.text(
            despachoId == 'd1' ? 'Disponible' : 'Evidencia no disponible',
          ),
        ),
        findsOneWidget,
      );
    }
  });
}
