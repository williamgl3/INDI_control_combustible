import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/models/solicitud_autorizacion.dart';

void main() {
  test('deserializa consumo propio y carga a granel sin mezclarlos', () {
    final consumo = SolicitudPartida.fromJson({
      'id': 'partida-1',
      'tipo': 'consumo_propio',
      'litrosSolicitados': 30,
      'litrosAutorizados': 25,
      'litrosCargados': 20,
      'tipoCombustible': 'Diésel',
      'estado': 'aprobada',
      'observaciones': null,
    });
    final granel = SolicitudPartida.fromJson({
      'id': 'partida-2',
      'tipo': 'carga_granel',
      'litrosSolicitados': 100,
      'litrosAutorizados': null,
      'litrosCargados': 0,
      'tipoCombustible': 'Diésel',
      'estado': 'pendiente',
      'observaciones': null,
    });

    expect(consumo.tipo, TipoPartidaSolicitud.consumoPropio);
    expect(consumo.litrosCargados, 20);
    expect(granel.tipo, TipoPartidaSolicitud.cargaGranel);
    expect(granel.litrosAutorizados, isNull);
  });

  test('serializa la partida con el identificador semántico de API', () {
    const partida = SolicitudPartida(
      tipo: TipoPartidaSolicitud.cargaGranel,
      litrosSolicitados: 125.5,
      tipoCombustible: 'Diésel',
    );
    expect(partida.toRequestJson(), containsPair('tipo', 'carga_granel'));
    expect(partida.toRequestJson(), containsPair('litros', 125.5));
  });

  test('rechaza un tipo de partida desconocido', () {
    expect(
      () => SolicitudPartida.fromJson({
        'tipo': 'legado',
        'litrosSolicitados': 1,
        'tipoCombustible': 'Diésel',
        'estado': 'pendiente',
      }),
      throwsFormatException,
    );
  });

  test('acepta decimales exactos serializados como texto', () {
    final partida = SolicitudPartida.fromJson({
      'tipo': 'carga_granel',
      'litrosSolicitados': '100.00',
      'litrosAutorizados': '80.25',
      'litrosCargados': '30.10',
      'tipoCombustible': 'Magna',
      'estado': 'aprobada',
    });

    expect(partida.litrosSolicitados, 100);
    expect(partida.litrosAutorizados, 80.25);
    expect(partida.litrosCargados, 30.1);
    expect(partida.tipoCombustible, 'Magna');
  });
}
