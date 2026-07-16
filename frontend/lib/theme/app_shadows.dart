import 'package:flutter/material.dart';

/// Sombras de la app como [ThemeExtension].
///
/// TODO-SPEC: valores PLACEHOLDER (elevaciones suaves genéricas).
/// Reemplazar con los valores exactos de SPEC.md.
@immutable
class AppShadows extends ThemeExtension<AppShadows> {
  const AppShadows({required this.card, required this.raised});

  final List<BoxShadow> card;
  final List<BoxShadow> raised;

  static const light = AppShadows(
    card: [
      BoxShadow(
        color: Color(0x14000000),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
    raised: [
      BoxShadow(
        color: Color(0x1F000000),
        blurRadius: 20,
        offset: Offset(0, 8),
      ),
    ],
  );

  static const dark = AppShadows(
    card: [
      BoxShadow(
        color: Color(0x40000000),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
    raised: [
      BoxShadow(
        color: Color(0x59000000),
        blurRadius: 20,
        offset: Offset(0, 8),
      ),
    ],
  );

  @override
  AppShadows copyWith({List<BoxShadow>? card, List<BoxShadow>? raised}) {
    return AppShadows(card: card ?? this.card, raised: raised ?? this.raised);
  }

  @override
  AppShadows lerp(ThemeExtension<AppShadows>? other, double t) {
    if (other is! AppShadows) return this;
    return t < 0.5 ? this : other;
  }
}
