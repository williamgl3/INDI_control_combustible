import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Identifica cada paso del flujo diario, para resaltar cuál es el "paso
/// activo" (en qué pantalla está el chofer ahora) independientemente de
/// si ya quedó marcado como hecho — ver [PasoDiarioStepper.pasoActivo].
enum PasoDiarioTipo { unidad, tablero, solicitud, evidencia }

/// Stepper horizontal puramente informativo con 4 pasos del flujo diario
/// del chofer ("Unidad" → "Tablero" → "Solicitud" → "Evidencia"). No
/// bloquea nada: el chofer puede hacer los pasos en cualquier orden, esto
/// solo refleja cuáles ya completó hoy.
///
/// [pasoActivo] es opcional y puramente visual — resalta el paso
/// correspondiente a la pantalla actual (ej. "Unidad" mientras el chofer
/// está en la pantalla de selección de unidad) con el color de marca, sin
/// afectar el estado real de "hecho" (que sigue viniendo de
/// [pasoDiarioProvider]). Si un paso ya está hecho, ese estado manda sobre
/// "activo" — no tiene sentido resaltar como "en curso" algo que ya se
/// completó.
class PasoDiarioStepper extends StatelessWidget {
  const PasoDiarioStepper({
    super.key,
    required this.unidad,
    required this.tablero,
    required this.solicitud,
    required this.evidencia,
    this.pasoActivo,
  });

  final bool unidad;
  final bool tablero;
  final bool solicitud;
  final bool evidencia;
  final PasoDiarioTipo? pasoActivo;

  @override
  Widget build(BuildContext context) {
    final pasos = [
      (
        tipo: PasoDiarioTipo.unidad,
        etiqueta: 'Unidad',
        icono: Icons.local_shipping_outlined,
        hecho: unidad,
      ),
      (
        tipo: PasoDiarioTipo.tablero,
        etiqueta: 'Tablero',
        icono: Icons.speed_outlined,
        hecho: tablero,
      ),
      (
        tipo: PasoDiarioTipo.solicitud,
        etiqueta: 'Solicitud',
        icono: Icons.receipt_long_outlined,
        hecho: solicitud,
      ),
      (
        tipo: PasoDiarioTipo.evidencia,
        etiqueta: 'Evidencia',
        icono: Icons.photo_camera_outlined,
        hecho: evidencia,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < pasos.length; i++) ...[
          Expanded(
            child: _PasoIndicador(
              etiqueta: pasos[i].etiqueta,
              icono: pasos[i].icono,
              hecho: pasos[i].hecho,
              activo: pasos[i].tipo == pasoActivo,
            ),
          ),
          if (i != pasos.length - 1)
            _Conector(hecho: pasos[i].hecho && pasos[i + 1].hecho),
        ],
      ],
    );
  }
}

class _PasoIndicador extends StatelessWidget {
  const _PasoIndicador({
    required this.etiqueta,
    required this.icono,
    required this.hecho,
    this.activo = false,
  });

  final String etiqueta;
  final IconData icono;
  final bool hecho;
  final bool activo;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // "Hecho" manda sobre "activo": un paso ya completado se ve como
    // completado aunque el chofer siga en esa pantalla.
    final resaltado = hecho || activo;
    final color = hecho
        ? colors.success
        : activo
        ? colors.primary
        : colors.textMuted;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: hecho
                ? colors.success.withValues(alpha: 0.18)
                : activo
                ? colors.primary.withValues(alpha: 0.14)
                : colors.surfaceAlt,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(hecho ? Icons.check : icono, size: 15, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: resaltado ? colors.textPrimary : colors.textMuted,
            fontWeight: resaltado ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _Conector extends StatelessWidget {
  const _Conector({required this.hecho});

  final bool hecho;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: SizedBox(
        width: 16,
        height: 1.5,
        child: ColoredBox(color: hecho ? colors.success : colors.border),
      ),
    );
  }
}
