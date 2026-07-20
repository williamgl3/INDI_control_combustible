import 'package:flutter/material.dart';

/// Colores de acento por sección del panel administrativo — inspirados en
/// los iconos de color de Ajustes de iOS (Wi-Fi azul, Bluetooth azul,
/// Batería verde, etc.): cada sección tiene su propio color de identidad
/// en vez de que todo sea el mismo azul de marca, para que la navegación
/// se sienta más viva y sea más fácil de reconocer de un vistazo.
///
/// `primary` (el azul de marca) se reserva para CTAs y el estado
/// seleccionado — estos colores son solo para iconografía/badges.
class AppSectionColors {
  const AppSectionColors._();

  static const dashboard = Color(0xFF5856D6); // iOS purple
  static const autorizaciones = Color(0xFF0165F9); // azul de marca
  static const concentrado = Color(0xFF30B0C7); // iOS teal
  static const finanzas = Color(0xFF34C759); // iOS green
  static const vehiculos = Color(0xFFFF9500); // iOS orange
  static const mantenimiento = Color(0xFFFF3B30); // iOS red
  static const choferes = Color(0xFFFF2D55); // iOS pink
}
