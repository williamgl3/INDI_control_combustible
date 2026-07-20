import 'package:flutter/material.dart';

/// Sombras de la app como [ThemeExtension].
///
/// Dirección "iOS": las listas agrupadas casi no llevan sombra (el
/// contraste blanco-sobre-gris agrupado ya separa el contenido — ver
/// `GroupedSection`); solo los elementos flotantes de verdad (diálogos,
/// hojas modales) llevan una sombra sutil, nunca tan marcada como un
/// `Material` elevation alto.
@immutable
class AppShadows extends ThemeExtension<AppShadows> {
  const AppShadows({required this.card, required this.raised});

  final List<BoxShadow> card;
  final List<BoxShadow> raised;

  static const light = AppShadows(
    card: [
      BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    raised: [
      BoxShadow(color: Color(0x26000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
  );

  static const dark = AppShadows(
    card: [
      BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    raised: [
      BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
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
