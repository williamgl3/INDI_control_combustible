import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

enum AppRouteTransitionKind { authentication, primary, detail }

/// Fuente única de las transiciones de página. Los diálogos, hojas y
/// paneles conservan las transiciones Material que ya controlan su modalidad.
Page<void> buildAppTransitionPage({
  required BuildContext context,
  required LocalKey pageKey,
  required Widget child,
  required AppRouteTransitionKind kind,
}) {
  if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
    return NoTransitionPage<void>(key: pageKey, child: child);
  }

  final (duration, reverseDuration) = switch (kind) {
    AppRouteTransitionKind.authentication => (
      const Duration(milliseconds: 200),
      const Duration(milliseconds: 160),
    ),
    AppRouteTransitionKind.primary => (
      const Duration(milliseconds: 180),
      const Duration(milliseconds: 140),
    ),
    AppRouteTransitionKind.detail => (
      const Duration(milliseconds: 220),
      const Duration(milliseconds: 170),
    ),
  };

  return CustomTransitionPage<void>(
    key: pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      if (kind == AppRouteTransitionKind.authentication) {
        return FadeTransition(opacity: curved, child: child);
      }
      if (kind == AppRouteTransitionKind.detail) {
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.025, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      }
      return FadeTransition(
        opacity: curved,
        child: AnimatedBuilder(
          animation: curved,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, 8 * (1 - curved.value)),
            child: child,
          ),
          child: child,
        ),
      );
    },
  );
}
