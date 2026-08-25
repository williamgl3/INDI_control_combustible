import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/theme/app_theme.dart';
import 'package:indi_combustible/widgets/ver_foto_dialog.dart';

const _referencia = '/uploads/550e8400-e29b-41d4-a716-446655440000.png';
final _png1x1 = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _AbrirFoto extends StatelessWidget {
  const _AbrirFoto({this.local});
  final String? local;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ElevatedButton(
      onPressed: () => VerFotoDialog.show(
        context,
        titulo: 'Evidencia',
        url: local == null ? _referencia : null,
        rutaLocal: local,
      ),
      child: const Text('Abrir'),
    ),
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<Uint8List> Function(String) cargar,
  String? local,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        archivoBytesProvider.overrideWith(
          (ref, referencia) => cargar(referencia),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: _AbrirFoto(local: local),
      ),
    ),
  );
  await tester.tap(find.text('Abrir'));
  await tester.pump();
}

void main() {
  testWidgets('muestra loading y luego una Image.memory correcta', (
    tester,
  ) async {
    final pendiente = Completer<Uint8List>();
    await _pump(tester, cargar: (_) => pendiente.future);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pendiente.complete(_png1x1);
    await tester.pumpAndSettle();
    final imagen = tester.widget<Image>(find.byType(Image));
    expect(imagen.image, isA<MemoryImage>());
  });

  testWidgets('muestra estado de error si la descarga falla', (tester) async {
    await _pump(
      tester,
      cargar: (_) => Future<Uint8List>.error(StateError('falló')),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
  });

  testWidgets('las fotografías locales continúan usando Image.file', (
    tester,
  ) async {
    final archivo = File('${Directory.systemTemp.path}/indi-foto-local.png');
    archivo.writeAsBytesSync(_png1x1);
    addTearDown(() => archivo.deleteSync());
    await _pump(
      tester,
      local: archivo.path,
      cargar: (_) => Future.error(StateError('no debe descargar')),
    );
    final imagen = tester.widget<Image>(find.byType(Image));
    expect(imagen.image, isA<FileImage>());
  });
}
