import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:indi_combustible/core/providers.dart';
import 'package:indi_combustible/main.dart';

import 'test_helpers.dart';

void main() {
  testWidgets('la app arranca en /login sin sesión', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tokenStorageProvider.overrideWithValue(FakeTokenStorage()),
          sessionStorageProvider.overrideWithValue(FakeSessionStorage()),
        ],
        child: const MyApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INDI Combustible'), findsOneWidget);
  });
}
