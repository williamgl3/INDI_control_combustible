import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Colores de acento por sección del panel administrativo — cada sección
/// tiene su propio color de identidad en vez de que todo sea el mismo
/// azul de marca, para que la navegación se sienta más viva y sea más
/// fácil de reconocer de un vistazo (mismo criterio de "un color por
/// categoría" que Ajustes de iOS, pero con una paleta propia — tonos más
/// serios/industriales acordes a una app de control de flotilla en obra,
/// no los colores de sistema de Apple).
///
/// `primary` (el azul de marca) se reserva para CTAs y el estado
/// seleccionado — estos colores son solo para iconografía/badges (siempre
/// como fondo detrás de un ícono blanco, ver `IconBadge`).
class AppSectionColors {
  const AppSectionColors._();

  static const dashboard = Color(0xFF4F46E5); // índigo — resumen/métricas

  // Mismo azul que ya usa "Mis solicitudes" en el home del chofer
  // (`colors.info`, #0A84FF) — Autorizaciones (admin) y Solicitudes
  // (chofer) son la misma entidad (`SolicitudAutorizacion`) vista desde
  // cada rol, así que comparten color a propósito. Antes usaba el mismo
  // hex que `colors.primary` (#0165F9), que esta clase reserva para
  // CTAs/selección, no para iconografía de categoría — quedaba fuera de
  // su propia regla.
  static const autorizaciones = AppColors.brandBlue;
  static const concentrado = Color(0xFF0D9488); // verde azulado — reportes
  static const finanzas = Color(0xFF16A34A); // verde — dinero/presupuesto
  static const vehiculos = Color(0xFFD97706); // ámbar — catálogo de unidades
  static const mantenimiento = Color(0xFFDC2626); // rojo — alertas/servicio
  static const choferes = Color(0xFFE11D48); // carmín — directorio de personas
  static const auditoria = Color(0xFF475569); // gris azulado — bitácora/control
  static const marimba = Color(0xFF7C3AED); // violeta — recorridos de despacho
}
