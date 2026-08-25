import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/models/registro_auditoria.dart';

/// `detalleLegible` es lo que evita que la pestaña Auditoría truene al
/// leer del backend real: `detalle` llega como el objeto JSON crudo (no
/// como texto ya redactado, que es lo único que probaban los mocks) — ver
/// el bug real encontrado al construir esta función: `RegistroAuditoria`
/// esperaba `detalle` como `String`, pero `detalle JSONB` en Postgres se
/// deserializa como `Map` en la respuesta HTTP.
void main() {
  RegistroAuditoria registro({
    required String accion,
    required Object? detalle,
  }) {
    return RegistroAuditoria(
      id: 'x',
      usuarioId: 'u1',
      usuarioNombre: 'Ana',
      accion: accion,
      entidad: 'x',
      entidadId: 'x',
      detalle: detalle,
      creadoEn: DateTime(2026, 1, 1),
    );
  }

  test('detalle como texto (mocks) se muestra tal cual', () {
    final r = registro(accion: 'aprobó', detalle: 'Autorizó 40 L.');
    expect(r.detalleLegible, 'Autorizó 40 L.');
  });

  test('detalle null no truena y muestra vacío', () {
    final r = registro(accion: 'aprobar_solicitud', detalle: null);
    expect(r.detalleLegible, '');
  });

  test('acepta actor y entidad eliminados sin perder la auditoría', () {
    final r = RegistroAuditoria.fromJson({
      'id': 'audit-1',
      'usuarioId': null,
      'usuarioNombre': null,
      'accion': 'chofer_eliminado',
      'entidad': 'usuario',
      'entidadId': null,
      'detalle': null,
      'creadoEn': '2026-01-01T00:00:00.000Z',
    });

    expect(r.usuarioId, isNull);
    expect(r.entidadId, isNull);
    expect(r.usuarioNombreLegible, 'Usuario eliminado o sistema');
  });

  test('editar_precio arma el mensaje desde el mapa del backend', () {
    final r = registro(accion: 'editar_precio', detalle: {'nuevoPrecio': 26.9});
    expect(r.detalleLegible, contains('26.9'));
  });

  test('editar_presupuesto_semanal arma el mensaje desde el mapa', () {
    final r = registro(
      accion: 'editar_presupuesto_semanal',
      detalle: {'nuevoValor': 60000},
    );
    expect(r.detalleLegible, contains('60000'));
  });

  test('editar_carga solo menciona los campos que cambiaron', () {
    final r = registro(
      accion: 'editar_carga',
      detalle: {
        'anterior': {'litrosCargados': 38.0, 'kmAlCargar': 1000.0},
        'nuevo': {'litrosCargados': 40.0, 'kmAlCargar': 1000.0},
      },
    );
    expect(r.detalleLegible, contains('Litros'));
    expect(r.detalleLegible, isNot(contains('Km')));
  });
}
