import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/models/solicitud_autorizacion.dart';

import 'test_helpers.dart';

/// Cubre el punto de la auditoría UI/UX: antes tocar una solicitud en
/// "Actividad reciente" no hacía nada — ahora abre un detalle desde el
/// que el chofer puede cancelarla mientras siga pendiente.
void main() {
  testWidgets(
    'el chofer cancela su propia solicitud pendiente desde el detalle',
    (tester) async {
      final container = makeTestContainer();
      addTearDown(container.dispose);

      final chofer1 = container.read(authRepositoryProvider).listarChoferes().firstWhere(
            (c) => c.usuario == 'chofer1',
          );
      final vehiculo1 = container.read(vehiculosRepositoryProvider).todos.first;
      final repo = container.read(operacionesRepositoryProvider);
      late SolicitudAutorizacion solicitud;
      await tester.runAsync(() async {
        solicitud = await repo.enviarSolicitud(
          choferId: chofer1.id,
          vehiculo: vehiculo1,
          litrosSolicitados: 40,
          actividad: 'Actividad de prueba',
          fechaProgramada: DateTime.now().add(const Duration(days: 1)),
        );
      });
      expect(solicitud.estado, EstadoSolicitud.pendiente);

      await pumpTestApp(tester, container: container);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Usuario'),
        'chofer1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Contraseña'),
        'chofer123',
      );
      await tester.ensureVisible(find.text('Ingresar'));
      await tester.tap(find.text('Ingresar'));
      await tester.pumpAndSettle();

      // Toca la fila de la solicitud en "Actividad reciente".
      await tester.ensureVisible(find.textContaining('40.0 L'));
      await tester.tap(find.textContaining('40.0 L'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelar solicitud'), findsWidgets);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Cerrar'));
      await tester.pumpAndSettle();
      // Reabre para confirmar que el diálogo se cerró limpio (no dejó
      // un candado de doble apertura) y proceder con la cancelación real.
      await tester.tap(find.textContaining('40.0 L'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Cancelar solicitud'));
      await tester.pumpAndSettle();

      // Diálogo de confirmación destructivo.
      expect(find.text('Sí, cancelar'), findsOneWidget);
      await tester.tap(find.text('Sí, cancelar'));
      await tester.pumpAndSettle();

      final actualizada = repo
          .solicitudesDeChofer(chofer1.id)
          .firstWhere((s) => s.id == solicitud.id);
      expect(actualizada.estado, EstadoSolicitud.rechazada);
      expect(actualizada.comentario, 'Cancelada por el chofer.');
    },
  );
}
