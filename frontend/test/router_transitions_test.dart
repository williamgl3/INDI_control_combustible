import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:indi_combustible/router/app_route_transitions.dart';

void main() {
  final cases = <AppRouteTransitionKind, (Duration, Duration)>{
    AppRouteTransitionKind.authentication: (
      const Duration(milliseconds: 200),
      const Duration(milliseconds: 160),
    ),
    AppRouteTransitionKind.primary: (
      const Duration(milliseconds: 180),
      const Duration(milliseconds: 140),
    ),
    AppRouteTransitionKind.detail: (
      const Duration(milliseconds: 220),
      const Duration(milliseconds: 170),
    ),
  };

  for (final entry in cases.entries) {
    testWidgets('${entry.key.name} usa la transición centralizada', (
      tester,
    ) async {
      late Page<void> page;
      late BuildContext transitionContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              transitionContext = context;
              page = buildAppTransitionPage(
                context: context,
                pageKey: ValueKey(entry.key),
                child: const SizedBox(),
                kind: entry.key,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      final transition = page as CustomTransitionPage<void>;
      expect(transition.transitionDuration, entry.value.$1);
      expect(transition.reverseTransitionDuration, entry.value.$2);
      final built = transition.transitionsBuilder(
        transitionContext,
        const AlwaysStoppedAnimation(0.5),
        const AlwaysStoppedAnimation(0),
        const SizedBox(),
      );
      expect(built, isA<FadeTransition>());
      final fade = built as FadeTransition;
      switch (entry.key) {
        case AppRouteTransitionKind.authentication:
          expect(fade.child, isA<SizedBox>());
        case AppRouteTransitionKind.primary:
          expect(fade.child, isA<AnimatedBuilder>());
        case AppRouteTransitionKind.detail:
          expect(fade.child, isA<SlideTransition>());
      }
    });
  }

  testWidgets('disableAnimations elimina la transición', (tester) async {
    late Page<void> page;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              page = buildAppTransitionPage(
                context: context,
                pageKey: const ValueKey('sin-animacion'),
                child: const SizedBox(),
                kind: AppRouteTransitionKind.detail,
              );
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(page, isA<NoTransitionPage<void>>());
  });
}
