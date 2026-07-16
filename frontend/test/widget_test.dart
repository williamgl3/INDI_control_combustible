import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/main.dart';

void main() {
  testWidgets('la app arranca en /login sin sesión', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));
    await tester.pumpAndSettle();

    expect(find.text('INDI Combustible'), findsOneWidget);
  });
}
