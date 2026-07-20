import 'package:flutter/material.dart';

/// Insignia de ícono cuadrada redondeada con color de fondo suave — el
/// tratamiento de color de los iconos de Ajustes de iOS (Wi-Fi en su
/// cuadrito azul, Batería en su cuadrito verde, etc.), reutilizado en el
/// sidebar del panel, las filas de `GroupedSection` y las `StatTile`.
class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icono,
    required this.color,
    this.size = 34,
    this.iconSize = 18,
  });

  final IconData icono;
  final Color color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icono, color: Colors.white, size: iconSize),
    );
  }
}
