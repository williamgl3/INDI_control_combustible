import 'package:flutter/material.dart';

/// Duraciones y curvas de animación reutilizadas en toda la app — antes
/// cada `TweenAnimationBuilder`/transición definía sus propios valores
/// sueltos (260ms en el router, 600ms en la barra de tope, 400ms +
/// `elasticOut` en la respuesta de solicitud), sin ningún token
/// compartido.
class AppMotion {
  const AppMotion._();

  /// Feedback de hover/press — no se usa todavía como Duration explícita
  /// (los overlays de Material son instantáneos), pero queda declarado
  /// para cuando se necesite una microinteracción más deliberada.
  static const Duration fast = Duration(milliseconds: 150);

  /// Transiciones de página y de diálogo (ver `_conTransicion` en
  /// app_router.dart y `mostrarDialogoApp` en app_dialog.dart).
  static const Duration base = Duration(milliseconds: 250);

  /// Revelado de barras de progreso (tope semanal, presupuesto).
  static const Duration slow = Duration(milliseconds: 400);

  /// Curva "sobria" por defecto — página, diálogo, barras de progreso.
  static const Curve curve = Curves.easeOutCubic;

  /// Curva con rebote — reservada a propósito para un solo momento de la
  /// app (el resultado de una solicitud aprobada, en
  /// `RespuestaSolicitudScreen`), no para uso general.
  static const Curve celebratory = Curves.elasticOut;
}
