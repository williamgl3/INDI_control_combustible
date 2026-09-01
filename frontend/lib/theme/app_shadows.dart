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
  const AppShadows({
    required this.card,
    required this.raised,
    required this.floating,
  });

  final List<BoxShadow> card;
  final List<BoxShadow> raised;

  /// Sombra de cards flotantes en depth design — más profunda que [card]
  /// pero más contenida que [raised]. Pensada para leerse como una sombra
  /// suave y difusa (blur alto, opacidad baja, sin borde duro) en AMBOS
  /// temas por igual — antes en claro era prácticamente invisible (4% de
  /// opacidad) porque el valor solo se había calibrado contra el fondo
  /// oscuro del panel de chofer; ahora sube a un nivel visible pero sutil,
  /// y en oscuro se suaviza un poco (era demasiado marcada/dura) y gana
  /// blur para difuminarse más en vez de leerse como un borde duro.
  final List<BoxShadow> floating;

  static const light = AppShadows(
    card: [
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 8, offset: Offset(0, 2)),
    ],
    raised: [
      BoxShadow(color: Color(0x1A0F172A), blurRadius: 18, offset: Offset(0, 6)),
    ],
    floating: [
      BoxShadow(color: Color(0x0F0F172A), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );

  static const dark = AppShadows(
    card: [
      BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 2)),
    ],
    raised: [
      BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    floating: [
      BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4)),
    ],
  );

  @override
  AppShadows copyWith({
    List<BoxShadow>? card,
    List<BoxShadow>? raised,
    List<BoxShadow>? floating,
  }) {
    return AppShadows(
      card: card ?? this.card,
      raised: raised ?? this.raised,
      floating: floating ?? this.floating,
    );
  }

  @override
  AppShadows lerp(ThemeExtension<AppShadows>? other, double t) {
    if (other is! AppShadows) return this;
    return t < 0.5 ? this : other;
  }
}
