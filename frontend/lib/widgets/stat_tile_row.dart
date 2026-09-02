import 'package:flutter/material.dart';

/// Fila de tarjetas de estadística (`StatTile` u otras) que se reacomoda
/// sola según el ancho disponible — en vez de un `Row` de `Expanded` fijo,
/// que en un teléfono angosto (~320-360px) aprieta 2-3 tarjetas hasta
/// desbordar el texto. Con [minTileWidth] como referencia, calcula cuántas
/// columnas caben y las reparte con `Wrap` — en pantallas muy angostas
/// puede terminar en 1 columna (una tarjeta por fila), en tablet/desktop
/// caben todas en una sola fila.
class StatTileRow extends StatelessWidget {
  const StatTileRow({
    super.key,
    required this.tiles,
    this.minTileWidth = 140,
    this.spacing = 12,
  });

  final List<Widget> tiles;
  final double minTileWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final anchoDisponible = constraints.maxWidth;
        final columnas = (anchoDisponible / (minTileWidth + spacing))
            .floor()
            .clamp(1, tiles.length);
        final ancho = (anchoDisponible - spacing * (columnas - 1)) / columnas;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final tile in tiles) SizedBox(width: ancho, child: tile),
          ],
        );
      },
    );
  }
}
