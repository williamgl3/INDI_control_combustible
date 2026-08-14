import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/models/despacho_marimba.dart';
import 'package:indi_combustible/models/panel_marimba.dart';

void main() {
  test(
    'el resumen conserva saldos separados, ausencias y recorrido opcional',
    () {
      final unidad = ResumenUnidadMarimba.fromJson({
        'id': 'pipa-1',
        'tipoUnidad': 'Pipa',
        'modelo': 'Pipa norte',
        'placas': null,
        'numeroEconomico': 'E-10',
        'activo': true,
        'recorridoAbiertoId': null,
        'responsableId': null,
        'responsableNombre': null,
        'fechaApertura': null,
        'saldoMagna': '0',
        'saldoDiesel': null,
        'ultimaActividad': '2026-08-13T10:00:00.000Z',
        'requiereRevision': false,
      });

      expect(unidad.saldoMagna, '0');
      expect(unidad.saldoDiesel, isNull);
      expect(unidad.recorridoAbiertoId, isNull);
      expect(unidad.responsableId, isNull);
      expect(unidad.ultimaActividad, DateTime.utc(2026, 8, 13, 10));
    },
  );

  test('el resumen completo conserva recorrido y responsable', () {
    final unidad = ResumenUnidadMarimba.fromJson({
      'id': 'marimba-1',
      'tipoUnidad': 'Marimba',
      'modelo': 'Unidad uno',
      'activo': false,
      'recorridoAbiertoId': 'recorrido-1',
      'responsableId': 'supervisor-1',
      'responsableNombre': 'Ana Pérez',
      'fechaApertura': '2026-08-13T08:00:00.000Z',
      'saldoMagna': '125.50',
      'saldoDiesel': '300.00',
      'ultimaActividad': null,
      'requiereRevision': true,
    });
    expect(unidad.tipoUnidad, 'Marimba');
    expect(unidad.recorridoAbiertoId, 'recorrido-1');
    expect(unidad.responsableNombre, 'Ana Pérez');
    expect(unidad.requiereRevision, isTrue);
  });

  test('la página conserva todos sus metadatos', () {
    final pagina = PaginaRecorridosMarimba.fromJson({
      'items': <Object>[],
      'page': 2,
      'limit': 20,
      'total': 45,
      'totalPages': 3,
    });
    expect(
      (pagina.page, pagina.limit, pagina.total, pagina.totalPages),
      (2, 20, 45, 3),
    );
  });

  test('valores inválidos del panel producen un error controlado', () {
    expect(
      () => ResumenUnidadMarimba.fromJson({'id': 'x'}),
      throwsA(isA<TypeError>()),
    );
    expect(
      () => PaginaRecorridosMarimba.fromJson({'items': 'no-lista'}),
      throwsA(isA<TypeError>()),
    );
  });

  test('despachos conservan clasificación y evidencias independientes', () {
    Map<String, dynamic> json(bool? declarada) => {
      'id': 'd',
      'marimbaId': 'm',
      'operadorTexto': 'Operador',
      'litrosSuministrados': '10.25',
      'registradoPor': 's',
      'creadoEn': '2026-08-13T09:00:00Z',
      'cantidadDeclarada': declarada,
      'fotoHorometroPath': 'h.jpg',
      'fotoMedidorPath': 'm.jpg',
      'fotoEvidenciaPath': 'e.jpg',
    };
    expect(DespachoMarimba.fromJson(json(true)).cantidadDeclarada, isTrue);
    expect(DespachoMarimba.fromJson(json(false)).cantidadDeclarada, isFalse);
    final historico = DespachoMarimba.fromJson(json(null));
    expect(historico.cantidadDeclarada, isNull);
    expect(
      [
        historico.fotoHorometroPath,
        historico.fotoMedidorPath,
        historico.fotoEvidenciaPath,
      ],
      ['h.jpg', 'm.jpg', 'e.jpg'],
    );
  });
}
