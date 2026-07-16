import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/session_provider.dart';
import '../../models/carga.dart';
import '../../models/cierre_dia.dart';
import '../../theme/app_radii.dart';
import '../../theme/app_theme.dart';
import '../../widgets/captura_foto_field.dart';
import '../../widgets/stepper_numerico.dart';

/// Registro 2 del día: se llena cuando el chofer termina de trabajar,
/// contra la [Carga] (registro 1) de ese mismo día. Llega vía
/// `state.extra` (la [Carga]) desde /chofer.
class CerrarDiaScreen extends ConsumerStatefulWidget {
  const CerrarDiaScreen({super.key, required this.carga});

  final Carga carga;

  @override
  ConsumerState<CerrarDiaScreen> createState() => _CerrarDiaScreenState();
}

class _CerrarDiaScreenState extends ConsumerState<CerrarDiaScreen> {
  double _kmFinal = 0;
  String? _fotoTableroPath;

  bool _cargandoFoto = false;
  bool _enviando = false;
  String? _errorGeneral;
  RendimientoDia? _resultado;

  Future<void> _tomarFoto() async {
    setState(() => _cargandoFoto = true);
    final ruta = await ref.read(fotoPickerProvider).tomarFoto();
    if (mounted) {
      setState(() {
        if (ruta != null) _fotoTableroPath = ruta;
        _cargandoFoto = false;
      });
    }
  }

  Future<void> _enviar() async {
    if (_kmFinal <= widget.carga.kmAlCargar) {
      setState(() => _errorGeneral =
          'El km final debe ser mayor al km de cuando cargaste (${widget.carga.kmAlCargar.toStringAsFixed(0)}).');
      return;
    }
    if (_fotoTableroPath == null) {
      setState(() => _errorGeneral = 'Toma la foto del tablero con el km final.');
      return;
    }

    setState(() {
      _enviando = true;
      _errorGeneral = null;
    });

    try {
      final perfil = ref.read(sessionProvider)!;
      final repo = ref.read(operacionesRepositoryProvider);
      final cierre = await repo.cerrarDia(
        choferId: perfil.id,
        cargaId: widget.carga.id,
        kmFinal: _kmFinal,
        fotoTableroPath: _fotoTableroPath!,
      );
      final resultado = repo.rendimientoDe(cierre);
      ref.read(operacionesTickProvider.notifier).state++;
      await ref.read(recordatorioServiceProvider).cancelarRecordatorio(widget.carga.id);
      if (mounted) setState(() => _resultado = resultado);
    } catch (e) {
      setState(() => _errorGeneral = 'No pudimos cerrar tu día. Intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cerrar mi día'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _resultado != null
                  ? _ResultadoCierre(resultado: _resultado!)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors.surfaceAlt,
                            borderRadius: AppRadii.cardRadius,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.speed_outlined, color: colors.textSecondary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Cargaste combustible hoy con '
                                  '${widget.carga.kmAlCargar.toStringAsFixed(0)} km en el tablero.',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        CapturaFotoField(
                          etiqueta: 'Foto del tablero (km final)',
                          icono: Icons.speed_outlined,
                          rutaFoto: _fotoTableroPath,
                          cargando: _cargandoFoto,
                          onTomarFoto: _tomarFoto,
                        ),
                        const SizedBox(height: 16),
                        StepperNumerico(
                          etiqueta: 'Km final del día',
                          valor: _kmFinal,
                          sufijo: 'km',
                          paso: 1,
                          decimales: 0,
                          minimo: widget.carga.kmAlCargar,
                          onChanged: (v) => setState(() => _kmFinal = v),
                        ),
                        if (_errorGeneral != null) ...[
                          const SizedBox(height: 12),
                          Text(_errorGeneral!, style: TextStyle(color: colors.error)),
                        ],
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _enviando ? null : _enviar,
                          child: _enviando
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Cerrar mi día'),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultadoCierre extends StatelessWidget {
  const _ResultadoCierre({required this.resultado});

  final RendimientoDia resultado;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final color = resultado.esAnomalo ? colors.warning : colors.success;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(Icons.check_circle, color: color, size: 44),
        ),
        const SizedBox(height: 24),
        Text('Día cerrado', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '${resultado.kmRecorridos.toStringAsFixed(0)} km recorridos',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surfaceAlt,
            borderRadius: AppRadii.cardRadius,
          ),
          child: Column(
            children: [
              Text('Rendimiento',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted)),
              const SizedBox(height: 4),
              Text(
                resultado.rendimiento != null
                    ? '${resultado.rendimiento!.toStringAsFixed(1)} km/L'
                    : 'No calculable',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: color),
              ),
              if (resultado.esAnomalo) ...[
                const SizedBox(height: 4),
                Text('Fuera de lo habitual — un admin lo revisará.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.warning)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 28),
        ElevatedButton(
          // pop() (no go()): se llegó aquí con push() desde /chofer, y el
          // caller espera ese Future para refrescar sus datos al volver.
          onPressed: () => context.pop(),
          child: const Text('Volver al inicio'),
        ),
      ],
    );
  }
}
